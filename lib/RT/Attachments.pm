# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

  RT::Attachments - a collection of RT::Attachment objects

=head1 SYNOPSIS

  use RT::Attachments;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=head1 METHODS



=cut


package RT::Attachments;
use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Attachment;

sub Table { 'Attachments'}


use RT::Attachment;

sub _Init   {
    my $self = shift;
    $self->{'table'} = "Attachments";
    $self->{'primary_key'} = "id";
    $self->OrderBy(
        FIELD => 'id',
        ORDER => 'ASC',
    );
    return $self->SUPER::_Init( @_ );
}

sub CleanSlate {
    my $self = shift;
    delete $self->{_sql_transaction_alias};
    return $self->SUPER::CleanSlate( @_ );
}


=head2 TransactionAlias

Returns alias for transactions table with applied join condition.
Always return the same alias, so if you want to build some complex
or recursive joining then you have to create new alias youself.

=cut

sub TransactionAlias {
    my $self = shift;
    return $self->{'_sql_transaction_alias'}
        if $self->{'_sql_transaction_alias'};

    return $self->{'_sql_transaction_alias'} = $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'TransactionId',
        TABLE2 => 'Transactions',
        FIELD2 => 'id',
    );
}

=head2 ContentType (VALUE => 'text/plain', ENTRYAGGREGATOR => 'OR', OPERATOR => '=' ) 

Limit result set to attachments of ContentType 'TYPE'...

=cut


sub ContentType  {
    my $self = shift;
    my %args = (
        VALUE           => 'text/plain',
        OPERATOR        => '=',
        ENTRYAGGREGATOR => 'OR',
        @_
    );

    return $self->Limit ( %args, FIELD => 'ContentType' );
}

=head2 ChildrenOf ID

Limit result set to children of Attachment ID

=cut


sub ChildrenOf  {
    my $self = shift;
    my $attachment = shift;
    return $self->Limit(
        FIELD => 'Parent',
        VALUE => $attachment
    );
}

=head2 LimitNotEmpty

Limit result set to attachments with not empty content.

=cut

sub LimitNotEmpty {
    my $self = shift;
    $self->Limit(
        ENTRYAGGREGATOR => 'AND',
        FIELD           => 'Content',
        OPERATOR        => 'IS NOT',
        VALUE           => 'NULL',
        QUOTEVALUE      => 0,
    );

    # http://rt3.fsck.com/Ticket/Display.html?id=12483
    if ( RT->Config->Get('DatabaseType') ne 'Oracle' ) {
        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'Content',
            OPERATOR        => '!=',
            VALUE           => '',
        );
    }
    return;
}

=head2 LimitHasFilename

Limit result set to attachments with not empty filename.

=cut

sub LimitHasFilename {
    my $self = shift;

    $self->Limit(
        ENTRYAGGREGATOR => 'AND',
        FIELD           => 'Filename',
        OPERATOR        => 'IS NOT',
        VALUE           => 'NULL',
        QUOTEVALUE      => 0,
    );

    if ( RT->Config->Get('DatabaseType') ne 'Oracle' ) {
        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'Filename',
            OPERATOR        => '!=',
            VALUE           => '',
        );
    }

    return;
}

=head2 LimitByTicket $ticket_id

Limit result set to attachments of a ticket.

=cut

sub LimitByTicket {
    my $self = shift;
    my $tid = shift;

    my $transactions = $self->TransactionAlias;
    $self->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS           => $transactions,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
    );

    my $tickets = $self->Join(
        ALIAS1 => $transactions,
        FIELD1 => 'ObjectId',
        TABLE2 => 'Tickets',
        FIELD2 => 'id',
    );
    $self->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS           => $tickets,
        FIELD           => 'EffectiveId',
        VALUE           => $tid,
    );
    return;
}

sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->TransactionObj->CurrentUserCanSee;
    return $self->SUPER::AddRecord( $record );
}

=head2 ReplaceAttachments ( Search => 'SEARCH', Replacement => 'Replacement', Header => 1, Content => 1 )

