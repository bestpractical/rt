#line 1 "inc/Module/Install/Can.pm - /usr/lib/perl5/site_perl/5.8.7/Module/Install/Can.pm"
package Module::Install::Can;

use Module::Install::Base;
@ISA = qw(Module::Install::Base);

$VERSION = '0.01';

use strict;
use Config ();
use File::Spec ();
use ExtUtils::MakeMaker ();

# check if we can load some module
sub can_use {
    my ($self, $mod, $ver) = @_;
    $mod =~ s{::|\\}{/}g;
    $mod .= ".pm" unless $mod =~ /\.pm$/i;

    my $pkg = $mod;
    $pkg =~ s{/}{::}g;
    $pkg =~ s{\.pm$}{}i;

    local $@;
    eval { require $mod; $pkg->VERSION($ver || 0); 1 };
}

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

# Fix Cygwin bug on maybe_command();
if ($^O eq 'cygwin') {
    require ExtUtils::MM_Cygwin;
    require ExtUtils::MM_Win32;
    if ( ! defined(&ExtUtils::MM_Cygwin::maybe_command) ) {
        *ExtUtils::MM_Cygwin::maybe_command = sub {
            my ($self, $file) = @_;
            if ($file =~ m{^/cygdrive/}i and ExtUtils::MM_Win32->can('maybe_command')) {
                ExtUtils::MM_Win32->maybe_command($file);
            }
            else {
                ExtUtils::MM_Unix->maybe_command($file);
            }
        }
    }
}

1;
