use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'RT',
    'VERSION_FROM' => 'RT.pm', # finds $VERSION
    'PREREQ_PM' => {
                     'DBI'                 => 1.13,
                     'DBIx::DataSource'    => 0.02,
                     'DBIx::DBSchema'      => 0.14,
                     'DBIx::SearchBuilder' => 0.15,
                     'HTML::Mason'         => 0.89,
                     'Date::Manip'         => 0,
                     'Date::Format'        => 0,
                     'MIME::Entity'        => 5.108,
                     'Mail::Mailer'        => 1.20,
                     'CGI::Cookie'         => 1.06,
                     'Log::Dispatch'       => 1.6,
                     'HTML::Entities'      => 0,
                     'Text::Wrapper'       => 0,
                     'Text::Template'      => 0,
                     'Apache::Session'     => 1.53,
                   },
);

