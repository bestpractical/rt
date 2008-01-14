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

  RT::Model::TransactionCollection - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Model::TransactionCollection;


=head1 DESCRIPTION


=head1 METHODS


=cut

use warnings;
use strict;

package RT::Model::TransactionCollection;
use base qw/RT::SearchBuilder/;


# {{{ sub _init  
sub _init   {
  my $self = shift;
  
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  
  # By default, order by the date of the transaction, rather than ID.
  $self->order_by( { column => 'Created',
			order => 'ASC' },
		      { column => 'id',
			order => 'ASC' } );

  return ( $self->SUPER::_init(@_));
}
# }}}

=head2 limit_ToTicket TICKETID 

Find only transactions for the ticket whose id is TICKETID.

This includes tickets merged into TICKETID.

Repeated calls to this method will intelligently limit down to that set of tickets, joined with an OR


=cut


sub limit_ToTicket {
    my $self = shift;
    my $tid  = shift;

    unless ( $self->{'tickets_table'} ) {
        $self->{'tickets_table'} ||= $self->new_alias('Tickets');
        $self->join(
            alias1 => 'main',
            column1 => 'object_id',
            alias2 => $self->{'tickets_table'},
            column2 => 'id'
        );
        $self->limit(
            column => 'object_type',
            value => 'RT::Model::Ticket',
        );
    }
    $self->limit(
        alias           => $self->{tickets_table},
        column           => 'EffectiveId',
        operator        => '=',
        entry_aggregator => 'OR',
        value           => $tid,
    );

}


# {{{ sub next
sub next {
    my $self = shift;
 	
    my $Transaction = $self->SUPER::next();
    if ((defined($Transaction)) and (ref($Transaction))) {
    	# If the user can see the transaction's type, then they can 
	#  see the transaction and we should hand it back.
	if ($Transaction->Type) {
	    return($Transaction);
	}

	#If the user doesn't have the right to show this ticket
	else {	
	    return($self->next());
	}
    }

    #if there never was any ticket
    else {
	return(undef);
    }	
}
# }}}



1;

