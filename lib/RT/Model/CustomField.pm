# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}

use warnings;
use strict;
package RT::Model::CustomField;

use base qw/ RT::Record/;
use strict;
no warnings qw(redefine);

use RT::Model::CustomFieldValueCollection;
use RT::Model::ObjectCustomFieldValueCollection;

sub table {'CustomFields'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
     
column        name => max_length is 200,      type is 'varchar(200)', default is '';
column        Type => max_length is 200,      type is 'varchar(200)', default is '';
column        MaxValues => max_length is 11,      type is 'int(11)', default is '0';
column        Pattern =>       type is 'longtext', default is '';
column        Repeated => max_length is 6,      type is 'smallint(6)', default is '0';
column        Description => max_length is 255,      type is 'varchar(255)', default is '';
column        SortOrder => max_length is 11,      type is 'int(11)', default is '0';
column        LookupType => max_length is 255,      type is 'varchar(255)', default is '';
column        Creator => max_length is 11,      type is 'int(11)', default is '0';
column        Created =>       type is 'datetime', default is '';
column        LastUpdatedBy => max_length is 11,      type is 'int(11)', default is '0';
column        LastUpdated =>       type is 'datetime', default is '';
column        disabled => max_length is 6,      type is 'smallint(6)', default is '0';
    };


our %FieldTypes = (
    Select => [
        'Select multiple values',    # loc
        'Select one value',        # loc
        'Select up to %1 values',    # loc
    ],
    Freeform => [
        'Enter multiple values',    # loc
        'Enter one value',        # loc
        'Enter up to %1 values',    # loc
    ],
    Text => [
        'Fill in multiple text areas',    # loc
        'Fill in one text area',    # loc
        'Fill in up to %1 text areas',# loc
    ],
    Wikitext => [
        'Fill in multiple wikitext areas',    # loc
        'Fill in one wikitext area',    # loc
        'Fill in up to %1 wikitext areas',# loc
    ],
    Image => [
        'Upload multiple images',    # loc
        'Upload one image',        # loc
        'Upload up to %1 images',    # loc
    ],
    Binary => [
        'Upload multiple files',    # loc
        'Upload one file',        # loc
        'Upload up to %1 files',    # loc
    ],
    Combobox => [
        'Combobox: Select or enter multiple values',    # loc
        'Combobox: Select or enter one value',        # loc
        'Combobox: Select or enter up to %1 values',    # loc
    ],
    Autocomplete => [
        'Enter multiple values with autocompletion',    # loc
        'Enter one value with autocompletion',            # loc
        'Enter up to %1 values with autocompletion',    # loc
    ],
);


our %FRIENDLY_OBJECT_TYPES =  ();

RT::Model::CustomField->_Forobject_type( 'RT::Model::Queue-RT::Model::Ticket' => "Tickets", );    #loc
RT::Model::CustomField->_Forobject_type(
    'RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction' => "Ticket Transactions", );    #loc
RT::Model::CustomField->_Forobject_type( 'RT::Model::User'  => "Users", );                           #loc
RT::Model::CustomField->_Forobject_type( 'RT::Model::Group' => "Groups", );                          #loc

our $RIGHTS = {
    SeeCustomField            => 'See custom fields',       # loc_pair
    AdminCustomField          => 'Create, delete and modify custom fields',        # loc_pair
    ModifyCustomField         => 'Add, delete and modify custom field values for objects' #loc_pair
};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::Model::CustomField'} = 1;

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

sub AvailableRights {
    my $self = shift;
    return $RIGHTS;
}

=head1 name

  RT::Model::CustomField_Overlay - overlay for RT::Model::CustomField

=head1 DESCRIPTION

=head1 'CORE' METHODS

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'name'.
  varchar(200) 'Type'.
  int(11) 'MaxValues'.
  varchar(255) 'Pattern'.
  smallint(6) 'Repeated'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.
  varchar(255) 'LookupType'.
  smallint(6) 'disabled'.

