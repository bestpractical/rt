use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'      => 'RT',
    'VERSION_FROM' => 'RT.pm', # finds $VERSION
    'PREREQ_PM' => {
                     'DBI'                 => 1.16,
                     'DBIx::SearchBuilder' => '0.46',
                     'Date::Parse'         => 0,
                     'Date::Format'        => 0,
                     'MIME::Entity'        => 5.108,
                     'Mail::Mailer'        => '1.20',
                     'Log::Dispatch'       => 1.6,
                     'HTML::Entities'      => 0,
                     'Text::Wrapper'       => 0,
                     'Text::Template'      => 0,
		     'Getopt::Long'        => 2.24,
                   },
);

     {
                   package MY;
                   sub top_targets {
                       my($self) = @_;
                       my $out = "POD2TEST_EXE = pod2test\n";

                       $out .= $self->SUPER::top_targets(@_);
                       # $out =~ s/^(pure_all\b.*)/$1 testifypods/m;

                       $out .= "\n\ntestifypods : \n";

			my @pods = (keys %{$self->{MAN1PODS}},
				     keys %{$self->{MAN3PODS}});

                       foreach my $pod (@pods) {
                           (my $test = $pod) =~ s/\.(pm|pod)$//;
                           $test =~ s/^lib\W//;
                           $test =~ s/\W/-/;
			   $test =~ s/\//__/g;
                           $test = "autogen-$test.t";
                           $out .= "\t$self->{NOECHO}\$(POD2TEST_EXE) ".
                                   "$pod t/$test \n";
                       }

                       return $out;
                   }
               }

