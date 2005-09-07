#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 8;
use Catalyst::Test 'TestApp';

# test defined static dirs
TestApp->config->{static}->{dirs} = [
    'always-static',
    qr/^images/,
    'qr/^css/',
];

# a file with no extension will return text/plain
ok( my $res = request('http://localhost/always-static/test'), 'request ok' );
is( $res->content_type, 'text/plain', 'text/plain ok' );

# a missing file in a defined static dir will return 404
ok( $res = request('http://localhost/always-static/404.txt'), 'request ok' );
is( $res->code, 404, '404 ok' );

# qr regex test
ok( $res = request('http://localhost/images/catalyst.png'), 'request ok' );
is( $res->content_type, 'image/png', 'qr regex path ok' );

# eval regex test
ok( $res = request('http://localhost/css/static.css'), 'request ok' );
like( $res->content, qr/background/, 'eval regex path ok' );
