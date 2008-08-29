use inc::Module::Install;

name        'RT';
version     '3.99_01';
license 'GPLv2';
requires    'Jifty' => '0.70824';

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
    'Log::Dispatch'              => '2.0',
    'Locale::Maketext'           => '1.06',
    'Locale::Maketext::Lexicon'  => '0.32',
    'Locale::Maketext::Fuzzy'    => '0',
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
    'Scalar::Util'               => 0,
    'Module::Versions::Report'   => '1.05',
    'Cache::Simple::TimedExpiry' => 0,
    'Calendar::Simple'           => 0,
    'Encode'                     => '2.13',
    'CSS::Squish'                => '0.06',
    'File::Glob'                 => 0,
    'Devel::StackTrace'          => '1.19',
    'Text::Naming::Convention'   => 0,
);

features(

    'Mason' => [
        -default            => 1,
        'HTML::Mason'       => 1.36,
        'Errno'             => 0,
        'Digest::MD5'       => 2.27,
        'CGI::Cookie'       => 1.20,
        'Storable'          => 2.08,
        'Apache::Session'   => 1.53,
        'XML::RSS'          => 1.05,
        'Text::WikiFormat'  => 0.76,
        'CSS::Squish'       => 0.06,
        'Devel::StackTrace' => 1.19,
    ],

    'Standalone Server' => [
        -default => 1,

        'HTTP::Server::Simple' => 0.34,
        'HTTP::Server::Simple::Mason', 0.09,
        'Net::Server'          => 0,
        'Net::Server::PreFork' => 0
    ],

    ,
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
        'Test::HTTP::Server::Simple' => '0.09',
        'Log::Dispatch::Perl',
        'Test::Warn',
        'Test::Builder' => '0.77',
        'IPC::Run3',
    ],

    ,
    FASTCGI => [
        -default => 0,
        'CGI'    => '3.38',
        'FCGI',
        'CGI::Fast'
        ]

    ,
    SPEEDYCGI => [
        -default => 0,
        'CGI'    => '3.38',
        'CGI::SpeedyCGI'
        ]

    ,
    MODPERL1 => [
        -default => 0,
        'CGI'    => '3.38',
        'Apache::Request',
        'Apache::DBI' => '0.92'
        ]

    ,
    MODPERL2 => [
        -default => 0,
        'CGI'    => '3.38',
        'Apache::DBI',
        'HTML::Mason' => '1.36',
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
