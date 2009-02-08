use inc::Module::Install 0.65;

name 'Catalyst-Plugin-Static-Simple';
all_from 'lib/Catalyst/Plugin/Static/Simple.pm';

requires 'Catalyst::Runtime' => '5.30';
requires 'MIME::Types' => '1.15';
requires 'Test::More';
requires 'MRO::Compat';

unless( can_use 'Catalyst' => '5.33' ) {
    requires 'File::Slurp';
}

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
WriteAll;
