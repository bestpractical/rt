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

  RT::Action::EscalatePriority

=head1 DESCRIPTION

EscalatePriority is a ScripAction which is NOT intended to be called per 
transaction. It's intended to be called by an RT escalation daemon.
(The daemon is called escalator).

EsclatePriority uses the following formula to change a ticket's priority:

    Priority = Priority +  (( FinalPriority - Priority ) / ( DueDate-Today))

Unless the duedate is past, in which case priority gets bumped straight
to final priority.

In this way, priority is either increased or decreased toward the final priority
as the ticket heads toward its due date.


=cut


package RT::Action::EscalatePriority;
require RT::Action::Generic;

use strict;
use vars qw/@ISA/;
@ISA=qw(RT::Action::Generic);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will move a ticket's priority toward its final priority.");
}
# }}}
	

# {{{ sub Prepare 
sub Prepare  {
    my $self = shift;
    
    if ($self->TicketObj->Priority() == $self->TicketObj->FinalPriority()) {
	# no update necessary.
	return 0;
    }
   
    #compute the number of days until the ticket is due
    my $due = $self->TicketObj->DueObj();
    

    # If we don't have a due date, adjust the priority by one
    # until we hit the final priority
    if ($due->Unix() < 1) {
	if ( $self->TicketObj->Priority > $self->TicketObj->FinalPriority ){
	    $self->{'prio'} = ($self->TicketObj->Priority - 1);
	    return 1;
	}
	elsif ( $self->TicketObj->Priority < $self->TicketObj->FinalPriority ){
	    $self->{'prio'} = ($self->TicketObj->Priority + 1);
	    return 1;
	}
	# otherwise the priority is at the final priority. we don't need to
	# Continue
	else {
	    return 0;
	}
    }

    # we've got a due date. now there are other things we should do
    else { 
	my $diff_in_seconds = $due->Diff(time());    
	my $diff_in_days = int( $diff_in_seconds / 86400);    
	
	#if we haven't hit the due date yet
	if ($diff_in_days > 0 ) {	
	    
	    # compute the difference between the current priority and the
	    # final priority
	    
	    my $prio_delta = 
	      $self->TicketObj->FinalPriority() - $self->TicketObj->Priority;
	    
	    my $inc_priority_by = int( $prio_delta / $diff_in_days );
	    
	    #set the ticket's priority to that amount
	    $self->{'prio'} = $self->TicketObj->Priority + $inc_priority_by;
	    
	}
	#if $days is less than 1, set priority to final_priority
	else {	
	    $self->{'prio'} = $self->TicketObj->FinalPriority();
	}

    }
    return 1;
}
# }}}

sub Commit {
    my $self = shift;
   my ($val, $msg) = $self->TicketObj->SetPriority($self->{'prio'});

   unless ($val) {
	$RT::Logger->debug($self . " $msg\n"); 
   }
}

eval "require RT::Action::EscalatePriority_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/EscalatePriority_Vendor.pm});
eval "require RT::Action::EscalatePriority_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/EscalatePriority_Local.pm});

1;
