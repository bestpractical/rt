# $Header$
# This Action will open the BASE if a dependent is resolved.

package RT::Action::OpenDependent;
require RT::Action;
require RT::Links;
@ISA=qw(RT::Action);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will stall a [local] BASE if it's open and a dependency link is created.");
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

    my $Links=RT::Links->new($RT::SystemUser);
    $Links->Limit(FIELD => 'Type', VALUE => 'DependsOn');
    $Links->Limit(FIELD => 'Target', VALUE => $self->TicketObj->id);

    while (my $Link=$Links->Next()) {
	next unless $Link->BaseIsLocal;
	my $base=RT::Ticket->new($self->TicketObj->CurrentUser);
	# Todo: Only work if Base is a plain ticket num:
	$base->Load($Link->Base);
        $base->Open if $base->Status eq 'stalled';
    }
}


# Applicability checked in Commit.

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  1;  
  return 1;
}
# }}}

1;
