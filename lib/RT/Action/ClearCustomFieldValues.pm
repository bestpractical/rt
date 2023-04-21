# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

RT::Action::ClearCustomFieldValues - clear all the values of a custom
field on a ticket

=head1 DESCRIPTION

ClearCustomFieldValues clears the values of a custom field on a ticket.
For multiple value custom fields, this action will clear all values.

Since it requires a Custom Field name or ID as an argument, you need
to create a specific Action with this ScripAction module and set
"Parameters to Pass" with the desired Custom Field to be cleared.

=head1 USAGE

Assume you have a date custom field called 'Next Follow Up'.
When a ticket is resolved, you want to clear the date value because
no more follow-ups are needed.

The first step is to create a new Custom Action. Go to Admin -> Global
-> Actions and find "Clear Custom Field Value Template" in the action
list. Click on that action, then click Copy Action to create a new Action.

Update the fields with your new custom field information, for example:

    Name: Clear Next Follow Up
    Description: Clear Next Follow Up custom field
    Action Module: ClearCustomFieldValues
    Parameters to Pass: Next Follow Up

For "Parameters to Pass", add the custom field name or ID that you
want to clear.

Finally, create a new Scrip with the Custom Action you have just created.
Go to Admin -> Scrips -> Create.

Fill out the new Scrip with the following information:

    Description: Clear Next Follow Up custom field on Resolve
    Condition: On Resolve
    Action: Clear Next Follow Up
    Template: Blank
    Stage: Normal

=cut

package RT::Action::ClearCustomFieldValues;
use base 'RT::Action';

use strict;
use warnings;

sub Describe  {
    my $self = shift;
    return (ref $self .
    " clears the value of the custom field provided in the Argument.");
}


sub Prepare  {
    my $self = shift;
    my $ticket = $self->TicketObj;

    # Check if custom field identifier is provided
    unless ( $self->Argument ) {
        RT->Logger->error( "No custom field identifier provided. Skipping" );
        return 0;
    }

    # Can we load the custom field?
    my $cf = $ticket->LoadCustomFieldByIdentifier( $self->Argument );
    unless ( $cf->Id ) {
        RT->Logger->debug( "Unable to load custom field from " . $self->Argument );
        return 0;
    }

    return 1;
}

sub Commit {
    my $self = shift;

    # Get the current value of the custom field
    my $ocfvs_obj = $self->TicketObj->CustomFieldValues($self->Argument);

    unless ( $ocfvs_obj->Count ) {
        # No values, nothing to do
        return 1;
    }

    # For each value, delete it
    foreach my $cfvalue ( @{$ocfvs_obj->ItemsArrayRef} ) {
        my ($ret, $msg) = $self->TicketObj->DeleteCustomFieldValue(
            Field => $self->Argument,
            Value => $cfvalue->Content
        );
        unless ( $ret ) {
            RT->Logger->error( "Unable to delete custom field value $cfvalue: $msg" );
        }
    }

    return 1;
}

RT::Base->_ImportOverlays();

1;
