#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More tests => 4;
use Catalyst::Test 'TestApp';
use HTTP::Request;

# test getting a file via serve_static_file
ok( my $res = request('http://localhost/images/catalyst.png'), 'got image the first time' );
ok( my $lastmod = $res->headers->header('Last-Modified'), 'image has Last-Modified');

my $req = HTTP::Request->new(GET => "http://localhost/images/catalyst.png",
  [ "If-Modified-Since" => $lastmod ]
);

ok( $res = request($req), 'got the image with If-Modified-Since' );
is( $res->code, 304, 'got a 304 response' );

