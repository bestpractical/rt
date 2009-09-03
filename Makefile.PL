use inc::Module::Install;

name        'RT';
version     '3.999_01';
license     'GPLv2';
requires    'Jifty' => '0.80913';

requires(
    'Digest::base' => 0,
    'Digest::MD5'                => '2.27',
    'DBI'                        => '1.37',
    'Class::ReturnValue'         => '0.40',
    'Jifty::DBI'                 => '0.49',
    'Text::Template'             => 0,
    'File::ShareDir'             => 0,
    'File::Spec'                 => '0.8',
    'HTML::Entities'             => 0,
    'HTML::Scrubber'             => '0.08',
    'Locale::Maketext::Lexicon'  => '0.32',
    'Locale::Maketext::Fuzzy'    => '0',
    'Lorzy'                      => '0',
    'MIME::Entity'               => '5.425',
    'Email::Address'             => 0,
    'Mail::Mailer'               => '1.57',
    'Text::Wrapper'              => 0,
    'Time::ParseDate'            => 0,
    'Time::HiRes'                => 0,
    'File::Temp'                 => '0.18',
    'Text::Quoted'               => '2.02',
    'Tree::Simple'               => '1.04',
    'UNIVERSAL::require'         => 0,
    'Regexp::Common'             => 0,
    'Regexp::Common::Email::Address'             => 0,
    'Scalar::Util'               => 0,
    'Module::Versions::Report'   => '1.05',
    'Cache::Simple::TimedExpiry' => 0,
    'Calendar::Simple'           => 0,
    'Encode'                     => '2.13',
    'CSS::Squish'                => '0.06',
    'File::Glob'                 => 0,
    'Devel::StackTrace'          => '1.19',
    'Text::Naming::Convention'   => 0,
    'DateTime'                   => '0.46',
    'Pod::POM'                   => 0,
);

test_requires (
    'Test::Expect'        => 0,
    'Test::MockTime'      => 0,
    'String::ShellQuote'  => 0,
);

features(

    'Mason' => [
        -default            => 1,
        'HTML::Mason'       => 1.40,
        'Digest::MD5'       => 2.27,
        'Storable'          => 2.08,
        'XML::RSS'          => 1.05,
        'Text::WikiFormat'  => 0.76,
        'CSS::Squish'       => 0.06,
        'Devel::StackTrace' => 1.19,
    ],
    MAILGATE => [
        -default => 1,
        'HTML::TreeBuilder',
        'HTML::FormatText',
        'Getopt::Long',
        'LWP::UserAgent',
        'Pod::Usage',
    ],

    ,
    CLI => [
        -default       => 1,
        'Getopt::Long' => '2.24',
        'LWP',
        'HTTP::Request::Common',
        'Text::ParseWords',
        'Term::ReadLine',
        'Term::ReadKey',
        ]

    ,
    DEV => [
        -default => 1,
        'HTML::Form',
        'HTML::TokeParser',
        'WWW::Mechanize',
        'Test::WWW::Mechanize' => '1.04',
        'Module::Refresh'      => '0.03',
        'Test::Expect'         => '0.31',
        'XML::Simple',
        'File::Find',
        'Test::Deep', => 0,
        'String::ShellQuote'         => '0',
        'Test::Warn',
        'Test::Builder' => '0.77',
        'IPC::Run3',
        'Test::MockTime',
    ],

    ,
    FASTCGI => [
        -default => 0,
        'CGI'    => '3.38',
        'FCGI',
        'CGI::Fast'
        ]

    ,
    MYSQL => [
        -default     => 1,
        'DBD::mysql' => '2.1018'
        ]

    ,
    ORACLE => [
        -default => 0,
        'DBD::Oracle'
        ]

    ,
    POSTGRESQL => [
        -default  => 0,
        'DBD::Pg' => '1.43',
        ]

    ,
    SQLITE => [
        -default      => 1,
        'DBD::SQLite' => '1.00',
    ],
    GPG => [
        -default => 1,
        'GnuPG::Interface' => 0,
        'PerlIO::eol' => 0,
        ]

    ,
    ICAL => [
        -default     => 1,
        'Data::ICal' => 0
        ]

    ,
    SMTP => [
        -default    => 0,
        'Net::SMTP' => 0
        ]

    ,
    DASHBOARDS => [
        -default                  => 1,
        'HTML::RewriteAttributes' => 0.02,
        'MIME::Types'
        ]

    ,
    GRAPHVIZ => [
        -default                => 1,
        'GraphViz'              => 0,
        'IPC::Run'              => 0,
        'IPC::Run::SafeHandles' => 0
        ]

    ,
    GD => [
        -default => 1,
        'GD',
        'GD::Graph',
        'GD::Text'
    ]
);

tests("t/*.t t/*/*.t");
auto_install;
WriteAll;
