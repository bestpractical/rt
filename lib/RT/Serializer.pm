# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::Serializer;

use strict;
use warnings;

use base 'RT::DependencyWalker';

use Storable qw//;
use DateTime;

sub Init {
    my $self = shift;

    $self->SUPER::Init(@_, First => "top");

    # Keep track of the number of each type of object written out
    $self->{ObjectCount} = {};
}

sub Walk {
    my $self = shift;

    # Set up our output file
    open($self->{Filehandle}, ">", "serialized.dat"
        or die "Can't write to serialized.dat: $!";

    # Walk the objects
    $self->SUPER::Walk( @_ );

    # Close everything back up
    close($self->{Filehandle})
        or die "Can't close serialized.dat: $!";
    $self->{FileCount}++;

    return $self->ObjectCount;
}

sub ObjectCount {
    my $self = shift;
    return %{ $self->{ObjectCount} };
}

sub Observe {
    my $self = shift;
    my %args = (
        object    => undef,
        direction => undef,
        from      => undef,
        @_
    );

    my $obj = $args{object};
    my $from = $args{from};
    if ($obj->isa("RT::ACE")) {
        return 0;
    } elsif ($obj->isa("RT::GroupMember")) {
        my $grp = $obj->GroupObj->Object;
        if ($grp->Domain =~ /^RT::(Queue|Ticket)-Role$/) {
            return 0 unless $grp->UID eq $from;
        } elsif ($grp->Domain eq "SystemInternal") {
            return 0 if $grp->UID eq $from;
        }
    } elsif ($obj->isa("RT::ObjectCustomField")) {
        return 0 if $from =~ /^RT::CustomField-/;
    }

    return 1;
}

sub Visit {
    my $self = shift;
    my %args = (
        object    => undef,
        @_
    );

    # Serialize it
    my $obj = $args{object};
    my @store = (
        ref($obj),
        $obj->UID,
        { $obj->Serialize },
    );

    # Write it out; nstore_fd doesn't trap failures to write, so we have
    # to; by clearing $! and checking it afterwards.
    $! = 0;
    Storable::nstore_fd(\@store, $self->{Filehandle});
    die "Failed to write to serialized.dat: $!" if $!;

    $self->{ObjectCount}{ref($obj)}++;
}

1;
