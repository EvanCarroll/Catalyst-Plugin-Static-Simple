package Catalyst::Plugin::Static::Simple;

use strict;
use base qw/Class::Accessor::Fast Class::Data::Inheritable/;
use File::Slurp;
use File::stat;
use MIME::Types;
use NEXT;

our $VERSION = '0.08';

__PACKAGE__->mk_classdata( qw/_static_mime_types/ );
__PACKAGE__->mk_accessors( qw/_static_file
                              _static_apache_mode
                              _static_debug_message/ );

# prepare_action is used to first check if the request path is a static file.
# If so, we skip all other prepare_action steps to improve performance.
sub prepare_action {
    my $c = shift;
    my $path = $c->req->path;

    # is the URI in a static-defined path?
    foreach my $dir ( @{ $c->config->{static}->{dirs} } ) {
        my $re = ( $dir =~ /^qr\//xms ) ? eval $dir : qr/^${dir}/;
        if ($@) {
            $c->error( "Error compiling static dir regex '$dir': $@" );
        }
        if ( $path =~ $re ) {
            if ( $c->_locate_static_file ) {
                $c->_debug_msg( "from static directory" )
                    if ( $c->config->{static}->{debug} );
                return;
            } else {
                $c->_debug_msg( "404: file not found: $path" )
                    if ( $c->config->{static}->{debug} );
                $c->res->status( 404 );
                return;
            }
        }
    }
    
    # Does the path have an extension?
    if ( $path =~ /.*\.(\S{1,})$/xms ) {
        # and does it exist?
        return if ( $c->_locate_static_file );
    }
    
    return $c->NEXT::prepare_action(@_);
}

# dispatch takes the file found during prepare_action and serves it
sub dispatch {
    my $c = shift;
    
    return if ( $c->res->status != 200 );
    
    if ( $c->_static_file ) {
        return $c->_serve_static;
    }
    else {
        return $c->NEXT::dispatch(@_);
    }
}

# finalize serves up final header information
sub finalize {
    my $c = shift;
    
    # display all log messages
    if ( $c->config->{static}->{debug} && scalar @{$c->_debug_msg} ) {
        $c->log->debug( "Static::Simple: Serving " .
            join( " ", @{$c->_debug_msg} )
        );
    }
    
    # return DECLINED when under mod_perl
    if ( $c->config->{static}->{use_apache} && $c->_static_apache_mode ) {
        my $engine = $c->_static_apache_mode;
        no strict 'subs';
        if ( $engine == 13 ) {
            return Apache::Constants::DECLINED;
        }
        elsif ( $engine == 19 ) {
            return Apache::Const::DECLINED;
        }
        elsif ( $engine == 20 ) {
            return Apache2::Const::DECLINED;
        }
    }
    
    if ( $c->res->status =~ /^(1\d\d|[23]04)$/xms ) {
        $c->res->headers->remove_content_headers;
        return $c->finalize_headers;
    }
    
    return $c->NEXT::finalize(@_);
}

sub setup {
    my $c = shift;
    
    $c->NEXT::setup(@_);
    
    $c->config->{static}->{dirs} ||= [];
    $c->config->{static}->{include_path} ||= [ $c->config->{root} ];
    $c->config->{static}->{mime_types} ||= {};
    $c->config->{static}->{use_apache} ||= 0; 
    $c->config->{static}->{debug} ||= $c->debug;
    
    # load up a MIME::Types object, only loading types with
    # at least 1 file extension
    $c->_static_mime_types( MIME::Types->new( only_complete => 1 ) );
    
    # preload the type index hash so it's not built on the first request
    $c->_static_mime_types->create_type_index;
}

# Search through all included directories for the static file
# Based on Template Toolkit INCLUDE_PATH code
sub _locate_static_file {
    my $c = shift;
    
    my $path = $c->req->path;
    
    my @ipaths = @{ $c->config->{static}->{include_path} };
    my $dpaths;
    my $count = 64; # maximum number of directories to search
    
    while ( @ipaths && --$count) {
        my $dir = shift @ipaths || next;
        
        if ( ref $dir eq 'CODE' ) {
            eval { $dpaths = &$dir( $c ) };
            if ($@) {
                $c->log->error( "Static::Simple: include_path error: " . $@ );
            } else {
                unshift( @ipaths, @$dpaths );
                next;
            }
        } else {
            $dir =~ s/\/$//xms;
            if ( -d $dir && -f $dir . '/' . $path ) {
                $c->_debug_msg( $dir . "/" . $path )
                    if ( $c->config->{static}->{debug} );
                return $c->_static_file( $dir . '/' . $path );
            }
        }
    }
    
    return;
}

sub _serve_static {
    my $c = shift;
    
    my $path = $c->req->path;    
    
    # abort if running under mod_perl
    # note that we do not use the Apache method if the user has defined
    # custom MIME types or is using include paths, as Apache would not know
    # about them
    APACHE_CHECK:
    {
        if ( $c->config->{static}->{use_apache} ) {
            # check engine version
            last APACHE_CHECK unless $c->engine =~ /Apache::MP(\d{2})/xms;
            my $engine = $1;
    
            # skip if we have user-defined MIME types
            last APACHE_CHECK if keys %{ $c->config->{static}->{mime_types} };
            
            # skip if the file is in a user-defined include path
            last APACHE_CHECK if $c->_static_file 
                ne $c->config->{root} . '/' . $path;
    
             # check that Apache will serve the correct file
             if ( $c->apache->document_root ne $c->config->{root} ) {
                 $c->log->warn( "Static::Simple: Your Apache DocumentRoot"
                              . " must be set to " . $c->config->{root} 
                              . " to use the Apache feature.  Yours is"
                              . " currently " . $c->apache->document_root
                              );
             }
             else {
                 $c->_debug_msg( "DECLINED to Apache" )
                    if ( $c->config->{static}->{debug} );          
                 $c->_static_apache_mode( $engine );
                 return;
             }
        }
    }
    
    my $type = $c->_ext_to_type;
    
    my $full_path = $c->_static_file;
    my $stat = stat( $full_path );

    # the below code all from C::P::Static
    if ( $c->req->headers->if_modified_since ) {
        if ( $c->req->headers->if_modified_since == $stat->mtime ) {
            $c->res->status( 304 ); # Not Modified
            $c->res->headers->remove_content_headers;
            return 1;
        }
    }

    my $content = read_file( $full_path );
    $c->res->headers->content_type( $type );
    $c->res->headers->content_length( $stat->size );
    $c->res->headers->last_modified( $stat->mtime );
    $c->res->output( $content );
    return 1;
}

# looks up the correct MIME type for the current file extension
sub _ext_to_type {
    my $c = shift;
    my $path = $c->req->path;
    
    if ( $path =~ /.*\.(\S{1,})$/xms ) {
        my $ext = $1;
        my $user_types = $c->config->{static}->{mime_types};
        my $type = $user_types->{$ext} 
                || $c->_static_mime_types->mimeTypeOf( $ext );
        if ( $type ) {
            $c->_debug_msg( "as $type" )
                if ( $c->config->{static}->{debug} );            
            return $type;
        }
        else {
            $c->_debug_msg( "as text/plain (unknown extension $ext)" )
                if ( $c->config->{static}->{debug} );
            return 'text/plain';
        }
    }
    else {
        $c->_debug_msg( 'as text/plain (no extension)' )
            if ( $c->config->{static}->{debug} );
        return 'text/plain';
    }
}

sub _debug_msg {
    my ( $c, $msg ) = @_;
    
    if ( !defined $c->_static_debug_message ) {
        $c->_static_debug_message( [] );
    }
    
    if ( $msg ) {
        push @{ $c->_static_debug_message }, $msg;
    }
    
    return $c->_static_debug_message;
}

1;
__END__

=head1 NAME

Catalyst::Plugin::Static::Simple - Make serving static pages painless.

=head1 SYNOPSIS

    use Catalyst;
    MyApp->setup( qw/Static::Simple/ );

=head1 DESCRIPTION

The Static::Simple plugin is designed to make serving static content in your
application during development quick and easy, without requiring a single
line of code from you.

It will detect static files used in your application by looking for file
extensions in the URI.  By default, you can simply load this plugin and it
will immediately begin serving your static files with the correct MIME type.
The light-weight MIME::Types module is used to map file extensions to
IANA-registered MIME types.

Note that actions mapped to paths using periods (.) will still operate
properly.

You may further tweak the operation by adding configuration options, described
below.

=head1 ADVANCED CONFIGURATION

Configuration is completely optional and is specified within 
MyApp->config->{static}.  If you use any of these options, the module will
probably feel less "simple" to you!

=head2 Forcing directories into static mode

Define a list of top-level directories beneath your 'root' directory that
should always be served in static mode.  Regular expressions may be
specified using qr//.

    MyApp->config->{static}->{dirs} = [
        'static',
        qr/^(images|css)/,
    ];

=head2 Including additional directories (experimental!)

You may specify a list of directories in which to search for your static
files.  The directories will be searched in order and will return the first
file found.  Note that your root directory is B<not> automatically added to
the search path when you specify an include_path.  You should use
MyApp->config->{root} to add it.

    MyApp->config->{static}->{include_path} = [
        '/path/to/overlay',
        \&incpath_generator,
        MyApp->config->{root}
    ];
    
With the above setting, a request for the file /images/logo.jpg will search
for the following files, returning the first one found:

    /path/to/overlay/images/logo.jpg
    /dynamic/path/images/logo.jpg
    /your/app/home/root/images/logo.jpg
    
The include path can contain a subroutine reference to dynamically return a
list of available directories.  This method will receive the $c object as a
parameter and should return a reference to a list of directories.  Errors can
be reported using die().  This method will be called every time a file is
requested that appears to be a static file (i.e. it has an extension).

For example:

    sub incpath_generator {
        my $c = shift;
        
        if ( $c->session->{customer_dir} ) {
            return [ $c->session->{customer_dir} ];
        } else {
            die "No customer dir defined.";
        }
    }

=head2 Custom MIME types

To override or add to the default MIME types set by the MIME::Types module,
you may enter your own extension to MIME type mapping. 

    MyApp->config->{static}->{mime_types} = {
        jpg => 'image/jpg',
        png => 'image/png',
    };

=head2 Apache integration and performance

Optionally, when running under mod_perl, Static::Simple can return DECLINED
on static files to allow Apache to serve the file.  A check is first done to
make sure that Apache's DocumentRoot matches your Catalyst root, and that you
are not using any custom MIME types or multiple roots.  To enable the Apache
support, you can set the following option.

    MyApp->config->{static}->{use_apache} = 1;
    
By default this option is disabled because after several benchmarks it
appears that just serving the file from Catalyst is the better option.  On a
3K file, Catalyst appears to be around 25% faster, and is 42% faster on a 10K
file.  My benchmarking was done using the following 'siege' command, so other
benchmarks would be welcome!

    siege -u http://server/static/css/10K.css -b -t 1M -c 1

For best static performance, you should still serve your static files directly
from Apache by defining a Location block similar to the following:

    <Location /static>
        SetHandler default-handler
    </Location>

=head2 Bypassing other plugins

This plugin checks for a static file in the prepare_action stage.  If the
request is for a static file, it will bypass all remaining prepare_action
steps.  This means that by placing Static::Simple before all other plugins,
they will not execute when a static file is found.  This can be helpful by
skipping session cookie checks for example.  Or, if you want some plugins
to run even on static files, list them before Static::Simple.

Currently, work done by plugins in any other prepare method will execute
normally.

=head2 Debugging information

Enable additional debugging information printed in the Catalyst log.  This
is automatically enabled when running Catalyst in -Debug mode.

    MyApp->config->{static}->{debug} = 1;

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Static>, 
L<http://www.iana.org/assignments/media-types/>

=head1 AUTHOR

Andy Grundman, <andy@hybridized.org>

=head1 THANKS

The authors of Catalyst::Plugin::Static:

    Sebastian Riedel
    Christian Hansen
    Marcus Ramberg

For the include_path code from Template Toolkit:

    Andy Wardley

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
