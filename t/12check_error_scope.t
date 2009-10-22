#!perl

use strict;
use warnings;
no strict 'refs';
no warnings 'redefine';

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 3;
use Catalyst::Test 'TestApp';

TestApp->config->{ static }->{ dirs } = [ qr{stuff/} ];
my $orig_sub = *Catalyst::Plugin::Static::Simple::prepare_action{CODE};

*Catalyst::Plugin::Static::Simple::prepare_action = sub {
	my ($c) = @_;

	eval { my $var = 1 / 0 };

	ok ($@, '$@ has a value.');
	return $orig_sub->( $c );
};

ok( my $res = request("http://localhost/"), 'request ok' );
ok( $res->code == 200, q{Previous error doesn't crash static::simple} );
