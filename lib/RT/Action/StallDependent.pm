# This Action will stall the BASE if a dependency link is created and if BASE is open.

package RT::Action::StallDependent;
require RT::Action;
@ISA=qw|RT::Action|;

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will open a [local] BASE if it's stalled and dependent on a resolved request.");
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
    # Find all Dependent
    unless ($self->TransactionObj->Data =~ /^([^ ]*) DependsOn /) {
	warn; return 0;
    }
    my $base;
    if ($1 eq "THIS") {
	$base=$self->TicketObj;
    } else {
	my $base_id=&RT::Link::_IsLocal($1) || return 0;
	$base=RT::Ticket->new($self->TicketObj->CurrentUser);
	$base->Load($base_id);
    }
    $base->Stall if $base->Status eq 'open';
    return 0;
}


# Only applicable if:
# 1. the link action is a dependency
# 2. BASE is a local ticket

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  # 1:
  $self->TransactionObj->Data =~ /^([^ ]*) DependsOn / || return 0;

  # 2:
  # (dirty!)
  &RT::Link::_IsLocal(undef,$1) || return 0;
  
  return 1;
}
# }}}

1;
