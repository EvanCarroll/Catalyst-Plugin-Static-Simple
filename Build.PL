use strict;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Catalyst::Plugin::Static::Simple',
    requires           => { 
        'Catalyst'    => '5.30',
        'MIME::Types' => '1.15',
    },
    create_makefile_pl => 'passthrough',
    test_files   => [
        glob('t/*.t') 
    ]
);

# Require File::Slurp only for older Catalyst versions
my $cat = $build->check_installed_status('Catalyst');
if ( $cat->{have} le '5.33' ) {
    $build->requires->{'File::Slurp'} = 0;
}

# If the user has the SubRequest plugin installed, tell them to upgrade
my $subreq = $build->check_installed_status('Catalyst::Plugin::SubRequest');
if ( $subreq->{have} le '0.08' ) {
    print "** WARNING **\n"
        . "You appear to have a version of Catalyst::Plugin::SubRequest "
        . "older than 0.08.\n"
        . "You must upgrade to SubRequest 0.08 or later if you use it "
        . "in any applications with Static::Simple.\n";
    $build->requires->{'Catalyst::Plugin::SubRequest'} => '0.08';
}

$build->create_build_script;
