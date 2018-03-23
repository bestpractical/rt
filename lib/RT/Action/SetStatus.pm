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

package RT::Action::SetStatus;

use strict;
use warnings;
use base qw(RT::Action);

=head1 NAME

RT::Action::SetStatus - RT's scrip action to set status of a ticket

=head1 DESCRIPTION

This action changes status to a new value according to the rules in L</ARGUMENT>.
Status is not changed if the transition is invalid or another error occurs. All
issues are logged at apropriate levels.

=head1 ARGUMENT

Argument can be one of the following:

=over 4

=item status literally

Status is changed from the current value to a new defined by the argument,
but only if it's valid status and allowed by transitions of the current lifecycle,
for example:

    * The current status is 'stalled'
    * Argument of this action is 'open'
    * The only possible transition in the scheam from 'stalled' is 'open'
    * Status is changed

However, in the example above Status is not changed if argument is anything
else as it's just not allowed by the lifecycle.

=item 'initial', 'active' or 'inactive'

Status is changed from the current value to first possible 'initial',
'active' or 'inactive' correspondingly. First possible value is figured
according to transitions to the target set, for example:

    * The current status is 'open'
    * Argument of this action is 'inactive'
    * Possible transitions from 'open' are 'resolved', 'rejected' or 'deleted'
    * Status is changed to 'resolved'

=back

=cut

sub Prepare {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $lifecycle = $ticket->LifecycleObj;
    my $status = $ticket->Status;

    my $argument = $self->Argument;
    unless ( $argument ) {
        $RT::Logger->error("Argument is mandatory for SetStatus action");
        return 0;
    }

    my $next = '';
    if ( $argument =~ /^(initial|active|inactive)$/i ) {
        my $method = 'Is'. ucfirst lc $argument;
        ($next) = grep $lifecycle->$method($_), $lifecycle->Transitions($status);
        unless ( $next ) {
            $RT::Logger->info("No transition from '$status' to $argument set");
            return 1;
        }
    }
    elsif ( $lifecycle->IsValid( $argument ) ) {
        unless ( $lifecycle->IsTransition( $status => $argument ) ) {
            $RT::Logger->warning("Transition '$status -> $argument' is not valid");
            return 1;
        }
        $next = $argument;
    }
    else {
        $RT::Logger->error("Argument for SetStatus action is not valid status or one of set");
        return 0;
    }

    $self->{'set_status_to'} = $next;

    return 1;
}

sub Commit {
    my $self = shift;

    return 1 unless my $new_status = $self->{'set_status_to'};

    my ($val, $msg) = $self->TicketObj->SetStatus( $new_status );
    unless ( $val ) {
        $RT::Logger->error( "Couldn't set status: ". $msg );
        return 0;
    }
    return 1;
}

1;
