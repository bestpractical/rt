# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
use strict;
no warnings qw(redefine);

use vars qw(@TYPES %TYPES $RIGHTS);

use RT::CustomFieldValues;
use RT::ObjectCustomFieldValues;

# Enumerate all valid types for this custom field
@TYPES = (
    'Freeform',	# loc
    'Select',	# loc
    'Text',     # loc
    'Image',    # loc
    'Binary',   # loc
);

# Populate a hash of types of easier validation
for (@TYPES) { $TYPES{$_} = 1};

$RIGHTS = {
    SeeCustomField            => 'Can this principal see this custom field',       # loc_pair
    AdminCustomField          => 'Create, delete and modify custom fields',        # loc_pair
};

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::CustomField'} = 1;

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

sub AvailableRights {
    my $self = shift;
    return($RIGHTS);
}

=head1 NAME

  RT::CustomField_Overlay 

=head1 DESCRIPTION

=head1 'CORE' METHODS

=cut



=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Type'.
  int(11) 'MaxValues'.
  varchar(255) 'Pattern'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.
  smallint(6) 'Disabled'.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Type => '',
		MaxValues => '0',
		Pattern  => '',
                Description => '',
                Disabled => '0',
		LookupType  => '',
		Repeated  => '0',

		  @_);

    if ($args{TypeComposite}) {
	@args{'Type', 'MaxValues'} = split(/-/, $args{TypeComposite}, 2);
    }
    
    if ( !exists $args{'Queue'}) {
	# do nothing -- things below are strictly backward compat
    }
    elsif (  ! $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System, Right => 'AdminCustomFields') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
	$args{'LookupType'} = 'RT::Queue-RT::Ticket';
    }
    else {
        my $queue = RT::Queue->new($self->CurrentUser);
        $queue->Load($args{'Queue'});
        unless ($queue->Id) {
            return (0, $self->loc("Queue not found"));
        }
        unless ( $queue->CurrentUserHasRight('AdminCustomFields') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
	$args{'LookupType'} = 'RT::Queue-RT::Ticket';
    }
    my $rv = $self->SUPER::Create(
                         Name => $args{'Name'},
                         Type => $args{'Type'},
                         MaxValues => $args{'MaxValues'},
                         Pattern  => $args{'Pattern'},
                         Description => $args{'Description'},
                         Disabled => $args{'Disabled'},
			 LookupType => $args{'LookupType'},
			 Repeated => $args{'Repeated'},
);

    return $rv unless exists $args{'Queue'};

    # Compat code -- create a new ObjectCustomField mapping
    my $OCF = RT::ObjectCustomField->new($self->CurrentUser);
    $OCF->Create(
	CustomField => $self->Id,
	ObjectId => $args{'Queue'},
    );

    return $rv;
}


# {{{ sub LoadByNameAndQueue

=head2  LoadByNameAndQueue (Queue => QUEUEID, Name => NAME)

Loads the Custom field named NAME for Queue QUEUE. If QUEUE is 0,
loads a global custom field

=cut

# Compatibility for API change after 3.0 beta 1
*LoadNameAndQueue = \&LoadByNameAndQueue;

sub LoadByNameAndQueue {
    my $self = shift;
    my %args = (
        Queue => undef,
        Name  => undef,
        @_,
    );

    if ($args{'Queue'} =~ /\D/) {
	my $QueueObj = RT::Queue->new($self->CurrentUser);
	$QueueObj->Load($args{'Queue'});
	$args{'Queue'} = $QueueObj->Id;
    }

    # XXX - really naive implementation.  Slow.

    my $CFs = RT::CustomFields->new($self->CurrentUser);
    $CFs->Limit( FIELD => 'Name', VALUE => $args{'Name'} );
    $CFs->LimitToQueue( $args{'Queue'} );
    $CFs->RowsPerPage(1);

    my $CF = $CFs->First or return;
    return $self->Load($CF->Id);

}

# }}}

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

=head2 AddValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements Name, Description and SortOrder

=begin testing

ok(my $cf = RT::CustomField->new($RT::SystemUser));
$cf->Load(1);
ok($cf->Id == 1);
ok(my ($val,$msg)  = $cf->AddValue(Name => 'foo' , Description => 'TestCFValue', SortOrder => '6'));
ok($val != 0);
ok (my ($delval, $delmsg) = $cf->DeleteValue($val));
ok ($delval != 0);

