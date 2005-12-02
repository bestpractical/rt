#line 1 "inc/Module/Install/Can.pm - /usr/local/share/perl/5.8.4/Module/Install/Can.pm"
package Module::Install::Can;
use Module::Install::Base; @ISA = qw(Module::Install::Base);
$VERSION = '0.01';

use strict;
use Config ();
use File::Spec ();
use ExtUtils::MakeMaker ();

# check if we can run some command
sub can_run {
    my ($self, $cmd) = @_;

    my $_cmd = $cmd;
    return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = File::Spec->catfile($dir, $_[1]);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

sub can_cc {
    my $self = shift;
    my @chunks = split(/ /, $Config::Config{cc}) or return;

    # $Config{cc} may contain args; try to find out the program part
    while (@chunks) {
        return $self->can_run("@chunks") || (pop(@chunks), next);
    }

    return;
}

1;
