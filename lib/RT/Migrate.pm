# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Migrate;

use strict;
use warnings;

use Time::HiRes qw//;

sub format_time {
    my $time = shift;
    my $s = "";

    $s .= int($time/60/60)."hr "
        if $time > 60*60;
    $s .= int(($time % (60*60))/60)."min "
        if $time > 60;
    $s .= int($time % 60)."s"
        if $time < 60*60;

    return $s;
}

sub progress_bar {
    my %args = (
        label => "",
        now   => 0,
        max   => 1,
        cols  => 80,
        char  => "=",
        @_,
    );
    $args{now} ||= 0;

    my $fraction = $args{max} ? $args{now} / $args{max} : 0;

    my $max_width = $args{cols} - 30;
    my $bar_width = int($max_width * $fraction);

    return sprintf "%20s |%-" . $max_width . "s| %3d%%\n",
        $args{label}, $args{char} x $bar_width, $fraction*100;
}

sub progress {
    my %args = (
        top    => sub { print "\n\n" },
        bottom => sub {},
        every  => 3,
        bars   => [qw/Ticket Asset Transaction Attachment User Group/],
        counts => sub {},
        max    => {},
        @_,
    );

    my $max_objects = 0;
    $max_objects += $_ for values %{ $args{max} };

    my $last_time;
    my $start;
    my $left;
    my $offset;
    return sub {
        my $obj = shift;
        my $force = shift;
        my $now = Time::HiRes::time();
        return if defined $last_time and $now - $last_time <= $args{every} and not $force;

        $start = $now unless $start;
        $last_time = $now;

        my $elapsed = $now - $start;

        # Determine terminal size
        print `clear`;
        my ($cols, $rows) = (80, 25);
        eval {
            require Term::ReadKey;
            ($cols, $rows) = Term::ReadKey::GetTerminalSize();
        };
        $cols -= 1;

        $args{top}->($elapsed, $rows, $cols);

        my %counts = $args{counts}->();
        for my $class (map {"RT::$_"} @{$args{bars}}) {
            my $display = $class;
            $display =~ s/^RT::(.*)/@{[$1]}s:/;
            print progress_bar(
                label => $display,
                now   => $counts{$class},
                max   => $args{max}{$class},
                cols  => $cols,
            );
        }

        my $total = 0;
        $total += $_ for map {$counts{$_}} grep {exists $args{max}{$_}} keys %counts;
        $offset = $total unless defined $offset;
        print "\n", progress_bar(
            label => "Total",
            now   => $total,
            max   => $max_objects,
            cols  => $cols,
            char  => "#",
        );

        # Time estimates
        my $fraction = $max_objects
            ? ($total - $offset)/($max_objects - $offset)
            : 0;
        if ($fraction > 0.03) {
            if (defined $left) {
                $left = 0.75 * $left
                      + 0.25 * ($elapsed / $fraction - $elapsed);
            } else {
                $left = ($elapsed / $fraction - $elapsed);
            }
        }
        print "\n";
        printf "%20s %s\n", "Elapsed time:",
            format_time($elapsed);
        printf "%20s %s\n", "Estimated left:",
            (defined $left) ? format_time($left) : "-";

        $args{bottom}->($elapsed, $rows, $cols);
    }

}

sub setup_logging {
    my ($dir, $file) = @_;


    RT->Config->Set(LogToSTDERR    => 'warning');
    RT->Config->Set(LogToFile      => 'warning');
    RT->Config->Set(LogDir         => $dir);
    RT->Config->Set(LogToFileNamed => $file);
    RT->Config->Set(LogStackTraces => 'error');

    undef $RT::Logger;
    RT->InitLogging();

    my $logger = $RT::Logger->output('file') || $RT::Logger->output("rtlog");
    return $logger ? $logger->{filename} : undef;
}

1;
