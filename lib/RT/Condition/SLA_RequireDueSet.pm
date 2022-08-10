# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2022 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Condition::SLA_RequireDueSet;

use base qw(RT::Condition::SLA);

=head1 NAME

RT::Condition::SLA_RequireDueSet - checks if Due date require update

=head1 DESCRIPTION

Checks if Due date require update. This should be done when we create
a ticket and it has service level value or when we set service level.

=cut

sub IsApplicable {
    my $self = shift;
    return 0 unless $self->SLAIsApplied;
    return 0 if $self->TicketObj->QueueObj->SLADisabled;

    my $type = $self->TransactionObj->Type;
    if ( $type eq 'Create' || $type eq 'Correspond' ) {
        return 1 if $self->TicketObj->SLA;
        return 0;
    }
    elsif ( $type eq 'Status' || ($type eq 'Set' && $self->TransactionObj->Field eq 'Status') ) {
        return 1 if $self->TicketObj->SLA;
        return 0;
    }
    elsif ( $type eq 'SLA' || ($type eq 'Set' && $self->TransactionObj->Field eq 'SLA') ) {
        return 1;
    }
    return 0;
}

1;
