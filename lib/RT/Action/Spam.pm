# $Header$

# This Action will spam all "subrequestors" when correspondence is added to a Group Ticket.

package RT::Action::Spam;
require RT::Action::SendEmail;
require RT::Links;
@ISA=qw(RT::Action::SendEmail);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will spam all \"subrequestors\" and \"subCcs\" when correspondence is added.");
}
# }}}

# {{{ sub Prepare
sub Prepare {
    # we'll deal with everything in the commit sub -Tobix
    # Why? is there no preparation that needs doing? 
    # Preparation work _should_ be here. -jesse
    return 1;
}
# }}}

# {{{ sub SetSubjectToken
sub SetSubjectToken {
  my $self=shift;
  my $tag = "[$RT::rtname #".$self->{TicketId}."]";
  my $sub = $self->TemplateObj->MIMEObj->head->get('subject');
  $sub =~ s/\[\Q$RT::rtname\E #(\d)\]//;
  $self->TemplateObj->MIMEObj->head->replace('subject', "$tag $sub");
}

# }}}

# {{{ sub Commit
sub Commit {

    my $self = shift;

    my $cnt=0;

    my $Links=RT::Links->new($RT::SystemUser);
    $Links->Limit(FIELD => 'Type', VALUE => 'MemberOf');
    $Links->Limit(FIELD => 'Target', VALUE => $self->TicketObj->id);

    while (my $Link=$Links->Next()) {
	# Todo: Try to deal with remote URIs as well
	next unless RT::Ticket::URIIsLocal($Link->Base);
	my $base=RT::Ticket->new($self->TicketObj->CurrentUser);
	# Todo: Only work if Base is a plain ticket num:
	$base->Load($Link->Base);

	
	$self->{To}=[$base->RequestorsAsString];
	$self->{Cc}=[$base->CcAsString];
	$self->{TicketId}=$base->id;

	$self->SUPER::Prepare;
	$self->SUPER::Commit;

	$cnt++;
    }

    return $cnt;
}
# }}}

1;

