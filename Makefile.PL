use ExtUtils::MakeMaker;

WriteMakefile(
    NAME        => 'Bolts::Steamroller',
    VERSION     => '0.01',
    AUTHOR      => 'Joseph "Bolts" Nosie',
    LICENSE     => 'GPL',
    EXE_FILES   => [ 'bin/steamroller' ],
    PREREQ_PM   => {
        'JSON'          => '0',
        'LWP::Simple'   => '0',
    },
);