=end testing

=cut

sub AddValue {
	my $self = shift;
	my %args = ( Name => undef,
		     Description => undef,
		     SortOrder => undef,
		     @_ );

    unless ($self->CurrentUserHasRight('AdminCustomFields')) {
        return (0, $self->loc('Permission Denied'));
    }

    unless ($args{'Name'}) {
        return(0, $self->loc("Can't add a custom field value without a name"));
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

=head2 DeleteValue ID

Deletes a value from this custom field by id. 

Does not remove this value for any article which has had it selected	

=cut

sub DeleteValue {
	my $self = shift;
    my $id = shift;
    unless ($self->CurrentUserHasRight('AdminCustomFields')) {
        return (0, $self->loc('Permission Denied'));
    }

	my $val_to_del = RT::CustomFieldValue->new($self->CurrentUser);
	$val_to_del->Load($id);
	unless ($val_to_del->Id) {
		return (0, $self->loc("Couldn't find that value"));
	}
	unless ($val_to_del->CustomField == $self->Id) {
		return (0, $self->loc("That is not a value for this custom field"));
	}

	my $retval = $val_to_del->Delete();
    if ($retval) {
        return ($retval, $self->loc("Custom field value deleted"));
    } else {
        return(0, $self->loc("Custom field value could not be deleted"));
    }
}

# }}}

# {{{ Values

=head2 Values FIELD

Return a CustomFieldeValues object of all acceptable values for this Custom Field.


=cut

sub Values {
    my $self = shift;

    my $cf_values = RT::CustomFieldValues->new($self->CurrentUser);
    if ( $self->__Value('Queue') == 0 || $self->CurrentUserHasRight( 'SeeQueue') ) {
        $cf_values->LimitToCustomField($self->Id);
    }
    return ($cf_values);
}

sub ValuesObj {
    my $self = shift;
    return $self->Values(@_);
}

# }}}

# }}}

# {{{ Ticket related routines

# {{{ ValuesForTicket

=head2 ValuesForTicket TICKET

Returns a RT::ObjectCustomFieldValues object of this Field's values for TICKET.
TICKET is a ticket id.


=cut

sub ValuesForTicket {
	my $self = shift;
    my $ticket_id = shift;

	my $values = new RT::ObjectCustomFieldValues($self->CurrentUser);
	$values->LimitToCustomField($self->Id);
    $values->LimitToTicket($ticket_id);

	return ($values);
}

# }}}

# {{{ AddValueForTicket

=head2 AddValueForTicket HASH

Adds a custom field value for a ticket. Takes a param hash of Ticket and Content

=cut

sub AddValueForTicket {
	my $self = shift;
	my %args = ( Ticket => undef,
                 Content => undef,
		     @_ );

	my $newval = RT::ObjectCustomFieldValue->new($self->CurrentUser);
	my $val = $newval->Create(ObjectType => 'RT::Ticket',
	                    ObjectId => $args{'Ticket'},
                            Content => $args{'Content'},
                            CustomField => $self->Id);

    return($val);

}


# }}}

# {{{ DeleteValueForTicket

=head2 DeleteValueForTicket HASH

Adds a custom field value for a ticket. Takes a param hash of Ticket and Content

=cut

sub DeleteValueForTicket {
	my $self = shift;
	my %args = ( Ticket => undef,
                 Content => undef,
		     @_ );

	my $oldval = RT::ObjectCustomFieldValue->new($self->CurrentUser);
    $oldval->LoadByTicketContentAndCustomField (Ticket => $args{'Ticket'}, 
                                                Content =>  $args{'Content'}, 
                                                CustomField => $self->Id );
    # check ot make sure we found it
    unless ($oldval->Id) {
        return(0, $self->loc("Custom field value [_1] could not be found for custom field [_2]", $args{'Content'}, $self->Name));
    }
    # delete it

    my $ret = $oldval->Delete();
    unless ($ret) {
        return(0, $self->loc("Custom field value could not be found"));
    }
    return(1, $self->loc("Custom field value deleted"));
}


# }}}
# }}}


=head2 ValidateQueue Queue

Make sure that the queue specified is a valid queue name

=cut

sub ValidateQueue {
    my $self = shift;
    my $id = shift;

    if ($id eq '0') { # 0 means "Global" null would _not_ be ok.
        return (1); 
    }

    my $q = RT::Queue->new($RT::SystemUser);
    $q->Load($id);
    unless ($q->id) {
        return undef;
    }
    return (1);


}


# {{{ Types

=head2 Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
	return (@TYPES);
}

# }}}


=head2 FriendlyType [TYPE, MAX_VALUES]

Returns a localized human-readable version of the custom field type.
If a custom field type is specified as the parameter, the friendly type for that type will be returned

=cut

my %FriendlyTypes = (
    Select => [
        'Select multiple values',	# loc
        'Select one value',		# loc
        'Select up to [_1] values',	# loc
    ],
    Freeform => [
        'Enter multiple values',	# loc
        'Enter one value',		# loc
        'Enter up to [_1] values',	# loc
    ],
    Text => [
        'Fill in multiple text areas',	# loc
        'Fill in one text area',	# loc
        'Fill in up to [_1] text areas',# loc
    ],
    Image => [
        'Upload multiple images',	# loc
        'Upload one image',		# loc
        'Upload up to [_1] images',	# loc
    ],
    Binary => [
        'Upload multiple files',	# loc
        'Upload one files',		# loc
        'Upload up to [_1] files',	# loc
    ],
);

sub FriendlyType {
    my $self = shift;

    my $type = @_ ? shift : $self->Type;
    my $max  = @_ ? shift : $self->MaxValues;

    if (my $friendly_type = $FriendlyTypes{$type}[$max>2 ? 2 : $max]) {
	return ( $self->loc( $friendly_type, $max ) );
    }
    else {
        return ( $self->loc( $type ) );
    }
}

sub FriendlyTypeComposite {
    my $self = shift;
    my $composite = shift || $self->TypeComposite;
    return $self->FriendlyType(split(/-/, $composite, 2));
}


=head2 ValidateType TYPE

Takes a single string. returns true if that string is a value
type of custom field

=begin testing

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

=head2 SingleValue

Returns true if this CustomField only accepts a single value. 
Returns false if it accepts multiple values

=cut

sub SingleValue {
    my $self = shift;
    if ($self->MaxValues == 1) {
        return 1;
    } 
    else {
        return undef;
    }
}

sub UnlimitedValues {
    my $self = shift;
    if ($self->MaxValues == 0) {
        return 1;
    } 
    else {
        return undef;
    }
}

# }}}

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight RIGHT

Helper function to call the custom field's queue's CurrentUserHasRight with the passed in args.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    # if there's no queue, we want to know about a global right
    if ( ( !defined $self->__Value('Queue') ) || ( $self->__Value('Queue') == 0 ) ) {
         return $self->CurrentUser->HasRight( Object => $RT::System, Right => $right); 
    } else {
        return ( $self->QueueObj->CurrentUserHasRight($right) );
    }
}

