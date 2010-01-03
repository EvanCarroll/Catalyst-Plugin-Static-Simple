use strict;
use warnings;
use inc::Module::Install 0.91;

name 'Catalyst-Plugin-Static-Simple';
all_from 'lib/Catalyst/Plugin/Static/Simple.pm';

requires 'Catalyst::Runtime' => '5.80008';
requires 'MIME::Types' => '1.25';
requires 'Test::More';
requires 'Moose';
requires 'namespace::autoclean';

if( can_use 'Catalyst::Plugin::SubRequest' ) {
    unless( can_use 'Catalyst::Plugin::SubRequest' => '0.08' ) {
        print "** WARNING **\n"
            . "You appear to have a version of Catalyst::Plugin::SubRequest "
            . "older than 0.08.\n"
            . "You must upgrade to SubRequest 0.08 or later if you use it "
            . "in any applications with Static::Simple.\n";
        requires 'Catalyst::Plugin::SubRequest' => '0.08';
    }
}

auto_install;
resources repository => 'http://dev.catalyst.perl.org/repos/Catalyst/Catalyst-Plugin-Static-Simple/trunk/';

WriteAll;
