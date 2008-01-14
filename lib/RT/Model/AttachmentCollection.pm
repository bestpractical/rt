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
=head1 name

  RT::Model::AttachmentCollection - a collection of RT::Model::Attachment objects

=head1 SYNOPSIS

  use RT::Model::AttachmentCollection;

=head1 DESCRIPTION

This module should never be called directly by client code. it's an internal module which
should only be accessed through exported APIs in Ticket, Queue and other similar objects.


=head1 METHODS



=cut


use warnings;
use strict;
package RT::Model::AttachmentCollection;
use base qw/RT::SearchBuilder/;

use RT::Model::Attachment;

sub _init   {
    my $self = shift;
    $self->{'table'} = "Attachments";
    $self->{'primary_key'} = "id";
    $self->order_by(
        column => 'id',
        order => 'ASC',
    );
    return $self->SUPER::_init( @_ );
}

sub clean_slate {
    my $self = shift;
    delete $self->{_sql_transaction_alias};
    return $self->SUPER::clean_slate( @_ );
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

    my $res = $self->new_alias('Transactions');
    $self->limit(
        entry_aggregator => 'AND',
        column           => 'TransactionId',
        value           => $res . '.id',
        quote_value      => 0,
    );
    return $self->{'_sql_transaction_alias'} = $res;
}

=head2 ContentType (value => 'text/plain', entry_aggregator => 'OR', operator => '=' ) 

Limit result set to attachments of ContentType 'TYPE'...

=cut


sub ContentType  {
    my $self = shift;
    my %args = (
        value           => 'text/plain',
	    operator        => '=',
	    entry_aggregator => 'OR',
	    @_
    );

    return $self->limit ( %args, column => 'ContentType' );
}

=head2 ChildrenOf ID

Limit result set to children of Attachment ID

=cut


sub ChildrenOf  {
    my $self = shift;
    my $attachment = shift;
    return $self->limit(
        column => 'Parent',
        value => $attachment
    );
}

=head2 limit_NotEmpty

Limit result set to attachments with not empty content.

=cut

sub limit_NotEmpty {
    my $self = shift;
    $self->limit(
        entry_aggregator => 'AND',
        column           => 'Content',
        operator        => 'IS NOT',
        value           => 'NULL',
        quote_value      => 0,
    );
    $self->limit(
        entry_aggregator => 'AND',
        column           => 'Content',
        operator        => '!=',
        value           => '',
    );
    return;
}

=head2 limit_ByTicket $ticket_id

Limit result set to attachments of a ticket.

=cut

sub limit_ByTicket {
    my $self = shift;
    my $tid = shift;

    my $transactions = $self->TransactionAlias;
    $self->limit(
        entry_aggregator => 'AND',
        alias           => $transactions,
        column           => 'object_type',
        value           => 'RT::Model::Ticket',
    );

    my $tickets = $self->new_alias('Tickets');
    $self->limit(
        entry_aggregator => 'AND',
        alias           => $tickets,
        column           => 'id',
        value           => $transactions . '.object_id',
        quote_value      => 0,
    );
    $self->limit(
        entry_aggregator => 'AND',
        alias           => $tickets,
        column           => 'EffectiveId',
        value           => $tid,
    );
    return;
}

# {{{ sub new_item 
sub new_item  {
  my $self = shift;
  return RT::Model::Attachment->new;
}
# }}}

# {{{ sub next
sub next {
    my $self = shift;

    my $Attachment = $self->SUPER::next;
    return $Attachment unless $Attachment;

    my $txn = $Attachment->transaction_obj;
    if ( $txn->__value('Type') eq 'comment' ) {
        return $Attachment if $txn->current_user_has_right('ShowTicketcomments');
    } elsif ( $txn->current_user_has_right('ShowTicket') ) {
        return $Attachment;
    }

    # If the user doesn't have the right to show this ticket
    return $self->next;
}
# }}}

1;
