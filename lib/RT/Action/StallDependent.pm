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
    my $base;
    if ($base_id eq "THIS") {
	$base=$self->TicketObj;
    } else {
	$base=RT::Ticket->new($self->TicketObj->CurrentUser);
	# TODO: only works if id is a plain ticket num:
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
  &RT::Ticket::URIIsLocal($1) || return 0;
  
  return 1;
}
# }}}

1;
