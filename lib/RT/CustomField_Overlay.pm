no warnings qw(reload);

use vars qw(@TYPES);

@TYPES = qw(SelectSingle SelectMultiple FreeformSingle FreeformMultiple );

# {{{ ValuesForTicket

=item ValuesForTicket TICKET

Returns a RT::TicketCustomFieldValues object of this Field's values for TICKET.
TICKET is a ticket id.


=cut

sub ValuesForTicket {
	my $self = shift;
    my $ticket_id = shift;

	my $values = new RT::TicketCustomFieldValues($self->CurrentUser);
	$values->LimitToCustomField($self->Id);
    $values->LimitToTicket($ticket_id);
    ( FIELD => 'CustomField',
			OPERATOR => '=',
			VALUE => $self->Id );
	return ($values);
}

# }}}

# {{{ AddValueForTicket

=item AddValueForTicket HASH

Adds a custom field value for a ticket. Takes a param hash of Ticket and Content

=cut

sub AddValueForTicket {
	my $self = shift;
	my %args = ( Ticket => undef.
                 Content => undef,
		     @_ );

	my $newval = RT::CustomFieldValue->new($self->CurrentUser);
	return($newval->Create(Ticket => $args{'Ticket'},
                            Content => $args{'Content'},
                            CustomField => $self->Id)
    );
}


# }}}


# {{{ AddValue

=item AddValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements Name, Description and SortOrder

=cut

sub AddValue {
	my $self = shift;
	my %args = ( Name => undef,
		     Description => undef,
		     SortOrder => undef,
		     CustomField => $self->Id,
		     @_ );
	my $newval = RT::CustomFieldValue->new($self->CurrentUser);
	return($newval->Create(%args));
}


# }}}

# {{{ DeleteValue

=item DeleteValue ID

Deletes a value from this custom field by id.  Also removes this value
for any article which has had it selected	

=cut

sub DeleteValue {
	my $self = shift;
	my $id = shift;
	my $valtodel = new RT::CustomFieldValue($self->CurrentUser);
	$valtodel->Load($id);
	unless ($valtodel->Id) {
		return (0, "Couldn't find that value");
	}
	unless ($valtodel->CustomField == $self->Id) {
		return (0, "That is not a value for this custom field");
	}

	return($valtodel->Delete());
}

# }}}

# {{{ Types

=item Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
	return (@TYPES);
}

# }}}

# {{{ SingleValue

=item SingleValue

Returns true if this CustomField only accepts a single value. Returns false if it
accepts multiple values

=cut

sub SingleValue {
    my $self = shift;
    if ($self->Type =~  /single/i) {
        return 1;
    } 
    else {
        return undef;
    }
}

# }}}

# {{{ AcceptableValues

=item AcceptableValues FIELD

Return a CustomFieldeValues object of all acceptable values for this Custom Field.


=cut

sub AcceptableValues {
    my $self = shift;

    my $cf_values = RT::CustomFieldValues->new($self->CurrentUser);
    $cf_values->LimitToCustomField($self->Id);
    return ($cf_values);
}

# }}}

1;
