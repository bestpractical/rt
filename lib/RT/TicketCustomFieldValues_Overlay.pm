#$Header: /raid/cvsroot/rt/lib/RT/Groups.pm,v 1.2 2001/11/06 23:04:14 jesse Exp $

no warnings qw(redefine);

# {{{ sub LimitToCustomField

=head2 LimitToCustomField FIELD

Limits the returned set to values for the custom field with Id FIELD

=cut
  
sub LimitToCustomField {
    my $self = shift;
    my $cf = shift;
    return ($self->Limit( FIELD => 'CustomField',
			  VALUE => $cf,
			  OPERATOR => '='));

}

# }}}

# {{{ sub LimitToTicket

=head2 LimitToTicket TICKETID

Limits the returned set to values for the ticket with Id TICKETID

=cut
  
sub LimitToTicket {
    my $self = shift;
    my $ticket = shift;
    return ($self->Limit( FIELD => 'Ticket',
			  VALUE => $ticket,
			  OPERATOR => '='));

}

# }}}


=sub HasEntry VALUE

Returns true if this CustomFieldValues collection has an entry with content that eq VALUE

=cut


sub HasEntry {
    my $self = shift;
    my $value = shift;

    #TODO: this could cache and optimize a fair bit.
    foreach my $item (@{$self->ItemsArrayRef}) {
        return(1) if ($item->Content eq $value);  
    }
    return undef;

}

1;

