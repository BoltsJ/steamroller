use ExtUtils::MakeMaker;

WriteMakefile(
    NAME        => 'Bolts::Steamroller',
    VERSION     => '0.01',
    AUTHOR      => 'Joseph "Bolts" Nosie',
    LICENSE     => 'GPL',
    EXE_FILES   => [ 'bin/steamroller' ],
    PREREQ_PM   => {
        'JSON'          => '2.21',
        'LWP::Simple'   => '5.835',
    },
);
