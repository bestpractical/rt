# $Header: /raid/cvsroot/rt-addons/ScripActions/SetPriority/SetPriority.pm,v 1.1 2001/06/22 21:46:33 jesse Exp $

package RT::Action::SetPriority;
require RT::Action::Generic;
@ISA=qw(RT::Action::Generic);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will set a ticket's priority to the argument provided.");
}
# }}}


# {{{ sub Prepare 
sub Prepare  {
    # nothing to prepare
    return 1;
}
# }}}

sub Commit {
    my $self = shift;
    $self->TicketObj->SetPriority($self->Argument);

}

1;
