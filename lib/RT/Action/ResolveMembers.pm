# This Action will resolve all members of a resolved group ticket

package RT::Action::ResolveMembers;
require RT::Action;
require RT::Links;
@ISA=qw|RT::Action|;

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will resolve all members of a resolved group ticket.");
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
    $Links->Limit(FIELD => 'Type', VALUE => 'MemberOf');
    $Links->Limit(FIELD => 'Target', VALUE => $self->TicketObj->id);

    while (my $Link=$Links->Next()) {
	# Todo: Try to deal with remote URIs as well
	next unless RT::Ticket::URIIsLocal($Link->Base);
	my $base=RT::Ticket->new($self->TicketObj->CurrentUser);
	# Todo: Only work if Base is a plain ticket num:
	$base->Load($Link->Base);
	# I'm afraid this might be a major bottleneck if ResolveGroupTicket is on.
        $base->Resolve;
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

