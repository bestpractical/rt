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

use vars qw(@TYPES %TYPES);

use RT::CustomFieldValues;
use RT::TicketCustomFieldValues;

# Enumerate all valid types for this custom field
@TYPES = (
    'SelectSingle',	# loc
    'SelectMultiple',	# loc
    'FreeformSingle',	# loc
    'FreeformMultiple', # loc
);

# Populate a hash of types of easier validation
for (@TYPES) { $TYPES{$_} = 1};




=head1 NAME

  RT::CustomField_Overlay 

=head1 DESCRIPTION

=head1 'CORE' METHODS

=cut



=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Type'.
  int(11) 'Queue'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.
  smallint(6) 'Disabled'.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Type => '',
                Queue => '0',
                Description => '',
                SortOrder => '0',
                Disabled => '0',

		  @_);

    

    if (  ! $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System, Right => 'AdminCustomFields') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
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
    }
    $self->SUPER::Create(
                         Name => $args{'Name'},
                         Type => $args{'Type'},
                         Queue => $args{'Queue'},
                         Description => $args{'Description'},
                         SortOrder => $args{'SortOrder'},
                         Disabled => $args{'Disabled'},
);

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

    return ( $self->LoadByCols( Name => $args{'Name'}, Queue => $args{'Queue'} ) );

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

# }}}

# }}}

# {{{ Ticket related routines

# {{{ ValuesForTicket

=head2 ValuesForTicket TICKET

Returns a RT::TicketCustomFieldValues object of this Field's values for TICKET.
TICKET is a ticket id.


=cut

sub ValuesForTicket {
	my $self = shift;
    my $ticket_id = shift;

	my $values = new RT::TicketCustomFieldValues($self->CurrentUser);
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

	my $newval = RT::TicketCustomFieldValue->new($self->CurrentUser);
	my $val = $newval->Create(Ticket => $args{'Ticket'},
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

	my $oldval = RT::TicketCustomFieldValue->new($self->CurrentUser);
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


=head2 FriendlyType [TYPE]

Returns a localized human-readable version of the custom field type.
If a custom field type is specified as the parameter, the friendly type for that type will be returned

=cut

sub FriendlyType {
    my $self = shift;

    my $type = shift || $self->Type;

    if ( $type eq 'SelectSingle' ) {
        return ( $self->loc('Select one value') );
    }
    elsif ( $type eq 'SelectMultiple' ) {
        return ( $self->loc('Select multiple values') );
    }
    elsif ( $type eq 'FreeformSingle' ) {
        return ( $self->loc('Enter one value') );
    }
    elsif ( $type eq 'FreeformMultiple' ) {
        return ( $self->loc('Enter multiple values') );
    }
    else {
        return ( $self->loc( $self->Type ) );
    }
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
    if ($self->Type =~  /Single$/) {
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

1;