C<LookupType> is generally the result of either
C<RT::Model::Ticket->custom_field_lookup_type> or C<RT::Model::Transaction->custom_field_lookup_type>.

=cut

sub create {
    my $self = shift;
    my %args = (
        name        => '',
        Type        => '',
        MaxValues   => 0,
        Pattern     => '',
        Description => '',
        disabled    => 0,
        LookupType  => '',
        Repeated    => 0,
        @_,
    );

    unless ( $self->current_user->has_right(Object => RT->system, Right => 'AdminCustomField') ) {
        return (0, _('Permission Denied'));
    }

    if ( $args{TypeComposite} ) {
        @args{'Type', 'MaxValues'} = split(/-/, $args{TypeComposite}, 2);
    }
    elsif ( $args{Type} =~ s/(?:(Single)|Multiple)$// ) {
        # old style Type string
        $args{'MaxValues'} = $1 ? 1 : 0;
    }
    
    if ( !exists $args{'Queue'}) {
    # do nothing -- things below are strictly backward compat
    }
    elsif (  ! $args{'Queue'} ) {
        unless ( $self->current_user->has_right( Object => RT->system, Right => 'AssignCustomFields') ) {
            return ( 0, _('Permission Denied') );
        }
        $args{'LookupType'} = 'RT::Model::Queue-RT::Model::Ticket';
    }
    else {
        my $queue = RT::Model::Queue->new;
        $queue->load($args{'Queue'});
        unless ($queue->id) {
            return (0, _("Queue not found"));
        }
        unless ( $queue->current_user_has_right('AssignCustomFields') ) {
            return ( 0, _('Permission Denied') );
        }
        $args{'LookupType'} = 'RT::Model::Queue-RT::Model::Ticket';
        $args{'Queue'} = $queue->id;
    }

    my ($ok, $msg) = $self->_IsValidRegex( $args{'Pattern'} );
    return (0, _("Invalid pattern: %1", $msg)) unless $ok;

    (my $rv, $msg) = $self->SUPER::create(
        name        => $args{'name'},
        Type        => $args{'Type'},
        MaxValues   => $args{'MaxValues'},
        Pattern     => $args{'Pattern'},
        Description => $args{'Description'},
        disabled    => $args{'disabled'},
        LookupType  => $args{'LookupType'},
        Repeated    => $args{'Repeated'},
    );

    if ( exists $args{'ValuesClass'} ) {
        $self->set_ValuesClass( $args{'ValuesClass'} );
    }

    return ($rv, $msg) unless exists $args{'Queue'};

    # Compat code -- create a new ObjectCustomField mapping
    my $OCF = RT::Model::ObjectCustomField->new;
    $OCF->create(
        CustomField => $self->id,
        object_id => $args{'Queue'},
    );

    return ($rv, $msg);
}

=head2 Load ID/name

Load a custom field.  If the value handed in is an integer, load by custom field ID. Otherwise, Load by name.

=cut

sub load {
    my $self = shift;
    my $id = shift || '';

    if ( $id =~ /^\d+$/ ) {
        return $self->SUPER::load( $id );
    } else {
        return $self->load_by_name( name => $id );
    }
}


# {{{ sub load_by_name

=head2 load_by_name (Queue => QUEUEID, name => name)

Loads the Custom field named name.

If a Queue parameter is specified, only look for ticket custom fields tied to that Queue.

If the Queue parameter is '0', look for global ticket custom fields.

If no queue parameter is specified, look for any and all custom fields with this name.

BUG/TODO, this won't let you specify that you only want user or group CFs.

=cut

# Compatibility for API change after 3.0 beta 1
*LoadnameAndQueue = \&load_by_name;
# Change after 3.4 beta.
*load_by_name_and_queue = \&load_by_name;

