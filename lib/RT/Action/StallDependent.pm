# This Action will stall the BASE if a dependency link is created.

package RT::Action::StallDependent;
require RT::Action;
@ISA=qw|RT::Action|;

#Do what we need to do and send it out.

# {{{ sub Commit 
sub Commit  {
# Stall BASE.
}
# }}}

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will stall a [local] BASE if a dependency link is created.");
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
    my ($base_id)=$self->TransactionObj->Data =~ /^([^ ]*)/;
    my $base;
    if ($base_id eq "THIS") {
	$base=$self->TicketObj;
    } else {
	$base=RT::Ticket->new($self->TicketObj->CurrentUser);
	$base->Load($base_id);
    }
    $base->Stall;
    return 0;
}


# Only applicable if:
# 1. the link action is a dependency
# 2. BASE is a local ticket

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  # 1:
  $self->TransactionObj->Data =~ /^[^ ]* DependsOn / || return 0;
  
  return 1;
}
# }}}

1;
