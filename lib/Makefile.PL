use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'RT',
    'VERSION_FROM' => 'RT.pm', # finds $VERSION
    'PREREQ_PM' => {
                     'DBI'                 => 1.16,
                     'DBIx::SearchBuilder' => 0.39,
                     'Date::Parse'         => 0,
                     'Date::Format'        => 0,
                     'MIME::Entity'        => 5.108,
                     'Mail::Mailer'        => 1.20,
                     'Log::Dispatch'       => 1.6,
                     'HTML::Entities'      => 0,
                     'Text::Wrapper'       => 0,
                     'Text::Template'      => 0,
		     'Getopt::Long'        => 2.24,
                   },
);

