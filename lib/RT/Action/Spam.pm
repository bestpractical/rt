# This Action will spam all "subrequestors" when correspondence is added to a Group Ticket.

package RT::Action::Spam;
require RT::Action::SendEmail;
require RT::Links;
@ISA=qw|RT::Action::SendEmail|;

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will spam all \"subrequestors\" and \"subCcs\" when correspondence is added.");
}
# }}}


sub SetRecipients {

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

	# TODO:
	# This is baaad - all requestors are in the "To" field.  It
	# would be more correct to either have them in the BCC field
	# or send one email for each requestor.  I will deal with it
	# when somebody complains (: -- TobiX
	push(@{$self->{To}}, $base->RequestorsAsString);
	push(@{$self->{Cc}}, $base->CcAsString);
    }

    return $self->SUPER::SetRecipients;
    
}


1;

