# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Scrips - a collection of RT Scrip objects

=head1 SYNOPSIS

  use RT::Scrips;

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Scrips);

=end testing

=cut

use strict;
no warnings qw(redefine);

# {{{ sub LimitToQueue 

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
# }}}

# {{{ sub LimitToGlobal

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
# }}}

# {{{ sub NewItem 
sub NewItem  {
  my $self = shift;
  
  return(new RT::Scrip($self->CurrentUser));
}
# }}}

# {{{ sub Next 

=head2 Next

Returns the next scrip that this user can see.

=cut
  
sub Next {
    my $self = shift;
    
    
    my $Scrip = $self->SUPER::Next();
    if ((defined($Scrip)) and (ref($Scrip))) {

	if ($Scrip->CurrentUserHasRight('ShowScrips')) {
	    return($Scrip);
	}
	
	#If the user doesn't have the right to show this scrip
	else {	
	    return($self->Next());
	}
    }
    #if there never was any scrip
    else {
	return(undef);
    }	
    
}
# }}}

sub Apply {
    my ($self, %args) = @_;

    #We're really going to need a non-acled ticket for the scrips to work
    my ($TicketObj, $TransactionObj);

    if ( ($TicketObj = $args{'TicketObj'}) ) {
        $TicketObj->CurrentUser($self->CurrentUser);
    }
    else {
        $TicketObj = RT::Ticket->new($self->CurrentUser);
        $TicketObj->Load( $args{'Ticket'} )
            || $RT::Logger->err("$self couldn't load ticket $args{'Ticket'}\n");
    }

    if ( ($TransactionObj = $args{'TransactionObj'}) ) {
        $TransactionObj->CurrentUser($self->CurrentUser);
    }
    else {
        $TransactionObj = RT::Transaction->new($self->CurrentUser);
        $TransactionObj->Load( $args{'Transaction'} )
            || $RT::Logger->err("$self couldn't load transaction $args{'Transaction'}\n");
    }

    # {{{ Deal with Scrips

    $self->LimitToQueue( $TicketObj->QueueObj->Id )
        ;                                  #Limit it to  $Ticket->QueueObj->Id
    $self->LimitToGlobal()
        unless $TicketObj->QueueObj->Disabled;    # or to "global"


    $self->Limit(FIELD => "Stage", VALUE => $args{'Stage'});


    my $ConditionsAlias = $self->NewAlias('ScripConditions');

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'ScripCondition',
        ALIAS2 => $ConditionsAlias,
        FIELD2 => 'id'
    );

    #We only want things where the scrip applies to this sort of transaction
    $self->Limit(
        ALIAS           => $ConditionsAlias,
        FIELD           => 'ApplicableTransTypes',
        OPERATOR        => 'LIKE',
        VALUE           => $args{'Type'},
        ENTRYAGGREGATOR => 'OR',
    ) if $args{'Type'};

    # Or where the scrip applies to any transaction
    $self->Limit(
        ALIAS           => $ConditionsAlias,
        FIELD           => 'ApplicableTransTypes',
        OPERATOR        => 'LIKE',
        VALUE           => "Any",
        ENTRYAGGREGATOR => 'OR',
    );

    #Iterate through each script and check it's applicability.
    while ( my $Scrip = $self->Next() ) {
        $Scrip->Apply (TicketObj => $TicketObj,
                        TransactionObj => $TransactionObj);
    }

    $TicketObj->CurrentUser( $TicketObj->OriginalUser );
    $TransactionObj->CurrentUser( $TransactionObj->OriginalUser );

    # }}}
}


1;

