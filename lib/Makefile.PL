use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'RT',
    'VERSION_FROM' => 'RT.pm',    # finds $VERSION
    'PREREQ_PM'    => {
    },
);

{

    package MY;

    sub top_targets {
        my ($self) = @_;
        my $out = "POD2TEST_EXE = ".$self->{PERL}." ../sbin/extract_pod_tests\n";

        $out .= $self->SUPER::top_targets(@_);

        # $out =~ s/^(pure_all\b.*)/$1 testifypods/m;

        $out .= "\n\ntestifypods : \n\t-mkdir t/autogen\n";

        my @pods = ( keys %{ $self->{MAN1PODS} }, keys %{ $self->{MAN3PODS} } );

        foreach my $pod (@pods) {
            ( my $test = $pod ) =~ s/\.(pm|pod)$//;
            $test =~ s/^lib\W//;
            $test =~ s/\W/-/;
            $test =~ s/\//__/g;
            $test = "autogen-$test.t";
            $out .= "\t$self->{NOECHO}\$(POD2TEST_EXE) " . "$pod t/autogen/$test \n";
        }

        return $out;
    }
}

