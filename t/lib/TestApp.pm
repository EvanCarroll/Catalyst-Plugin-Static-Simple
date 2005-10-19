package TestApp;

use strict;
use Catalyst;

our $VERSION = '0.01';

TestApp->config(
    name => 'TestApp',
);

my @plugins = qw/Static::Simple/;

# load the SubRequest plugin if available
eval { 
    require Catalyst::Plugin::SubRequest; 
    die unless Catalyst::Plugin::SubRequest->VERSION ge '0.08';
};
push @plugins, 'SubRequest' unless ($@);

TestApp->setup( @plugins );

sub incpath_generator {
    my $c = shift;
    
    return [ $c->config->{root} . '/incpath' ];
}

sub default : Private {
    my ( $self, $c ) = @_;
    
    $c->res->output( 'default' );
}

sub subtest : Local {
    my ( $self, $c ) = @_;

    $c->res->output( $c->subreq('/subtest2') );
}

sub subtest2 : Local {
    my ( $self, $c ) = @_;
    
    $c->res->output( 'subtest2 ok' );
}

1;
