package TestApp;

use strict;
use Catalyst;

our $VERSION = '0.01';

TestApp->config(
    name => 'TestApp',
);

TestApp->setup( qw/Static::Simple/ );

sub incpath_generator {
    my $c = shift;
    
    return [ $c->config->{root} . '/incpath' ];
}

sub default : Private {
    my ( $self, $c ) = @_;
    
    $c->res->output( 'default' );
}

1;