Provide a search string to search the attachments table for, by default the Headers and Content
columns will both be searched for matches.

=cut

sub ReplaceAttachments {
    my $self = shift;
    my %args = (
        Search      => undef,
        Replacement => '',
        Headers     => 1,
        Content     => 1,
        FilterBySearchString => 1,
        @_,
    );

    return ( 0, $self->loc('Provide a search string to search on') ) unless $args{Search};


    my %munged;
    my $create_munge_txn = sub {
        my $ticket = shift;
        if ( !$munged{ $ticket->id } ) {
            my ( $ret, $msg ) = $ticket->_NewTransaction( Type => "Munge" );
            if ($ret) {
                $munged{ $ticket->id } = 1;
            }
            else {
                RT::Logger->error($msg);
            }
        }
    };

    my $attachments = $self->Clone;
    if ( $args{FilterBySearchString} ) {
        $attachments->Limit(
            FIELD     => 'ContentEncoding',
            VALUE     => 'none',
            SUBCLAUSE => 'Encoding',
        );
        $attachments->Limit(
            FIELD     => 'ContentEncoding',
            OPERATOR  => 'IS',
            VALUE     => 'NULL',
            SUBCLAUSE => 'Encoding',
        );

        # For QP encoding, if encoded string is equal to the decoded
        # version, then SQL search will also work.
        #
        # Adding "\n" is to avoid trailing "=" in QP encoding
        if ( MIME::QuotedPrint::encode( Encode::encode( 'UTF-8', "$args{Search}\n" ) ) eq
            Encode::encode( 'UTF-8', "$args{Search}\n" ) )
        {
            $attachments->Limit(
                FIELD     => 'ContentEncoding',
                VALUE     => 'quoted-printable',
                SUBCLAUSE => 'Encoding',
            );
        }
    }

    if ( $args{Headers} ) {
        my $atts = $attachments->Clone;
        if ( $args{FilterBySearchString} ) {
            $atts->Limit(
                FIELD    => 'Headers',
                OPERATOR => 'LIKE',
                VALUE    => $args{Search},
            );
        }
        $atts->Limit(
            FIELD     => 'ContentType',
            OPERATOR  => 'IN',
            VALUE     => [ RT::Util::EmailContentTypes(), 'text/plain', 'text/html' ],
            SUBCLAUSE => 'Types',
        );
        $atts->Limit(
            FIELD           => 'ContentType',
            OPERATOR        => 'STARTSWITH',
            VALUE           => 'multipart/',
            SUBCLAUSE       => 'Types',
            ENTRYAGGREGATOR => 'OR',
        );

        while ( my $att = $atts->Next ) {
            my ( $ret, $msg ) = $att->ReplaceHeaders(
                Search      => $args{Search},
                Replacement => $args{Replacement},
            );

            if ( $ret ) {
                $create_munge_txn->( $att->TransactionObj->TicketObj );
            }
            else {
                RT::Logger->debug($msg);
            }
        }
    }

    if ( $args{Content} ) {
        my $atts = $attachments->Clone;
        if ( $args{FilterBySearchString} ) {
            $atts->Limit(
                FIELD     => 'Content',
                OPERATOR  => 'LIKE',
                VALUE     => $args{Search},
                SUBCLAUSE => 'Content',
            );
        }
        $atts->Limit(
            FIELD    => 'ContentType',
            OPERATOR => 'IN',
            VALUE    => [ 'text/plain', 'text/html' ],
        );

        while ( my $att = $atts->Next ) {
            my ( $ret, $msg ) = $att->ReplaceContent(
                Search      => $args{Search},
                Replacement => $args{Replacement},
            );

            if ( $ret ) {
                $create_munge_txn->( $att->TransactionObj->TicketObj );
            }
            else {
                RT::Logger->debug($msg);
            }
        }
    }

    my $count = scalar keys %munged;
    return wantarray ? ( 1, $self->loc( "Updated [quant,_1,ticket's,tickets'] attachment content", $count ) ) : $count;
}

RT::Base->_ImportOverlays();

1;
