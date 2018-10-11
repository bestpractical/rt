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

#
package RT::Action::Notify;

use strict;
use warnings;

use base qw(RT::Action::SendEmail);

use Email::Address;
use Regexp::Common;

=head2 Prepare

Set up the relevant recipients, then call our parent.

=cut


sub Prepare {
    my $self = shift;
    $self->SetRecipients();
    $self->SUPER::Prepare();
}

=head2 SetRecipients

Sets the recipients of this message to Owner, Requestor, AdminCc, Cc or All.
Explicitly B<does not> notify the creator of the transaction by default.

=cut

sub SetRecipients {
    my $self = shift;

    my $ticket = $self->TicketObj;

    my $arg = $self->Argument;

    my ( @To, @PseudoTo, @Cc, @Bcc );

    my %args = map { $_ => 1 } $self->SplitArgument;

    if ( $args{All} ) {
        $args{$_} ||= 1 for qw/Owner Requestor AdminCc Cc/;
    }

    if ( $args{Requestor} ) {
        push @To, $ticket->Requestors->MemberEmailAddresses;
    }

    # custom role syntax:   gives:
    #   name                  (role name,  Cc)
    #   RT::CustomRole-#      (role with id, Cc)
    #   name/To               (role name,  To)
    #   RT::CustomRole-#/To   (role with id, To)
    #   name/Cc               (role name,  Cc)
    #   RT::CustomRole-#/Cc   (role with id, Cc)
    #   name/Bcc              (role name,  Bcc)
    #   RT::CustomRole-#/Bcc  (role with id, Bcc)

    # this has to happen early because adding To addresses affects how Cc
    # is handled

    for my $item ( sort keys %args ) {
        next if $item =~ /^(?:All|Owner|Requestor|AdminCc|Cc|OtherRecipients|AlwaysNotifyActor|NeverNotifyActor)$/;
        my ( $name, $type ) = ( $item =~ m{^(.+?)(?:/(To|Cc|Bcc))?$} );
        next unless $name;

        my $role;
        if ( $name =~ /^RT::CustomRole-(\d+)$/ ) {
            my $id = $1;
            $role = RT::CustomRole->new( $self->CurrentUser );
            $role->Load( $id );
        }
        else {
            my $roles = RT::CustomRoles->new( $self->CurrentUser );
            $roles->Limit( FIELD => 'Name', VALUE => $name, CASESENSITIVE => 0 );

            # custom roles are named uniquely, but just in case there are
            # multiple matches, bail out as we don't know which one to use
            $role = $roles->First;
            if ( $role ) {
                $role = undef if $roles->Next;
            }
        }

        unless ($role && $role->id) {
            $RT::Logger->debug("Unable to load custom role from scrip action argument '$item'");
            next;
        }

        my @role_members = (
            $ticket->RoleGroup($role->GroupType)->MemberEmailAddresses,
            $ticket->QueueObj->RoleGroup($role->GroupType)->MemberEmailAddresses,
        );

        if (!$type || $type eq 'Cc') {
            push @Cc, @role_members;
        }
        elsif ($type eq 'Bcc') {
            push @Bcc, @role_members;
        }
        elsif ($type eq 'To') {
            push @To, @role_members;
        }
    }

    if ( $args{Cc} ) {

        #If we have a To, make the Ccs, Ccs, otherwise, promote them to To
        if (@To) {
            push ( @Cc, $ticket->Cc->MemberEmailAddresses );
            push ( @Cc, $ticket->QueueObj->Cc->MemberEmailAddresses  );
        }
        else {
            push ( @Cc, $ticket->Cc->MemberEmailAddresses  );
            push ( @To, $ticket->QueueObj->Cc->MemberEmailAddresses  );
        }
    }

    if (   $args{Owner}
        && $ticket->OwnerObj->id != RT->Nobody->id
        && $ticket->OwnerObj->EmailAddress
        && not $ticket->OwnerObj->Disabled
    ) {
        # If we're not sending to Ccs or requestors,
        # then the Owner can be the To.
        if (@To) {
            push ( @Bcc, $ticket->OwnerObj->EmailAddress );
        }
        else {
            push ( @To, $ticket->OwnerObj->EmailAddress );
        }

    }

    if ( $args{AdminCc} ) {
        push ( @Bcc, $ticket->AdminCc->MemberEmailAddresses  );
        push ( @Bcc, $ticket->QueueObj->AdminCc->MemberEmailAddresses  );
    }

    if ( RT->Config->Get('UseFriendlyToLine') ) {
        unless (@To) {
            push @PseudoTo,
                sprintf RT->Config->Get('FriendlyToLineFormat'), $arg, $ticket->id;
        }
    }

    @{ $self->{'To'} }       = @To;
    @{ $self->{'Cc'} }       = @Cc;
    @{ $self->{'Bcc'} }      = @Bcc;
    @{ $self->{'PseudoTo'} } = @PseudoTo;

    if ( $args{OtherRecipients} ) {
        if ( my $attachment = $self->TransactionObj->Attachments->First ) {
            push @{ $self->{'NoSquelch'}{'Cc'} ||= [] }, map $_->address,
                Email::Address->parse( $attachment->GetHeader('RT-Send-Cc') );
            push @{ $self->{'NoSquelch'}{'Bcc'} ||= [] }, map $_->address,
                Email::Address->parse( $attachment->GetHeader('RT-Send-Bcc') );
        }
    }
}

=head2 RemoveInappropriateRecipients

Remove transaction creator as appropriate for the NotifyActor setting.

To send email to the selected recipients regardless of RT's NotifyActor
configuration, include AlwaysNotifyActor in the list of arguments. Or to
always suppress email to the selected recipients regardless of RT's
NotifyActor configuration, include NeverNotifyActor in the list of arguments.

=cut

sub RemoveInappropriateRecipients {
    my $self = shift;

    my $creatorObj = $self->TransactionObj->CreatorObj;
    my $creator = $creatorObj->EmailAddress() || '';
    my $TransactionCurrentUser = RT::CurrentUser->new;
    $TransactionCurrentUser->LoadByName($creatorObj->Name);

    my %args = map { $_ => 1 } $self->SplitArgument;

    $self->RecipientFilter(
        Callback => sub {
            return unless lc $_[0] eq lc $creator;
            return "not sending to $creator, creator of the transaction, due to NotifyActor setting";
        },
    ) if $args{NeverNotifyActor} ||
         (!RT->Config->Get('NotifyActor',$TransactionCurrentUser)
         && !$args{AlwaysNotifyActor});

    $self->SUPER::RemoveInappropriateRecipients();
}


=head2 SplitArgument

Split comma separated argument. Like CSV, it also supports quoted
values, so values like "'foo, bar'" is treated like a single value.

Return the list of the split values.

=cut

sub SplitArgument {
    my $self = shift;
    my $arg  = shift // $self->Argument;

    return unless defined $arg && length $arg;

    $arg =~ s!^\s+!!;
    $arg =~ s!\s+$!!;

    my @args;
    while ( $arg =~ s/^($RE{quoted}|[^,]+)(?:,\s*|$)//g ) {
        my $item = $1;
        if ( $item =~ /^(['"])(.*)\1/ ) {
            next unless length $2;
            push @args, $2;
        }
        else {
            push @args, $item;
        }
    }
    return @args;
}

RT::Base->_ImportOverlays();

1;
