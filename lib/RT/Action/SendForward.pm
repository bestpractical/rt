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
package RT::Action::SendForward;

use strict;
use warnings;

use base qw(RT::Action::SendEmail);

use Email::Address;

=head2 Prepare

=cut

sub Prepare {
    my $self = shift;

    my $txn = $self->TransactionObj;

    if ( $txn->Type eq 'Forward Transaction' ) {
        my $forwarded_txn = RT::Transaction->new( $self->CurrentUser );
        $forwarded_txn->Load( $txn->Field );
        $self->{ForwardedTransactionObj} = $forwarded_txn;
    }

    my ( $result, $message ) = $self->TemplateObj->Parse(
        Argument           => $self->Argument,
        Ticket             => $self->TicketObj,
        Transaction        => $self->ForwardedTransactionObj,
        ForwardTransaction => $self->TransactionObj,
    );

    if ( !$result ) {
        return (undef);
    }

    my $mime = $self->TemplateObj->MIMEObj;
    $mime->make_multipart unless $mime->is_multipart;

    my $entity;
    if ( $txn->Type eq 'Forward Transaction' ) {
        $entity = $self->ForwardedTransactionObj->ContentAsMIME;
    }
    else {
        my $txns = $self->TicketObj->Transactions;
        $txns->Limit(
            FIELD    => 'Type',
            OPERATOR => 'IN',
            VALUE    => [qw(Create Correspond)],
        );

        $entity = MIME::Entity->build(
            Type        => 'multipart/mixed',
            Description => 'forwarded ticket',
        );
        $entity->add_part($_) foreach
          map $_->ContentAsMIME,
          @{ $txns->ItemsArrayRef };
    }

    $mime->add_part($entity);

    my $txn_attachment = $self->TransactionObj->Attachments->First;
    for my $header (qw/From To Cc Bcc/) {
        if ( $txn_attachment->GetHeader( $header ) ) {
            $mime->head->replace( $header => Encode::encode( "UTF-8", $txn_attachment->GetHeader($header) ) );
        }
    }

    if ( RT->Config->Get('ForwardFromUser') ) {
        $mime->head->replace( 'X-RT-Sign' => 0 );
    }

    $self->SUPER::Prepare();
}

sub SetSubjectToken {
    my $self = shift;
    return if RT->Config->Get('ForwardFromUser');
    $self->SUPER::SetSubjectToken(@_);
}

sub ForwardedTransactionObj {
    my $self = shift;
    return $self->{'ForwardedTransactionObj'};
}

RT::Base->_ImportOverlays();

1;
