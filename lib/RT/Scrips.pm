# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

  RT::Scrips - a collection of RT Scrip objects

=head1 SYNOPSIS

  use RT::Scrips;

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Scrips;

use strict;
use warnings;

use RT::Scrip;

use base 'RT::SearchBuilder';

sub Table { 'Scrips'}


=head2 LimitToQueue

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => "$queue")
      if defined $queue;
  
}


=head2 LimitToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or LimitToQueue

=cut


sub LimitToGlobal  {
   my $self = shift;
 
  $self->Limit (ENTRYAGGREGATOR => 'OR',
		FIELD => 'Queue',
		VALUE => 0);
  
}

=head2 AddRecord

Overrides the collection to ensure that only scrips the user can see are
returned.

=cut

sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->CurrentUserHasRight('ShowScrips');
    return $self->SUPER::AddRecord( $record );
}

=head2 Apply

Run through the relevant scrips.  Scrips will run in order based on 
description.  (Most common use case is to prepend a number to the description,
forcing the scrips to run in ascending alphanumerical order.)

=cut

sub Apply {
    my $self = shift;

    my %args = ( TicketObj      => undef,
                 Ticket         => undef,
                 Transaction    => undef,
                 TransactionObj => undef,
                 Stage          => undef,
                 Type           => undef,
                 @_ );

    $self->Prepare(%args);
    $self->Commit();

}

=head2 Commit

Commit all of this object's prepared scrips

=cut

sub Commit {
    my $self = shift;

    foreach my $scrip (@{$self->Prepared}) {
        $RT::Logger->debug(
            "Committing scrip #". $scrip->id
            ." on txn #". $self->{'TransactionObj'}->id
            ." of ticket #". $self->{'TicketObj'}->id
        );

        $scrip->Commit( TicketObj      => $self->{'TicketObj'},
                        TransactionObj => $self->{'TransactionObj'} );
    }

}


=head2 Prepare

Only prepare the scrips, returning an array of the scrips we're interested in
in order of preparation, not execution

=cut

sub Prepare { 
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 Ticket         => undef,
                 Transaction    => undef,
                 TransactionObj => undef,
                 Stage          => undef,
                 Type           => undef,
                 @_ );

    #We're really going to need a non-acled ticket for the scrips to work
    $self->_SetupSourceObjects( TicketObj      => $args{'TicketObj'},
                                Ticket         => $args{'Ticket'},
                                TransactionObj => $args{'TransactionObj'},
                                Transaction    => $args{'Transaction'} );


    $self->_FindScrips( Stage => $args{'Stage'}, Type => $args{'Type'} );


    #Iterate through each script and check it's applicability.
    while ( my $scrip = $self->Next() ) {

          unless ( $scrip->IsApplicable(
                                     TicketObj      => $self->{'TicketObj'},
                                     TransactionObj => $self->{'TransactionObj'}
                   ) ) {
                   $RT::Logger->debug("Skipping Scrip #".$scrip->Id." because it isn't applicable");
                   next;
               }

        #If it's applicable, prepare and commit it
          unless ( $scrip->Prepare( TicketObj      => $self->{'TicketObj'},
                                    TransactionObj => $self->{'TransactionObj'}
                   ) ) {
                   $RT::Logger->debug("Skipping Scrip #".$scrip->Id." because it didn't Prepare");
                   next;
               }
        push @{$self->{'prepared_scrips'}}, $scrip;

    }

    return (@{$self->Prepared});

};

=head2 Prepared

Returns an arrayref of the scrips this object has prepared


=cut

sub Prepared {
    my $self = shift;
    return ($self->{'prepared_scrips'} || []);
}

=head2  _SetupSourceObjects { TicketObj , Ticket, Transaction, TransactionObj }

Setup a ticket and transaction for this Scrip collection to work with as it runs through the 
relevant scrips.  (Also to figure out which scrips apply)

Returns: nothing

=cut


