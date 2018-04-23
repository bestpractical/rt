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

=head1 NAME

RT::Action::LinearEscalate - will move a ticket's priority toward its final priority.

=head1 This vs. RT::Action::EscalatePriority

This action doesn't change priority if due date is not set.

This action honor the Starts date.

This action can apply changes silently.

This action can replace EscalatePriority completly. If you want to tickets
that have been created without Due date then you can add scrip that sets
default due date. For example a week then priorities of your tickets will
escalate linearly during the week from intial value towards final.

=head1 This vs. LinearEscalate from the CPAN

This action is an integration of the module from the CPAN into RT's core
that's happened in RT 3.8. If you're upgrading from 3.6 and have been using
module from the CPAN with old version of RT then you should uninstall it
and use this one.

However, this action doesn't support control over config. Read </CONFIGURATION>
to find out ways to deal with it.

=head1 DESCRIPTION

LinearEscalate is a ScripAction that will move a ticket's priority
from its initial priority to its final priority linearly as
the ticket approaches its due date.

It's intended to be called by an RT escalation tool. One such tool is called
rt-crontool and is located in $RTHOME/bin (see C<rt-crontool -h> for more details).

=head1 USAGE

Once the ScripAction is installed, the following script in "cron" 
will get tickets to where they need to be:

    rt-crontool --search RT::Search::FromSQL --search-arg \
    "(Status='new' OR Status='open' OR Status = 'stalled')" \
    --action RT::Action::LinearEscalate

The Starts date is associated with intial ticket's priority or
the Created field if the former is not set. End of interval is
the Due date. Tickets without due date B<are not updated>.

=head1 CONFIGURATION

Initial and Final priorities are controlled by queue's options
and can be defined using the web UI via Admin tab. This
action should handle correctly situations when initial priority
is greater than final.

LinearEscalate's behavior can be controlled by two options:

=over 4

=item RecordTransaction - defaults to false and if option is true then
causes the tool to create a transaction on the ticket when it is escalated.

=item UpdateLastUpdated - which defaults to true and updates the LastUpdated
field when the ticket is escalated, otherwise don't touch anything.

=back

You cannot set "UpdateLastUpdated" to false unless "RecordTransaction"
is also false. Well, you can, but we'll just ignore you.

You can set this options using either in F<RT_SiteConfig.pm>, as action
argument in call to the rt-crontool or in DB if you want to use the action
in scrips.

From a shell you can use the following command:

    rt-crontool --search RT::Search::FromSQL --search-arg \
    "(Status='new' OR Status='open' OR Status = 'stalled')" \
    --action RT::Action::LinearEscalate \
    --action-arg "RecordTransaction: 1"

This ScripAction uses RT's internal _Set or __Set calls to set ticket
priority without running scrips or recording a transaction on each
update, if it's been said to.

=cut

package RT::Action::LinearEscalate;

use strict;
use warnings;
use base qw(RT::Action);

#Do what we need to do and send it out.

#What does this type of Action does

sub Describe {
    my $self = shift;
    my $class = ref($self) || $self;
    return "$class will move a ticket's priority toward its final priority.";
}

sub Prepare {
    my $self = shift;

    my $ticket = $self->TicketObj;

    unless ( $ticket->DueObj->IsSet ) {
        $RT::Logger->debug('Due is not set. Not escalating.');
        return 1;
    }

    my $priority_range = ($ticket->FinalPriority ||0) - ($ticket->InitialPriority ||0);
    unless ( $priority_range ) {
        $RT::Logger->debug('Final and Initial priorities are equal. Not escalating.');
        return 1;
    }

    if ( $ticket->Priority >= $ticket->FinalPriority && $priority_range > 0 ) {
        $RT::Logger->debug('Current priority is greater than final. Not escalating.');
        return 1;
    }
    elsif ( $ticket->Priority <= $ticket->FinalPriority && $priority_range < 0 ) {
        $RT::Logger->debug('Current priority is lower than final. Not escalating.');
        return 1;
    }

    # TODO: compute the number of business days until the ticket is due

    # now we know we have a due date. for every day that passes,
    # increment priority according to the formula

    my $starts = $ticket->StartsObj->IsSet ? $ticket->StartsObj->Unix : $ticket->CreatedObj->Unix;
    my $now    = time;

    # do nothing if we didn't reach starts or created date
    if ( $starts > $now ) {
        $RT::Logger->debug('Starts(Created) is in future. Not escalating.');
        return 1;
    }

    my $due = $ticket->DueObj->Unix;
    $due = $starts + 1 if $due <= $starts; # +1 to avoid div by zero

    my $percent_complete = ($now-$starts)/($due - $starts);

    my $new_priority = int($percent_complete * $priority_range) + ($ticket->InitialPriority || 0);
    $new_priority = $ticket->FinalPriority if $new_priority > $ticket->FinalPriority;
    $self->{'new_priority'} = $new_priority;

    return 1;
}

sub Commit {
    my $self = shift;

    my $new_value = $self->{'new_priority'};
    return 1 unless defined $new_value;

    my $ticket = $self->TicketObj;
    # if the priority hasn't changed do nothing
    return 1 if $ticket->Priority == $new_value;

    # override defaults from argument
    my ($record, $update) = (0, 1);
    {
        my $arg = $self->Argument || '';
        if ( $arg =~ /RecordTransaction:\s*(\d+)/i ) {
            $record = $1;
            $RT::Logger->debug("Overrode RecordTransaction: $record");
        } 
        if ( $arg =~ /UpdateLastUpdated:\s*(\d+)/i ) {
            $update = $1;
            $RT::Logger->debug("Overrode UpdateLastUpdated: $update");
        }
        $update = 1 if $record;
    }

    $RT::Logger->debug(
        'Linearly escalating priority of ticket #'. $ticket->Id
        .' from '. $ticket->Priority .' to '. $new_value
        .' and'. ($record? '': ' do not') .' record a transaction'
        .' and'. ($update? '': ' do not') .' touch last updated field'
    );

    my ( $val, $msg );
    unless ( $record ) {
        unless ( $update ) {
            ( $val, $msg ) = $ticket->__Set(
                Field => 'Priority',
                Value => $new_value,
            );
        }
        else {
            ( $val, $msg ) = $ticket->_Set(
                Field => 'Priority',
                Value => $new_value,
                RecordTransaction => 0,
            );
        }
    }
    else {
        ( $val, $msg ) = $ticket->SetPriority( $new_value );
    }

    unless ($val) {
        $RT::Logger->error( "Couldn't set new priority value: $msg" );
        return (0, $msg);
    }
    return 1;
}

RT::Base->_ImportOverlays();

1;