# }}}

# {{{ sub _Set

sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminCustomFields') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return ( $self->SUPER::_Set(@_) );

}

# }}}

# {{{ sub _Value 

=head2 _Value

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


    #Anybody can see global custom fields, otherwise we need to do the rights check
        unless ( $self->__Value('Queue') == 0 || $self->CurrentUserHasRight( 'SeeQueue') ) {
            return (undef);
        }
    return ( $self->__Value($field) );

}

# }}}
# {{{ sub SetDisabled

=head2 SetDisabled

Takes a boolean.
1 will cause this custom field to no longer be avaialble for tickets.
0 will re-enable this queue

=cut

# }}}

sub Queue {
    return 0;
}

sub SetQueue {
    return 0;
}

sub SetTypeComposite {
    my $self = shift;
    my $composite = shift;
    my ($type, $max_values) = split(/-/, $composite, 2);
    $self->SetType($type);
    $self->SetMaxValues($max_values);
}

sub SetLookupType {
    my $self = shift;
    my $lookup = shift;
    if ($lookup ne $self->LookupType) {
	# Okay... We need to invalidate our existing relationships
	my $ObjectCustomFields = RT::ObjectCustomFields->new($self->CurrentUser);
	$ObjectCustomFields->LimitToCustomField($self->Id);
	$_->Delete foreach @{$ObjectCustomFields->ItemsArrayRef};
    }
    $self->SUPER::SetLookupType($lookup);
}

