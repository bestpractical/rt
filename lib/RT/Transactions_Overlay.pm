# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

  RT::Transactions - a collection of RT Transaction objects

=head1 SYNOPSIS

  use RT::Transactions;


=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Transactions;

use strict;
no warnings qw(redefine);

# {{{ sub _Init  
sub _Init   {
  my $self = shift;
  
  $self->{'table'} = "Transactions";
  $self->{'primary_key'} = "id";
  
  # By default, order by the date of the transaction, rather than ID.
  $self->OrderByCols( { FIELD => 'Created',
			ORDER => 'ASC' },
		      { FIELD => 'id',
			ORDER => 'ASC' } );

  return ( $self->SUPER::_Init(@_));
}
# }}}

=head2 LimitToTicket TICKETID 

Find only transactions for the ticket whose id is TICKETID.

This includes tickets merged into TICKETID.

Repeated calls to this method will intelligently limit down to that set of tickets, joined with an OR


=cut


sub LimitToTicket {
    my $self = shift;
    my $tid  = shift;

    unless ( $self->{'tickets_table'} ) {
        $self->{'tickets_table'} ||= $self->NewAlias('Tickets');
        $self->Join(
            ALIAS1 => 'main',
            FIELD1 => 'ObjectId',
            ALIAS2 => $self->{'tickets_table'},
            FIELD2 => 'id'
        );
        $self->Limit(
            FIELD => 'ObjectType',
            VALUE => 'RT::Ticket',
        );
    }
    $self->Limit(
        ALIAS           => $self->{tickets_table},
        FIELD           => 'EffectiveId',
        OPERATOR        => '=',
        ENTRYAGGREGATOR => 'OR',
        VALUE           => $tid,
    );

}


# {{{ sub Next
sub Next {
    my $self = shift;
 	
    my $Transaction = $self->SUPER::Next();
    if ((defined($Transaction)) and (ref($Transaction))) {
    	# If the user can see the transaction's type, then they can 
	#  see the transaction and we should hand it back.
	if ($Transaction->Type) {
	    return($Transaction);
	}

	#If the user doesn't have the right to show this ticket
	else {	
	    return($self->Next());
	}
    }

    #if there never was any ticket
    else {
	return(undef);
    }	
}
# }}}



1;

