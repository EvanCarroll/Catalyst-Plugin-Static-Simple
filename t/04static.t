#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 7;
use Catalyst::Test 'TestApp';

# test getting a css file
ok( my $res = request('http://localhost/files/static.css'), 'request ok' );
is( $res->content_type, 'text/css', 'content-type text/css ok' );
like( $res->content, qr/background/, 'content of css ok' );

# test a non-existent file
ok( $res = request('http://localhost/files/404.txt'), 'request ok' );
is( $res->content, 'default', 'default handler for non-existent content ok' );

# test unknown extension
ok( $res = request('http://localhost/files/err.omg'), 'request ok' );
is( $res->content_type, 'text/plain', 'unknown extension as text/plain ok' );