sub TypeComposite {
    my $self = shift;
    join('-', $self->Type, $self->MaxValues);
}

sub TypeComposites {
    my $self = shift;
    return map { ("$_-1", "$_-0") } $self->Types;
}

sub LookupTypes {
    my $self = shift;
    qw(
	RT::Queue-RT::Ticket
	RT::User
	RT::Group
    );
}

my @FriendlyObjectTypes = (
    "[_1] objects",		    # loc
    "[_1]'s [_2] objects",	    # loc
    "[_1]'s [_2]'s [_3] objects",   # loc
);

sub FriendlyLookupType {
    my $self = shift;
    my $lookup = shift;
    my @types = map { s/^RT::// ? $self->loc($_) : $_ }
		grep {defined and length}
		split(/-/, $lookup || $self->LookupType) or return;
    return ( $self->loc( $FriendlyObjectTypes[$#types], @types ) );
}

sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
	return ( 0, $self->loc('Lookup type mismatch') );
    }

    unless ( $object->CurrentUserHasRight('AdminCustomFields') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ObjectCF = RT::ObjectCustomField->new( $self->CurrentUser );

    $ObjectCF->LoadByCols( ObjectId => $id, CustomField => $self->Id );
    if ( $ObjectCF->Id ) {
        return ( 0, $self->loc("That is already the current value") );
    }
    my ( $id, $msg ) =
      $ObjectCF->Create( ObjectId => $id, CustomField => $self->Id );

    return ( $id, $msg );
}

sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
	return ( 0, $self->loc('Object type mismatch') );
    }

    unless ( $object->CurrentUserHasRight('AdminCustomFields') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ObjectCF = RT::ObjectCustomField->new( $self->CurrentUser );

    $ObjectCF->LoadByCols( ObjectId => $id, CustomField => $self->Id );
    unless ( $ObjectCF->Id ) {
        return ( 0, $self->loc("This custom field does not apply to that object") );
    }
    my ( $id, $msg ) = $ObjectCF->Delete;

    return ( $id, $msg );
}

# {{{ AddValueForObject

=head2 AddValueForObject HASH

Adds a custom field value for a ticket. Takes a param hash of Object and Content

=cut

sub AddValueForObject {
	my $self = shift;
	my %args = ( Object => undef,
                 Content => undef,
		     @_ );
	my $obj = $args{'Object'} or return;

	my $newval = RT::ObjectCustomFieldValue->new($self->CurrentUser);
	my $val = $newval->Create(ObjectType => ref($obj),
	                    ObjectId => $obj->Id,
                            Content => $args{'Content'},
                            CustomField => $self->Id);

    return($val);

}


# }}}

# {{{ DeleteValueForObject

=head2 DeleteValueForObject HASH

Adds a custom field value for a ticket. Takes a param hash of Object and Content

=cut

sub DeleteValueForObject {
	my $self = shift;
	my %args = ( Object => undef,
                 Content => undef,
		     @_ );

	my $oldval = RT::ObjectCustomFieldValue->new($self->CurrentUser);
    $oldval->LoadByObjectContentAndCustomField (Object => $args{'Object'}, 
                                                Content =>  $args{'Content'}, 
                                                CustomField => $self->Id );
    # check ot make sure we found it
    unless ($oldval->Id) {
        return(0, $self->loc("Custom field value [_1] could not be found for custom field [_2]", $args{'Content'}, $self->Name));
    }
    # delete it

    my $ret = $oldval->Delete();
    unless ($ret) {
        return(0, $self->loc("Custom field value could not be found"));
    }
    return(1, $self->loc("Custom field value deleted"));
}

sub ValuesForObject {
	my $self = shift;
    my $object = shift;

	my $values = new RT::ObjectCustomFieldValues($self->CurrentUser);
	$values->LimitToCustomField($self->Id);
    $values->LimitToObject($object);

	return ($values);
}


# }}}

1;