sub load_by_name {
    my $self = shift;
    my %args = (
        Queue => undef,
        name  => undef,
        @_,
    );

    # if we're looking for a queue by name, make it a number
    if ( defined $args{'Queue'} && $args{'Queue'} =~ /\D/ ) {
        my $queue_obj = RT::Model::Queue->new;
        $queue_obj->load( $args{'Queue'} );
        $args{'Queue'} = $queue_obj->id;
    }

    # XXX - really naive implementation.  Slow. - not really. still just one query

    my $CFs = RT::Model::CustomFieldCollection->new;
    Carp::cluck unless ($args{'name'});
    $CFs->limit( column => 'name', value => $args{'name'}, case_sensitive => 0);
    # Don't limit to queue if queue is 0.  Trying to do so breaks
    # RT::Model::Group type CFs.
    if ( defined $args{'Queue'} ) {
        $CFs->limit_ToQueue( $args{'Queue'} );
    }

    # When loading by name, it's ok if they're disabled. That's not a big deal.
    $CFs->{'find_disabled_rows'}=1;

    # We only want one entry.
    $CFs->rows_per_page(1);
    return (0, _("Not found")) unless my $first = $CFs->first;
    return $self->load_by_id( $first->id );
}

# }}}

# {{{ Dealing with custom field values 


=cut

=head2 Custom field values

=head3 Values column

Return a object (collection) of all acceptable values for this Custom Field.
Class of the object can vary and depends on the return value
of the C<ValuesClass> method.

=cut

*ValuesObj = \&Values;

sub Values {
    my $self = shift;

    my $class = $self->ValuesClass || 'RT::Model::CustomFieldValueCollection';
    eval "require $class" or die "$@";
    my $cf_values = $class->new;
    # if the user has no rights, return an empty object
    if ( $self->id && $self->current_user_has_right( 'SeeCustomField') ) {
        $cf_values->limit_to_custom_field( $self->id );
    }
    return ($cf_values);
}

# {{{ AddValue

=head3 AddValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements name, Description and SortOrder


=cut

sub AddValue {
    my $self = shift;
    my %args = @_;

    unless ($self->current_user_has_right('AdminCustomField')) {
        return (0, _('Permission Denied'));
    }

    # allow zero value
    if ( !defined $args{'name'} || $args{'name'} eq '' ) {
        return (0, _("Can't add a custom field value without a name"));
    }

    my $newval = RT::Model::CustomFieldValue->new;
    return $newval->create( %args, CustomField => $self->id );
}


# }}}

# {{{ DeleteValue

=head3 DeleteValue ID

Deletes a value from this custom field by id.

Does not remove this value for any article which has had it selected

=cut

sub deleteValue {
    my $self = shift;
    my $id = shift;
    unless ( $self->current_user_has_right('AdminCustomField') ) {
        return (0, _('Permission Denied'));
    }

    my $val_to_del = RT::Model::CustomFieldValue->new;
    $val_to_del->load( $id );
    unless ( $val_to_del->id ) {
        return (0, _("Couldn't find that value"));
    }
    unless ( $val_to_del->CustomField == $self->id ) {
        return (0, _("That is not a value for this custom field"));
    }

    my $retval = $val_to_del->delete;
    unless ( $retval ) {
        return (0, _("Custom field value could not be deleted"));
    }
    return ($retval, _("Custom field value deleted"));
}

# }}}


=head2 ValidateQueue Queue

Make sure that the queue specified is a valid queue name

=cut

sub validate_Queue {
    my $self = shift;
    my $id = shift || '';

    return undef unless defined $id;
    # 0 means "Global" null would _not_ be ok.
    return 1 if $id eq '0';

    my $q = RT::Model::Queue->new(current_user => RT->system_user );
    $q->load( $id );
    return undef unless $q->id;
    return 1;
}


# {{{ Types

=head2 Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
    return (keys %FieldTypes);
}

# }}}

# {{{ IsSelectionType
 
=head2 IsSelectionType 

Retuns a boolean value indicating whether the C<Values> method makes sense
to this Custom Field.

=cut

sub IsSelectionType {
    my $self = shift;
    my $type = @_? shift : $self->Type;
    return undef unless $type;

    $type =~ /(?:Select|Combobox|Autocomplete)/;
}

# }}}


=head2 IsExternalValues

=cut

