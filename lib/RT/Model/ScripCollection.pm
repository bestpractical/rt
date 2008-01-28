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

  RT::Model::ScripCollection - a collection of RT Scrip objects

=head1 SYNOPSIS

  use RT::Model::ScripCollection;

=head1 DESCRIPTION


=head1 METHODS



=cut


use warnings;
use strict;
package RT::Model::ScripCollection;
use base qw/RT::SearchBuilder/;

# {{{ sub limit_ToQueue 

=head2 limit_ToQueue

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub limit_to_queue {
   my $self = shift;
  my $queue = shift;
 
  $self->limit (entry_aggregator => 'OR',
		column => 'Queue',
		value => "$queue")
      if defined $queue;
  
}
# }}}

# {{{ sub limit_ToGlobal

=head2 limit_ToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or limit_ToQueue

=cut


sub limit_to_global {
   my $self = shift;
 
  $self->limit (entry_aggregator => 'OR',
		column => 'Queue',
		value => 0);
  
}
# }}}


=head2 next

Returns the next scrip that this user can see.

=cut
  
sub next {
    my $self = shift;
    
    
    my $Scrip = $self->SUPER::next();
    if ((defined($Scrip)) and (ref($Scrip))) {

	if ($Scrip->current_user_has_right('ShowScrips')) {
	    return($Scrip);
	}
	
	#If the user doesn't have the right to show this scrip
	else {	
	    return($self->next());
	}
    }
    #if there never was any scrip
    else {
	return(undef);
    }	
    
}
# }}}

=head2 Apply

Run through the relevant scrips.  Scrips will run in order based on 
description.  (Most common use case is to prepend a number to the description,
forcing the scrips to run in ascending alphanumerical order.)

=cut

sub apply {
    my $self = shift;

    my %args = ( ticket_obj      => undef,
                 Ticket         => undef,
                 Transaction    => undef,
                 transaction_obj => undef,
                 Stage          => undef,
                 Type           => undef,
                 @_ );

    $self->prepare(%args);
    $self->commit();

}

=head2 commit

Commit all of this object's prepared scrips

=cut

sub commit {
    my $self = shift;
    
    foreach my $scrip (@{$self->prepared}) {
         Jifty->log->debug(
               "Committing scrip #". $scrip->id
                ." on txn #". $self->{'transaction_obj'}->id
                 ." of ticket #". $self->{'ticket_obj'}->id
             );


        $scrip->commit( ticket_obj      => $self->{'ticket_obj'},
                        transaction_obj => $self->{'transaction_obj'} );
    }
}


=head2 prepare

Only prepare the scrips, returning an array of the scrips we're interested in
in order of preparation, not execution

=cut

sub prepare { 
    my $self = shift;
    my %args = ( ticket_obj      => undef,
                 Ticket         => undef,
                 Transaction    => undef,
                 transaction_obj => undef,
                 Stage          => undef,
                 Type           => undef,
                 @_ );

    #We're really going to need a non-acled ticket for the scrips to work
    $self->setup_source_objects( ticket_obj      => $args{'ticket_obj'},
                                Ticket         => $args{'Ticket'},
                                transaction_obj => $args{'transaction_obj'},
                                Transaction    => $args{'Transaction'} );


    $self->_find_scrips( Stage => $args{'Stage'}, Type => $args{'Type'} );

    
    #Iterate through each script and check it's applicability.
    while ( my $scrip = $self->next() ) {
        next
          unless ( $scrip->is_applicable(
                                     ticket_obj      => $self->{'ticket_obj'},
                                     transaction_obj => $self->{'transaction_obj'}
                   ) );


        #If it's applicable, prepare and commit it
        next
          unless ( $scrip->prepare( ticket_obj      => $self->{'ticket_obj'},
                                    transaction_obj => $self->{'transaction_obj'}
                   ) );
        push @{$self->{'prepared_scrips'}}, $scrip;

    }

    return (@{$self->prepared});

};

=head2 prepared

Returns an arrayref of the scrips this object has prepared


=cut

sub prepared {
    my $self = shift;
    return ($self->{'prepared_scrips'} || []);
}


# {{{ sup _setupSourceObjects

=head2  _setupSourceObjects { ticket_obj , Ticket, Transaction, transaction_obj }

Setup a ticket and transaction for this Scrip collection to work with as it runs through the 
relevant scrips.  (Also to figure out which scrips apply)

Returns: nothing

=cut


sub setup_source_objects {

    my $self = shift;
    my %args = ( 
            ticket_obj => undef,
            Ticket => undef,
            Transaction => undef,
            transaction_obj => undef,
            @_ );

    if ( ( $self->{'ticket_obj'} = $args{'ticket_obj'} ) ) {
        $self->{'ticket_obj'}->current_user( $self->current_user );
    }
    else {
        $self->{'ticket_obj'} = RT::Model::Ticket->new;
        $self->{'ticket_obj'}->load( $args{'Ticket'} )
          || Jifty->log->err("$self couldn't load ticket $args{'Ticket'}\n");
    }

    if ( ( $self->{'transaction_obj'} = $args{'transaction_obj'} ) ) {
        $self->{'transaction_obj'}->current_user( $self->current_user );
    }
    else {
        $self->{'transaction_obj'} = RT::Model::Transaction->new;
        $self->{'transaction_obj'}->load( $args{'Transaction'} )
          || Jifty->log->err( "$self couldn't load transaction $args{'Transaction'}\n");
    }
} 

# }}}

# {{{ sub _FindScrips;

=head2 _FindScrips

Find only the apropriate scrips for whatever we're doing now.  Order them 
by their description.  (Most common use case is to prepend a number to the
description, forcing the scrips to display and run in ascending alphanumerical 
order.)

=cut

sub _find_scrips {
    my $self = shift;
    my %args = (
                 Stage => undef,
                 Type => undef,
                 @_ );


    $self->limit_to_queue( $self->{'ticket_obj'}->queue_obj->id )
      ;    #Limit it to  $Ticket->queue_obj->id
    $self->limit_to_global();
      # or to "global"

    $self->limit( column => "Stage", value => $args{'Stage'} );

    my $ConditionsAlias = $self->new_alias('ScripConditions');

    $self->join(
        alias1 => 'main',
        column1 => 'ScripCondition',
        alias2 => $ConditionsAlias,
        column2 => 'id'
    );

    #We only want things where the scrip applies to this sort of transaction
    # transaction_batch stage can define list of transaction
    foreach( split /\s*,\s*/, ($args{'Type'} || '') ) {
	$self->limit(
	    alias           => $ConditionsAlias,
	    column           => 'ApplicableTransTypes',
	    operator        => 'LIKE',
	    value           => $_,
	    entry_aggregator => 'OR',
	)
    }

    # Or where the scrip applies to any transaction
    $self->limit(
        alias           => $ConditionsAlias,
        column           => 'ApplicableTransTypes',
        operator        => 'LIKE',
        value           => "Any",
        entry_aggregator => 'OR',
    );

    # Promise some kind of ordering
    $self->order_by( column => 'Description' );

    # we call Count below, but later we always do search
    # so just do search and get count from results
    $self->_do_search if $self->{'must_redo_search'};

    Jifty->log->debug(
        "Found ". $self->count ." scrips for $args{'Stage'} stage"
        ." with applicable type(s) $args{'Type'}"
    );
}

# }}}

1;

