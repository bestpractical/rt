# Copyright 1999-2001 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header: /raid/cvsroot/rt/lib/RT/CustomFields.pm,v 1.2 2001/11/06 23:04:14 jes se Exp $

no warnings qw(redefine);

use vars qw(@TYPES %TYPES);

# Enumerate all valid types for this custom field
@TYPES = qw(SelectSingle SelectMultiple FreeformSingle FreeformMultiple );
# Populate a hash of types of easier validation
for (@TYPES) { $TYPES{$_} = 1};




=head1 NAME

  RT::CustomField_Overlay 

=head1 DESCRIPTION

=head1 'CORE' METHODS

=cut

# {{{ Dealing with custom field values 

=begin testing
use_ok(RT::CustomField);
ok(my $cf = RT::CustomField->new($RT::SystemUser));
ok(my ($id, $msg)=  $cf->Create( Name => 'TestingCF',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field',
                                 Type=> 'SelectSingle'), 'Created a global CustomField');
ok($id != 0, 'Global custom field correctly created');
ok ($cf->SingleValue);
ok($cf->Type eq 'SelectSingle');

ok($cf->SetType('SelectMultiple'));
ok($cf->Type eq 'SelectMultiple');
ok(!$cf->SingleValue );
ok(my ($bogus_val, $bogus_msg) = $cf->SetType('BogusType') , "Trying to set a custom field's type to a bogus type");
ok($bogus_val == 0, "Unable to set a custom field's type to a bogus type");

ok(my $bad_cf = RT::CustomField->new($RT::SystemUser));
ok(my ($bad_id, $bad_msg)=  $cf->Create( Name => 'TestingCF-bad',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field with a bogus Type',
                                 Type=> 'SelectSingleton'), 'Created a global CustomField with a bogus type');
ok($bad_id == 0, 'Global custom field correctly decided to not create a cf with a bogus type ');

=end testing

=cut

# {{{ AddValue

=item AddValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements Name, Description and SortOrder

=cut

sub AddValue {
	my $self = shift;
	my %args = ( Name => undef,
		     Description => undef,
		     SortOrder => undef,
		     @_ );

    unless ($args{'Name'}) {
        return("Can't add a custom field value without a name");
    }
	my $newval = RT::CustomFieldValue->new($self->CurrentUser);
	return($newval->Create(
		     CustomField => $self->Id,
             Name =>$args{'Name'},
             Description => ($args{'Description'} || ''),
             SortOrder => ($args{'SortOrder'} || '0')
        ));    
}


# }}}

# {{{ DeleteValue

=item DeleteValue  ID

Deletes a value from this custom field by id. 

Does not remove this value for any article which has had it selected	

=cut

sub DeleteValue {
	my $self = shift;
    my $id = shift;

	my $val_to_del = RT::CustomFieldValue->Id($self->CurrentUser);
	$val_to_del->Load($id);
	unless ($val_to_del->Id) {
		return (0, "Couldn't find that value");
	}
	unless ($val_to_del->CustomField == $self->Id) {
		return (0, "That is not a value for this custom field");
	}

	return($val_to_del->Delete());
}

# }}}

# {{{ Values

=item Values FIELD

Return a CustomFieldeValues object of all acceptable values for this Custom Field.


=cut

sub Values {
    my $self = shift;

    my $cf_values = RT::CustomFieldValues->new($self->CurrentUser);
    $cf_values->LimitToCustomField($self->Id);
    return ($cf_values);
}

# }}}

# }}}

# {{{ Ticket related routines

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

# }}}

# {{{ Types

=item Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
	return (@TYPES);
}

# }}}

=item ValidateType TYPE

Takes a single string. returns true if that string is a value
type of custom field

=for testing
ok(my $cf = RT::CustomField->new($RT::SystemUser));
ok($cf->ValidateType('SelectSingle'));
ok($cf->ValidateType('SelectMultiple'));
ok(!$cf->ValidateType('SelectFooMultiple'));

=end testing

=cut

sub ValidateType {
    my $self = shift;
    my $type = shift;

    if( $TYPES{$type}) {
        return(1);
    }
    else {
        return undef;
    }
}

# {{{ SingleValue

=item SingleValue

Returns true if this CustomField only accepts a single value. 
Returns false if it accepts multiple values

=cut

sub SingleValue {
    my $self = shift;
    if ($self->Type =~  /Single$/) {
        return 1;
    } 
    else {
        return undef;
    }
}

# }}}



# {{{ sub CurrentUserHasQueueRight

=item CurrentUserHasQueueRight

Helper function to call the template's queue's CurrentUserHasQueueRight with the passed in args.

=cut

sub CurrentUserHasQueueRight {
    my $self = shift;

    # If there is no queue, we certainly can't check if the user has the queue right
    return undef unless ($self->Queue);
    return ( $self->QueueObj->CurrentUserHasRight(@_) );
}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;

    # use super::value or we get acl blocked
    if ( ( defined $self->SUPER::_Value('Queue') )
        && ( $self->SUPER::_Value('Queue') == 0 ) )
    {
        unless ( $self->CurrentUser->HasSystemRight('AdminCustomFields') ) {
            return ( 0, 'Permission Denied' );
        }
    }
    else {

        unless ( $self->CurrentUserHasQueueRight('AdminCustomFields') ) {
            return ( 0, 'Permission Denied' );
        }
    }
    return ( $self->SUPER::_Set(@_) );

}

# }}}

# {{{ sub _Value 

=item _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {

    my $self  = shift;
    my $field = shift;

    # We need to expose the queue so that we can do things like ACL checks
    if ( $field eq 'Queue') {
          return ( $self->SUPER::_Value($field) );
     }
    #If the current user doesn't have ACLs, don't let em at it.  
    #use super::value or we get acl blocked
    if ( ( !defined $self->__Value('Queue') )
        || ( $self->__Value('Queue') == 0 ) )
    {
        unless ( $self->CurrentUser->HasSystemRight('SeeQueue') ) {
            return (undef);
        }
    }
    else {
        unless ( $self->CurrentUserHasQueueRight('SeeQueue') ) {
            return (undef);
        }
    }
    return ( $self->__Value($field) );

}

# }}}

1;