sub _SetupSourceObjects {

    my $self = shift;
    my %args = ( 
            TicketObj => undef,
            Ticket => undef,
            Transaction => undef,
            TransactionObj => undef,
            @_ );


    if ( $args{'TicketObj'} ) {
        # This loads a clean copy of the Ticket object to ensure that we
        # don't accidentally escalate the privileges of the passed in
        # ticket (this function can be invoked from the UI).
        # We copy the TransactionBatch transactions so that Scrips
        # running against the new Ticket will have access to them. We
        # use RanTransactionBatch to guard against running
        # TransactionBatch Scrips more than once.
        $self->{'TicketObj'} = RT::Ticket->new( $self->CurrentUser );
        $self->{'TicketObj'}->Load( $args{'TicketObj'}->Id );
        if ( $args{'TicketObj'}->TransactionBatch ) {
            # try to ensure that we won't infinite loop if something dies, triggering DESTROY while 
            # we have the _TransactionBatch objects;
            $self->{'TicketObj'}->RanTransactionBatch(1);
            $self->{'TicketObj'}->{'_TransactionBatch'} = $args{'TicketObj'}->{'_TransactionBatch'};
        }
    }
    else {
        $self->{'TicketObj'} = RT::Ticket->new( $self->CurrentUser );
        $self->{'TicketObj'}->Load( $args{'Ticket'} )
          || $RT::Logger->err("$self couldn't load ticket $args{'Ticket'}");
    }

    if ( ( $self->{'TransactionObj'} = $args{'TransactionObj'} ) ) {
        $self->{'TransactionObj'}->CurrentUser( $self->CurrentUser );
    }
    else {
        $self->{'TransactionObj'} = RT::Transaction->new( $self->CurrentUser );
        $self->{'TransactionObj'}->Load( $args{'Transaction'} )
          || $RT::Logger->err( "$self couldn't load transaction $args{'Transaction'}");
    }
} 



=head2 _FindScrips

Find only the apropriate scrips for whatever we're doing now.  Order them 
by their description.  (Most common use case is to prepend a number to the
description, forcing the scrips to display and run in ascending alphanumerical 
order.)

=cut

sub _FindScrips {
    my $self = shift;
    my %args = (
                 Stage => undef,
                 Type => undef,
                 @_ );


    $self->LimitToQueue( $self->{'TicketObj'}->QueueObj->Id )
      ;    #Limit it to  $Ticket->QueueObj->Id
    $self->LimitToGlobal();
      # or to "global"

    $self->Limit( FIELD => "Stage", VALUE => $args{'Stage'} );

    my $ConditionsAlias = $self->NewAlias('ScripConditions');

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'ScripCondition',
        ALIAS2 => $ConditionsAlias,
        FIELD2 => 'id'
    );

    #We only want things where the scrip applies to this sort of transaction
    # TransactionBatch stage can define list of transaction
    foreach( split /\s*,\s*/, ($args{'Type'} || '') ) {
	$self->Limit(
	    ALIAS           => $ConditionsAlias,
	    FIELD           => 'ApplicableTransTypes',
	    OPERATOR        => 'LIKE',
	    VALUE           => $_,
	    ENTRYAGGREGATOR => 'OR',
	)
    }

    # Or where the scrip applies to any transaction
    $self->Limit(
        ALIAS           => $ConditionsAlias,
        FIELD           => 'ApplicableTransTypes',
        OPERATOR        => 'LIKE',
        VALUE           => "Any",
        ENTRYAGGREGATOR => 'OR',
    );

    # Promise some kind of ordering
    $self->OrderBy( FIELD => 'Description' );

    # we call Count below, but later we always do search
    # so just do search and get count from results
    $self->_DoSearch if $self->{'must_redo_search'};

    $RT::Logger->debug(
        "Found ". $self->Count ." scrips for $args{'Stage'} stage"
        ." with applicable type(s) $args{'Type'}"
        ." for txn #".$self->{TransactionObj}->Id
        ." on ticket #".$self->{TicketObj}->Id
    );
}




=head2 NewItem

Returns an empty new RT::Scrip item

=cut

sub NewItem {
    my $self = shift;
    return(RT::Scrip->new($self->CurrentUser));
}
RT::Base->_ImportOverlays();

1;
