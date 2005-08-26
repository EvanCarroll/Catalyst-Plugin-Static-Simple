use strict;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'passthrough',
    license            => 'perl',
    module_name        => 'Catalyst::Plugin::Static::Simple',
    requires           => { 
        'Catalyst' => '5.30',
        'File::Slurp' => 0,
        'MIME::Types' => '1.15',
    },
    create_makefile_pl => 'passthrough',
    test_files   => [
        glob('t/*.t') 
    ]
);
$build->create_build_script;