sub IsExternalValues {
    my $self = shift;
    my $selectable = $self->IsSelectionType( @_ );
    return $selectable unless $selectable;

    my $class = $self->ValuesClass;
    return 0 if $class eq 'RT::Model::CustomFieldValueCollection';
    return 1;
}

sub ValuesClass {
    my $self = shift;
    return '' unless $self->IsSelectionType;

    my $class = $self->first_attribute( 'ValuesClass' );
    $class = $class->Content if $class;
    return $class || 'RT::Model::CustomFieldValueCollection';
}

sub set_ValuesClass {
    my $self = shift;
    my $class = shift || 'RT::Model::CustomFieldValueCollection';

    if( $class eq 'RT::Model::CustomFieldValueCollection' ) {
        return $self->delete_attribute( 'ValuesClass' );
    }
    return $self->set_attribute( name => 'ValuesClass', Content => $class );
}


=head2 FriendlyType [TYPE, MAX_valueS]

Returns a localized human-readable version of the custom field type.
If a custom field type is specified as the parameter, the friendly type for that type will be returned

=cut

sub FriendlyType {
    my $self = shift;

    my $type = @_ ? shift : $self->Type;
    my $max  = @_ ? shift : $self->MaxValues;
    $max = 0 unless $max;

    if (my $friendly_type = $FieldTypes{$type}[ $max && $max>2 ? 2 : $max]) {
        return ( _( $friendly_type, $max ) );
    }
    else {
        return ( _( $type ) );
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


=cut

sub validate_Type {
    my $self = shift;
    my $type = shift;

    if ( $type =~ s/(?:Single|Multiple)$// ) {
        Jifty->log->warn( "Prefix 'Single' and 'Multiple' to Type deprecated, use MaxValues instead at (". join(":",caller).")");
    }

    if ( $FieldTypes{$type} ) {
        return 1;
    }
    else {
        return undef;
    }
}


sub set_Type {
    my $self = shift;
    my $type = shift;
    if ($type =~ s/(?:(Single)|Multiple)$//) {
        Jifty->log->warn("'Single' and 'Multiple' on SetType deprecated, use SetMaxValues instead at (". join(":",caller).")");
        $self->set_MaxValues($1 ? 1 : 0);
    }
    $self->_set(column =>'Type', value => $type);
}

=head2 SetPattern STRING

Takes a single string representing a regular expression.  Performs basic
validation on that regex, and sets the C<Pattern> field for the CF if it
is valid.

=cut

sub set_Pattern {
    my $self = shift;
    my $regex = shift;

    my ($ok, $msg) = $self->_IsValidRegex($regex);
    if ($ok) {
        return $self->set(column => 'Pattern', value => $regex);
    }
    else {
        return (0, _("Invalid pattern: %1", $msg));
    }
}

=head2 _IsValidRegex(Str $regex) returns (Bool $success, Str $msg)

Tests if the string contains an invalid regex.

=cut

sub _IsValidRegex {
    my $self  = shift;
    my $regex = shift or return (1, 'valid');

    local $^W; local $@;
    local $SIG{__DIE__} = sub { 1 };
    local $SIG{__WARN__} = sub { 1 };

    if (eval { qr/$regex/; 1 }) {
        return (1, 'valid');
    }

    my $err = $@;
    $err =~ s{[,;].*}{};    # strip debug info from error
    chomp $err;
    return (0, $err);
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

sub unlimitedValues {
    my $self = shift;
    if ($self->MaxValues == 0) {
        return 1;
    } 
    else {
        return undef;
    }
}

# }}}

# {{{ sub current_user_has_right

=head2 current_user_has_right RIGHT

Helper function to call the custom field's queue's current_user_has_right with the passed in args.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;

    return $self->current_user->has_right(
        Object => $self,
        Right  => $right,
    );
}

# }}}

# {{{ sub _set

sub _set {
    my $self = shift;

    unless ( $self->current_user_has_right('AdminCustomField') ) {
        return ( 0, _('Permission Denied') );
    }
    return $self->SUPER::_set( @_ );

}

# }}}

# {{{ sub _value 

=head2 _value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _value {
    my $self  = shift;
    return undef unless $self->id;

    # we need to do the rights check
    unless ( $self->current_user_has_right('SeeCustomField') ) {
        Jifty->log->debug(
            "Permission denied. User #". $self->current_user->id
            ." has no SeeCustomField right on CF #". $self->id
        );
        return (undef);
    }
    return $self->__value( @_ );
}

# }}}
# {{{ sub set_disabled

=head2 Setdisabled

Takes a boolean.
1 will cause this custom field to no longer be avaialble for objects.
0 will re-enable this field.

=cut

# }}}

=head2 SetTypeComposite

Set this custom field's type and maximum values as a composite value


=cut

sub set_TypeComposite {
    my $self = shift;
    my $composite = shift;

    my $old = $self->TypeComposite;

    my ($type, $max_values) = split(/-/, $composite, 2);
    if ( $type ne $self->Type ) {
        my ($status, $msg) = $self->set_Type( $type );
        return ($status, $msg) unless $status;
    }
    if ( ($max_values || 0) != ($self->MaxValues || 0) ) {
        my ($status, $msg) = $self->set_MaxValues( $max_values );
        return ($status, $msg) unless $status;
    }
    return 1, _(
        "Type changed from '%1' to '%2'",
        $self->FriendlyTypeComposite( $old ),
        $self->FriendlyTypeComposite( $composite ),
    );
}

=head2 SetLookupType

Autrijus: care to doc how LookupTypes work?

=cut

sub set_LookupType {
    my $self = shift;
    my $lookup = shift;
    if ( $lookup ne $self->LookupType ) {
        # Okay... We need to invalidate our existing relationships
        my $ObjectCustomFields = RT::Model::ObjectCustomFieldCollection->new;
        $ObjectCustomFields->limit_to_custom_field($self->id);
        $_->delete foreach @{$ObjectCustomFields->items_array_ref};
    }
    return $self->_set(column => 'LookupType', value => $lookup);
}

=head2 TypeComposite

Returns a composite value composed of this object's type and maximum values

=cut


sub TypeComposite {
    my $self = shift;
    return join '-', ($self->Type || ''), ($self->MaxValues || 0);
}

=head2 TypeComposites

Returns an array of all possible composite values for custom fields.

=cut

sub TypeComposites {
    my $self = shift;
    return grep !/(?:[Tt]ext|Combobox)-0/, map { ("$_-1", "$_-0") } $self->Types;
}

=head2 LookupTypes

Returns an array of LookupTypes available

=cut


sub LookupTypes {
    my $self = shift;
    return keys %FRIENDLY_OBJECT_TYPES;
}

my @Friendlyobject_types = (
    "%1 objects",            # loc
    "%1's %2 objects",        # loc
    "%1's %2's %3 objects",   # loc
);

=head2 FriendlyTypeLookup

=cut

sub FriendlyLookupType {
    my $self = shift;
    my $lookup = shift || $self->LookupType;
   
    return (_( $FRIENDLY_OBJECT_TYPES{$lookup} ))
                     if (defined  $FRIENDLY_OBJECT_TYPES{$lookup} );

    my @types = map { s/^RT::// ? _($_) : $_ }
      grep { defined and length }
      split( /-/, $lookup )
      or return;
    return ( _( $Friendlyobject_types[$#types], @types ) );
}


=head2 AddToObject OBJECT

Add this custom field as a custom field for a single object, such as a queue or group.

Takes an object 

=cut


sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
        return ( 0, _('Lookup type mismatch') );
    }

    unless ( $object->current_user_has_right('AssignCustomFields') ) {
        return ( 0, _('Permission Denied') );
    }

    my $ObjectCF = RT::Model::ObjectCustomField->new;
    $ObjectCF->load_by_cols( object_id => $id, CustomField => $self->id );
    if ( $ObjectCF->id ) {
        return ( 0, _("That is already the current value") );
    }
    my ( $oid, $msg ) =
      $ObjectCF->create( object_id => $id, CustomField => $self->id );

    return ( $oid, $msg );
}


=head2 RemoveFromObject OBJECT

Remove this custom field  for a single object, such as a queue or group.

Takes an object 

=cut


sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
        return ( 0, _('Object type mismatch') );
    }

    unless ( $object->current_user_has_right('AssignCustomFields') ) {
        return ( 0, _('Permission Denied') );
    }

    my $ObjectCF = RT::Model::ObjectCustomField->new;
    $ObjectCF->load_by_cols( object_id => $id, CustomField => $self->id );
    unless ( $ObjectCF->id ) {
        return ( 0, _("This custom field does not apply to that object") );
    }
    # XXX: Delete doesn't return anything
    my ( $oid, $msg ) = $ObjectCF->delete;

    return ( $oid, $msg );
}

# {{{ add_value_for_object

=head2 add_value_for_object HASH

Adds a custom field value for a record object of some kind. 
Takes a param hash of 

Required:

    Object
    Content

Optional:

    LargeContent
    ContentType

=cut

sub add_value_for_object {
    my $self = shift;
    my %args = (
        Object       => undef,
        Content      => undef,
        LargeContent => undef,
        ContentType  => undef,
        @_
    );
    my $obj = $args{'Object'} or return ( 0, _('Invalid object') );

    unless ( $self->current_user_has_right('ModifyCustomField') ) {
        return ( 0, _('Permission Denied') );
    }

    unless ( $self->MatchPattern($args{'Content'} || '' ) ) {
        return ( 0, _('Input must match %1', $self->FriendlyPattern) );
    }

    Jifty->handle->begin_transaction;

    if ( $self->MaxValues ) {
        my $current_values = $self->values_for_object($obj);
        my $extra_values = ( $current_values->count + 1 ) - $self->MaxValues;

        # (The +1 is for the new value we're adding)

        # If we have a set of current values and we've gone over the maximum
        # allowed number of values, we'll need to delete some to make room.
        # which former values are blown away is not guaranteed

        while ($extra_values) {
            my $extra_item = $current_values->next;
            unless ( $extra_item->id ) {
                Jifty->log->fatal( "We were just asked to delete "
                    ."a custom field value that doesn't exist!" );
                Jifty->handle->rollback();
                return (undef);
            }
            $extra_item->delete;
            $extra_values--;
        }
    }
    my $newval = RT::Model::ObjectCustomFieldValue->new;
    my $val    = $newval->create(
        object_type   => ref($obj),
        object_id     => $obj->id,
        Content      => $args{'Content'},
        LargeContent => $args{'LargeContent'},
        ContentType  => $args{'ContentType'},
        CustomField  => $self->id
    );

    unless ($val) {
        Jifty->handle->rollback();
        return ($val, _("Couldn't create record"));
    }

    Jifty->handle->commit();
    return ($val);

}

# }}}

# {{{ MatchPattern

=head2 MatchPattern STRING

Tests the incoming string against the Pattern of this custom field object
and returns a boolean; returns true if the Pattern is empty.

=cut

sub MatchPattern {
    my $self = shift;
    my $regex = $self->Pattern or return 1;

    return (($_[0] || '') =~ $regex);
}


# }}}

# {{{ FriendlyPattern

=head2 FriendlyPattern

Prettify the pattern of this custom field, by taking the text in C<(?#text)>
and localizing it.

=cut

sub FriendlyPattern {
    my $self = shift;
    my $regex = $self->Pattern;

    return '' unless length $regex;
    if ( $regex =~ /\(\?#([^)]*)\)/ ) {
        return '[' . _($1) . ']';
    }
    else {
        return $regex;
    }
}


# }}}

# {{{ delete_value_for_object

=head2 delete_value_for_object HASH

Deletes a custom field value for a ticket. Takes a param hash of Object and Content

Returns a tuple of (STATUS, MESSAGE). If the call succeeded, the STATUS is true. otherwise it's false

=cut

sub delete_value_for_object {
    my $self = shift;
    my %args = ( Object => undef,
                 Content => undef,
                 Id => undef,
             @_ );


    unless ($self->current_user_has_right('ModifyCustomField')) {
        return (0, _('Permission Denied'));
    }

    my $oldval = RT::Model::ObjectCustomFieldValue->new;

    if (my $id = $args{'Id'}) {
        $oldval->load($id);
    }
    unless ($oldval->id) { 
        $oldval->loadByObjectContentAndCustomField(
            Object => $args{'Object'}, 
            Content =>  $args{'Content'}, 
            CustomField => $self->id,
        );
    }


    # check to make sure we found it
    unless ($oldval->id) {
        return(0, _("Custom field value %1 could not be found for custom field %2", $args{'Content'}, $self->name));
    }

    # for single-value fields, we need to validate that empty string is a valid value for it
    if ( $self->SingleValue and not $self->MatchPattern( '' ) ) {
        return ( 0, _('Input must match %1', $self->FriendlyPattern) );
    }

    # delete it

    my $ret = $oldval->delete();
    unless ($ret) {
        return(0, _("Custom field value could not be found"));
    }
    return($oldval->id, _("Custom field value deleted"));
}


=head2 values_for_object OBJECT

Return an L<RT::Model::ObjectCustomFieldValueCollection> object containing all of this custom field's values for OBJECT 

=cut

sub values_for_object {
    my $self = shift;
    my $object = shift;

    my $values = RT::Model::ObjectCustomFieldValueCollection->new();
    unless ($self->current_user_has_right('SeeCustomField')) {
        # Return an empty object if they have no rights to see
        return ($values);
    }
    
    
    $values->limit_to_custom_field($self->id);
    $values->limit_to_enabled();
    $values->limit_to_object($object);

    return ($values);
}


=head2 _Forobject_type PATH friendly_name

Tell RT that a certain object accepts custom fields

Examples:

    'RT::Model::Queue-RT::Model::Ticket'                 => "Tickets",                # loc
    'RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction' => "Ticket Transactions",    # loc
    'RT::Model::User'                             => "Users",                  # loc
    'RT::Model::Group'                            => "Groups",                 # loc

This is a class method. 

=cut

sub _Forobject_type {
    my $self = shift;
    my $path = shift;
    my $friendly_name = shift;

    $FRIENDLY_OBJECT_TYPES{$path} = $friendly_name;

}


=head2 IncludeContentForValue [value] (and SetIncludeContentForValue)

Gets or sets the  C<IncludeContentForValue> for this custom field. RT
uses this field to automatically include content into the user's browser
as they display records with custom fields in RT.

=cut

sub set_IncludeContentForValue {
    shift->IncludeContentForValue(@_);
}
sub IncludeContentForValue{
    my $self = shift;
    $self->_URLTemplate('IncludeContentForValue', @_);
}



=head2 LinkValueTo [value] (and SetLinkValueTo)

Gets or sets the  C<LinkValueTo> for this custom field. RT
uses this field to make custom field values into hyperlinks in the user's
browser as they display records with custom fields in RT.

=cut


sub set_LinkValueTo {
    shift->LinkValueTo(@_);
}

sub LinkValueTo {
    my $self = shift;
    $self->_URLTemplate('LinkValueTo', @_);

}


=head2 _URLTemplate  name [value]

With one argument, returns the _URLTemplate named C<name>, but only if
the current user has the right to see this custom field.

With two arguments, attemptes to set the relevant template value.

=cut



sub _URLTemplate {
    my $self          = shift;
    my $template_name = shift;
    if (@_) {

        my $value = shift;
        unless ( $self->current_user_has_right('AdminCustomField') ) {
            return ( 0, _('Permission Denied') );
        }
        $self->set_attribute( name => $template_name, Content => $value );
        return ( 1, _('Updated') );
    } else {
        unless ( $self->id && $self->current_user_has_right('SeeCustomField') ) {
            return (undef);
        }

        my @attr = $self->attributes->named($template_name);
        my $attr = shift @attr;

        if ($attr) { return $attr->Content }

    }
}

1;
