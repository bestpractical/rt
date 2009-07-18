# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
package RT::ScripAction::Notify;

use strict;
use warnings;

use base qw(RT::ScripAction::SendEmail);

use Email::Address;

=head1 NAME

RT::ScripAction::Notify - notify recipients

=head1 DESCRIPTION

This scrip action notifies various recipients by email. List of
recipients is controlled using argument of the action.

=head1 ARGUMENT

Comma separated list of entries, where each entry can be in the following format:

    [{queue, ticket} ] <recipient> [ as {to, cc, bcc}]

As recipient the following can be used:

=over 4

=item 'other recipients' - one time recipients, there are two boxes on reply/comment
pages where users can put these recipients.

=item 'owner' - owner of the ticket.

=item 'some role' - any role in the system. Without prefix members of both queue's
and ticket's role groups are notified. Either 'queue' or 'ticket' prefix can be used
to notify only one group, for example:

    ticket requestor

=back

Each entry may define the way mail delivered: 'to', 'cc' or 'bcc', by default
it's 'to'. For example:

    owner as to
    admin cc as cc

Complete example:

    requestor, owner as cc, other recipients, ticket cc as cc

=head1 METHODS

=head2 prepare

Set up the relevant recipients, then call our parent.

=cut

sub prepare {
    my $self = shift;
    $self->set_recipients;
    $self->SUPER::prepare;
}

=head2 set_recipients

Sets the recipients of this meesage to Owner, Requestor, AdminCc, Cc or All. 
Explicitly B<does not> notify the creator of the transaction by default

=cut

sub set_recipients {
    my $self = shift;

    my $ticket = $self->ticket_obj;

    my %recipients = (
        to  => [], mandatory_to  => [],
        cc  => [], mandatory_cc  => [],
        bcc => [], mandatory_bcc => [],
    );
    foreach my $block ( $self->parse_argument ) {
        if ( $block->{'recipient'} eq 'other recipients' ) {
            if ( my $attachment = $self->transaction->attachments->first ) {
                push @{ $recipients{'mandatory_cc'} ||= [] },
                    map $_->address, Email::Address->parse( $attachment->get_header('RT-Send-Cc') );
                push @{ $recipients{'mandatory_bcc'} ||= [] },
                    map $_->address, Email::Address->parse( $attachment->get_header('RT-Send-Bcc') );
            }
        }
        elsif ( $block->{'recipient'} eq 'owner' ) {
            if ( $ticket->owner->id != RT->nobody->id ) {
                push @{ $recipients{ $block->{'in'} } }, $ticket->owner->email;
            }
        }
        else {
            my $in = $recipients{ $block->{'in'} };
            if ( ($block->{'mode'} || 'queue') eq 'queue' ) {
                push @$in, $ticket->queue->role_group( $block->{'recipient'} )->member_emails;
            }
            if ( ($block->{'mode'} || 'ticket') eq 'ticket' ) {
                push @$in, $ticket->role_group( $block->{'recipient'} )->member_emails;
            }
        }
    }

    my $skip = '';
    unless ( RT->config->get('notify_actor') ) {
        if ( my $creator = $self->transaction->creator->email ) {
            $skip = lc $creator;
        }
    }


    my %seen;
    foreach my $type ( qw(to cc bcc) ) {
        # delete empty
        @{ $recipients{ $type } } = grep defined && length, @{ $recipients{ $type } };

        # skip actor
        @{ $recipients{ $type } } = grep lc($_) ne $skip, @{ $recipients{ $type } }
            if $skip;

        # merge mandatory
        push @{ $recipients{ $type } }, grep defined && length, @{ delete $recipients{ "mandatory_$type" } };

        # skip duplicates
        @{ $recipients{ $type } } = grep !$seen{ lc $_ }++, @{ $recipients{ $type } };
    }

    unless ( @{ $recipients{'to'} } ) {
        $recipients{'to'} = delete $recipients{'cc'};
    }

    if ( my $format = RT->config->get('use_friendly_to_line') ) {
        unless ( @{ $recipients{'to'} } ) {
            push @{ $self->{'PseudoTo'} ||= [] }, sprintf $format, $self->argument, $ticket->id;
        }
    }

    @{ $self }{qw(To Cc Bcc)} = @recipients{ qw(to cc bcc) };

}

my $re_entry = qr{(?:(ticket|queue)\s+)?([^,]+?)(?:\s+as\s+(to|cc|bcc))?}i;

sub parse_argument {
    my $self = shift;

    my @res;

    my @parts = grep length, map { s/^\s+//; s/\s+$//; $_ } split /,/, $self->argument;
    foreach ( @parts ) {
        unless ( /^$re_entry$/o ) {
            Jifty->log->error("couldn't parse argument $_");
            next;
        }
        my ($mode, $recipient, $in) = ($1||'', $2, $3 || 'to');
        for ( $mode, $recipient, $in ) {
            s/^\s+//; s/\s+$//; s/\s+/ /g;
            $_ = lc $_;
        }
        push @res, { mode => $mode, recipient => $recipient, in => $in };
    }
    return @res;
}

1;
