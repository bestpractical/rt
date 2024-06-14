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

  RT::Action::ForwardTicketOrTransaction

=head1 DESCRIPTION

ForwardTicketOrTransaction is a ScripAction which is meant to be called from
rt-crontool. (see C<rt-crontool -h> for more details)

ForwardTicketOrTransaction allows forwarding of a ticket or ticket
transaction to the specified email, optionally with some content to use
as the content of the forward transaction that is added to the ticket.

To use with C<rt-crontool>, specify the email with C<--action-arg>:

    --action RT::Action::ForwardTicketOrTransaction
    --action-arg "your_email@domain.com"

To forward a ticket exclude the C<--transaction> arg and to forward a
ticket transaction include it:

    --transaction [first|last]

It is not possible to forward a specific ticket transaction at this
time, just the first or last transaction.

To specify the content of the forward transaction create a template and
specify it with C<--template>:

    --template "Your Template"

The template may include the following headers:

=over

=item ContentType

Set ContentType header in the template to text/html for html content in
the forward transaction email

=item Cc

Set CC email addresses that will receive a copy of the forward
transaction email

=item Bcc

Set Bcc email addresses that will receive a copy of the forward
transaction email

=item Subject

Set Subject header to control the subject of the forward transaction
email

=back

=cut

package RT::Action::ForwardTicketOrTransaction;
use base 'RT::Action';

use strict;
use warnings;

sub Describe  {
  my $self = shift;
  return (ref $self . " will forward a ticket transaction to the email provided as the Argument.");
}

sub Prepare  {
    my $self = shift;

    $self->{_to} = $self->Argument || '';

    if ( $self->TemplateObj ) {
        my ( $result, $message ) = $self->TemplateObj->Parse(
            Ticket      => $self->TicketObj,
            Transaction => $self->TransactionObj,
        );

        if ( ! $result ) {
            return ( undef );
        }

        my $mime = $self->TemplateObj->MIMEObj;
        foreach my $header ( qw( Bcc Cc ContentType Subject ) ) {
            $self->{"_$header"} = $mime->head->get($header);
        }
        $self->{_content} = $mime->bodyhandle->as_string;
    }

    if ( $self->{_to} ) {
        return 1;
    }
    else {
        RT->Logger->warning('No email argument for RT::Action::ForwardTicketOrTransaction');
        return;
    }
}

sub Commit {
    my $self = shift;

    my $ticket = $self->TicketObj;
    my $txn    = $self->TransactionObj;

    my %args = (
        Transaction => $txn,
        To          => $self->{_to},
    );

    foreach my $header ( qw( Bcc Cc ContentType Subject ) ) {
        $args{$header} = $self->{"_$header"}
            if $self->{"_$header"};
    }
    $args{Content} = $self->{_content}
        if $self->{_content};

    my ( $ret, $msg ) = $ticket->Forward(%args);

    RT->Logger->warning("Failed to Forward Transaction: $msg")
        unless $ret;

    return $ret;
}

RT::Base->_ImportOverlays();

1;
