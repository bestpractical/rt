# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::CustomField;

use strict;
use warnings;



use base 'RT::Record';

sub Table {'CustomFields'}

use Scalar::Util qw(blessed);
use RT::CustomFieldValues;
use RT::ObjectCustomFields;
use RT::ObjectCustomFieldValues;

our %FieldTypes = (
    Select => {
        sort_order => 10,
        selection_type => 1,

        labels => [ 'Select multiple values',      # loc
                    'Select one value',            # loc
                    'Select up to [_1] values',    # loc
                  ],

        render_types => {
            multiple => [

                # Default is the first one
                'Select box',              # loc
                'List',                    # loc
            ],
            single => [ 'Select box',              # loc
                        'Dropdown',                # loc
                        'List',                    # loc
                      ]
        },

    },
    Freeform => {
        sort_order => 20,
        selection_type => 0,

        labels => [ 'Enter multiple values',       # loc
                    'Enter one value',             # loc
                    'Enter up to [_1] values',     # loc
                  ]
                },
    Text => {
        sort_order => 30,
        selection_type => 0,
        labels         => [
                    'Fill in multiple text areas',      # loc
                    'Fill in one text area',            # loc
                    'Fill in up to [_1] text areas',    # loc
                  ]
            },
    Wikitext => {
        sort_order => 40,
        selection_type => 0,
        labels         => [
                    'Fill in multiple wikitext areas',      # loc
                    'Fill in one wikitext area',            # loc
                    'Fill in up to [_1] wikitext areas',    # loc
                  ]
                },

    Image => {
        sort_order => 50,
        selection_type => 0,
        labels         => [
                    'Upload multiple images',               # loc
                    'Upload one image',                     # loc
                    'Upload up to [_1] images',             # loc
                  ]
             },
    Binary => {
        sort_order => 60,
        selection_type => 0,
        labels         => [
                    'Upload multiple files',                # loc
                    'Upload one file',                      # loc
                    'Upload up to [_1] files',              # loc
                  ]
              },

    Combobox => {
        sort_order => 70,
        selection_type => 1,
        labels         => [
                    'Combobox: Select or enter multiple values',      # loc
                    'Combobox: Select or enter one value',            # loc
                    'Combobox: Select or enter up to [_1] values',    # loc
                  ]
                },
    Autocomplete => {
        sort_order => 80,
        selection_type => 1,
        labels         => [
                    'Enter multiple values with autocompletion',      # loc
                    'Enter one value with autocompletion',            # loc
                    'Enter up to [_1] values with autocompletion',    # loc
                  ]
    },

    Date => {
        sort_order => 90,
        selection_type => 0,
        labels         => [
                    'Select multiple dates',                          # loc
                    'Select date',                                    # loc
                    'Select up to [_1] dates',                        # loc
                  ]
            },
    DateTime => {
        sort_order => 100,
        selection_type => 0,
        labels         => [
                    'Select multiple datetimes',                      # loc
                    'Select datetime',                                # loc
                    'Select up to [_1] datetimes',                    # loc
                  ]
                },

    IPAddress => {
        sort_order => 110,
        selection_type => 0,

        labels => [ 'Enter multiple IP addresses',       # loc
                    'Enter one IP address',             # loc
                    'Enter up to [_1] IP addresses',     # loc
                  ]
                },
    IPAddressRange => {
        sort_order => 120,
        selection_type => 0,

        labels => [ 'Enter multiple IP address ranges',       # loc
                    'Enter one IP address range',             # loc
                    'Enter up to [_1] IP address ranges',     # loc
                  ]
                },
);


my %BUILTIN_GROUPINGS;
our %FRIENDLY_OBJECT_TYPES =  ();

RT::CustomField->_ForObjectType( 'RT::Queue-RT::Ticket' => "Tickets", );    #loc
RT::CustomField->_ForObjectType(
    'RT::Queue-RT::Ticket-RT::Transaction' => "Ticket Transactions", );    #loc
RT::CustomField->_ForObjectType( 'RT::User'  => "Users", );                           #loc
RT::CustomField->_ForObjectType( 'RT::Queue'  => "Queues", );                         #loc
RT::CustomField->_ForObjectType( 'RT::Group' => "Groups", );                          #loc

__PACKAGE__->RegisterBuiltInGroupings(
    'RT::Ticket'    => [ qw(Basics Dates Links People) ],
    'RT::User'      => [ 'Identity', 'Access control', 'Location', 'Phones' ],
);

our $RIGHTS = {
    SeeCustomField            => 'View custom fields',                                    # loc_pair
    AdminCustomField          => 'Create, modify and delete custom fields',               # loc_pair
    AdminCustomFieldValues    => 'Create, modify and delete custom fields values',        # loc_pair
    ModifyCustomField         => 'Add, modify and delete custom field values for objects' # loc_pair
};

our $RIGHT_CATEGORIES = {
    SeeCustomField          => 'General',
    AdminCustomField        => 'Admin',
    AdminCustomFieldValues  => 'Admin',
    ModifyCustomField       => 'Staff',
};

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::CustomField'} = 1;

__PACKAGE__->AddRights(%$RIGHTS);
__PACKAGE__->AddRightCategories(%$RIGHT_CATEGORIES);

=head2 AddRights C<RIGHT>, C<DESCRIPTION> [, ...]

Adds the given rights to the list of possible rights.  This method
should be called during server startup, not at runtime.

=cut

sub AddRights {
    my $self = shift;
    my %new = @_;
    $RIGHTS = { %$RIGHTS, %new };
    %RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                      map { lc($_) => $_ } keys %new);
}

sub AvailableRights {
    my $self = shift;
    return $RIGHTS;
}

=head2 RightCategories

Returns a hashref where the keys are rights for this type of object and the
values are the category (General, Staff, Admin) the right falls into.

=cut

sub RightCategories {
    return $RIGHT_CATEGORIES;
}

=head2 AddRightCategories C<RIGHT>, C<CATEGORY> [, ...]

Adds the given right and category pairs to the list of right categories.  This
method should be called during server startup, not at runtime.

=cut

sub AddRightCategories {
    my $self = shift if ref $_[0] or $_[0] eq __PACKAGE__;
    my %new = @_;
    $RIGHT_CATEGORIES = { %$RIGHT_CATEGORIES, %new };
}

=head1 NAME

  RT::CustomField_Overlay - overlay for RT::CustomField

=head1 DESCRIPTION

=head1 'CORE' METHODS

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(200) 'Type'.
  int(11) 'MaxValues'.
  varchar(255) 'Pattern'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.
  varchar(255) 'LookupType'.
  smallint(6) 'Disabled'.

C<LookupType> is generally the result of either
C<RT::Ticket->CustomFieldLookupType> or C<RT::Transaction->CustomFieldLookupType>.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => '',
        Type        => '',
        MaxValues   => 0,
        Pattern     => '',
        Description => '',
        Disabled    => 0,
        LookupType  => '',
        LinkValueTo => '',
        IncludeContentForValue => '',
        @_,
    );

    unless ( $self->CurrentUser->HasRight(Object => $RT::System, Right => 'AdminCustomField') ) {
        return (0, $self->loc('Permission Denied'));
    }

    if ( $args{TypeComposite} ) {
        @args{'Type', 'MaxValues'} = split(/-/, $args{TypeComposite}, 2);
    }
    elsif ( $args{Type} =~ s/(?:(Single)|Multiple)$// ) {
        # old style Type string
        $args{'MaxValues'} = $1 ? 1 : 0;
    }
    $args{'MaxValues'} = int $args{'MaxValues'};

    if ( !exists $args{'Queue'}) {
    # do nothing -- things below are strictly backward compat
    }
    elsif (  ! $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System, Right => 'AssignCustomFields') ) {
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
        unless ( $queue->CurrentUserHasRight('AssignCustomFields') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'LookupType'} = 'RT::Queue-RT::Ticket';
        $args{'Queue'} = $queue->Id;
    }

    my ($ok, $msg) = $self->_IsValidRegex( $args{'Pattern'} );
    return (0, $self->loc("Invalid pattern: [_1]", $msg)) unless $ok;

    if ( $args{'MaxValues'} != 1 && $args{'Type'} =~ /(text|combobox)$/i ) {
        $RT::Logger->debug("Support for 'multiple' Texts or Comboboxes is not implemented");
        $args{'MaxValues'} = 1;
    }

    if ( $args{'RenderType'} ||= undef ) {
        my $composite = join '-', @args{'Type', 'MaxValues'};
        return (0, $self->loc("This custom field has no Render Types"))
            unless $self->HasRenderTypes( $composite );

        if ( $args{'RenderType'} eq $self->DefaultRenderType( $composite ) ) {
            $args{'RenderType'} = undef;
        } else {
            return (0, $self->loc("Invalid Render Type") )
                unless grep $_ eq  $args{'RenderType'}, $self->RenderTypes( $composite );
        }
    }

    $args{'ValuesClass'} = undef if ($args{'ValuesClass'} || '') eq 'RT::CustomFieldValues';
    if ( $args{'ValuesClass'} ||= undef ) {
        return (0, $self->loc("This Custom Field can not have list of values"))
            unless $self->IsSelectionType( $args{'Type'} );

        unless ( $self->ValidateValuesClass( $args{'ValuesClass'} ) ) {
            return (0, $self->loc("Invalid Custom Field values source"));
        }
    }

    $args{'Disabled'} ||= 0;

    (my $rv, $msg) = $self->SUPER::Create(
        Name        => $args{'Name'},
        Type        => $args{'Type'},
        RenderType  => $args{'RenderType'},
        MaxValues   => $args{'MaxValues'},
        Pattern     => $args{'Pattern'},
        BasedOn     => $args{'BasedOn'},
        ValuesClass => $args{'ValuesClass'},
        Description => $args{'Description'},
        Disabled    => $args{'Disabled'},
        LookupType  => $args{'LookupType'},
    );

    if ($rv) {
        if ( exists $args{'LinkValueTo'}) {
            $self->SetLinkValueTo($args{'LinkValueTo'});
        }

        if ( exists $args{'IncludeContentForValue'}) {
            $self->SetIncludeContentForValue($args{'IncludeContentForValue'});
        }

        return ($rv, $msg) unless exists $args{'Queue'};

        # Compat code -- create a new ObjectCustomField mapping
        my $OCF = RT::ObjectCustomField->new( $self->CurrentUser );
        $OCF->Create(
            CustomField => $self->Id,
            ObjectId => $args{'Queue'},
        );
    }

    return ($rv, $msg);
}

=head2 Load ID/NAME

Load a custom field.  If the value handed in is an integer, load by custom field ID. Otherwise, Load by name.

=cut

sub Load {
    my $self = shift;
    my $id = shift || '';

    if ( $id =~ /^\d+$/ ) {
        return $self->SUPER::Load( $id );
    } else {
        return $self->LoadByName( Name => $id );
    }
}



=head2 LoadByName (Queue => QUEUEID, Name => NAME)

Loads the Custom field named NAME.

Will load a Disabled Custom Field even if there is a non-disabled Custom Field
with the same Name.

If a Queue parameter is specified, only look for ticket custom fields tied to that Queue.

If the Queue parameter is '0', look for global ticket custom fields.

If no queue parameter is specified, look for any and all custom fields with this name.

BUG/TODO, this won't let you specify that you only want user or group CFs.

=cut

# Compatibility for API change after 3.0 beta 1
*LoadNameAndQueue = \&LoadByName;
# Change after 3.4 beta.
*LoadByNameAndQueue = \&LoadByName;

sub LoadByName {
    my $self = shift;
    my %args = (
        Queue => undef,
        Name  => undef,
        @_,
    );

    unless ( defined $args{'Name'} && length $args{'Name'} ) {
        $RT::Logger->error("Couldn't load Custom Field without Name");
        return wantarray ? (0, $self->loc("No name provided")) : 0;
    }

    # if we're looking for a queue by name, make it a number
    if ( defined $args{'Queue'} && ($args{'Queue'} =~ /\D/ || !$self->ContextObject) ) {
        my $QueueObj = RT::Queue->new( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} );
        $args{'Queue'} = $QueueObj->Id;
        $self->SetContextObject( $QueueObj )
            unless $self->ContextObject;
    }

    # XXX - really naive implementation.  Slow. - not really. still just one query

    my $CFs = RT::CustomFields->new( $self->CurrentUser );
    $CFs->SetContextObject( $self->ContextObject );
    my $field = $args{'Name'} =~ /\D/? 'Name' : 'id';
    $CFs->Limit( FIELD => $field, VALUE => $args{'Name'}, CASESENSITIVE => 0);
    # Don't limit to queue if queue is 0.  Trying to do so breaks
    # RT::Group type CFs.
    if ( defined $args{'Queue'} ) {
        $CFs->LimitToQueue( $args{'Queue'} );
    }

    # When loading by name, we _can_ load disabled fields, but prefer
    # non-disabled fields.
    $CFs->FindAllRows;
    $CFs->OrderByCols(
        { FIELD => "Disabled", ORDER => 'ASC' },
    );

    # We only want one entry.
    $CFs->RowsPerPage(1);

    # version before 3.8 just returns 0, so we need to test if wantarray to be
    # backward compatible.
    return wantarray ? (0, $self->loc("Not found")) : 0 unless my $first = $CFs->First;

    return $self->LoadById( $first->id );
}




=head2 Custom field values

=head3 Values FIELD

Return a object (collection) of all acceptable values for this Custom Field.
Class of the object can vary and depends on the return value
of the C<ValuesClass> method.

=cut

*ValuesObj = \&Values;

sub Values {
    my $self = shift;

    my $class = $self->ValuesClass;
    if ( $class ne 'RT::CustomFieldValues') {
        eval "require $class" or die "$@";
    }
    my $cf_values = $class->new( $self->CurrentUser );
    # if the user has no rights, return an empty object
    if ( $self->id && $self->CurrentUserHasRight( 'SeeCustomField') ) {
        $cf_values->LimitToCustomField( $self->Id );
    } else {
        $cf_values->Limit( FIELD => 'id', VALUE => 0, SUBCLAUSE => 'acl' );
    }
    return ($cf_values);
}


=head3 AddValue HASH

Create a new value for this CustomField.  Takes a paramhash containing the elements Name, Description and SortOrder

=cut

sub AddValue {
    my $self = shift;
    my %args = @_;

    unless ($self->CurrentUserHasRight('AdminCustomField') || $self->CurrentUserHasRight('AdminCustomFieldValues')) {
        return (0, $self->loc('Permission Denied'));
    }

    # allow zero value
    if ( !defined $args{'Name'} || $args{'Name'} eq '' ) {
        return (0, $self->loc("Can't add a custom field value without a name"));
    }

    my $newval = RT::CustomFieldValue->new( $self->CurrentUser );
    return $newval->Create( %args, CustomField => $self->Id );
}




=head3 DeleteValue ID

Deletes a value from this custom field by id.

Does not remove this value for any article which has had it selected

=cut

sub DeleteValue {
    my $self = shift;
    my $id = shift;
    unless ( $self->CurrentUserHasRight('AdminCustomField') || $self->CurrentUserHasRight('AdminCustomFieldValues') ) {
        return (0, $self->loc('Permission Denied'));
    }

    my $val_to_del = RT::CustomFieldValue->new( $self->CurrentUser );
    $val_to_del->Load( $id );
    unless ( $val_to_del->Id ) {
        return (0, $self->loc("Couldn't find that value"));
    }
    unless ( $val_to_del->CustomField == $self->Id ) {
        return (0, $self->loc("That is not a value for this custom field"));
    }

    my $retval = $val_to_del->Delete;
    unless ( $retval ) {
        return (0, $self->loc("Custom field value could not be deleted"));
    }
    return ($retval, $self->loc("Custom field value deleted"));
}


=head2 ValidateQueue Queue

Make sure that the name specified is valid

=cut

sub ValidateName {
    my $self = shift;
    my $value = shift;

    return 0 unless length $value;

    return $self->SUPER::ValidateName($value);
}

=head2 ValidateQueue Queue

Make sure that the queue specified is a valid queue name

=cut

sub ValidateQueue {
    my $self = shift;
    my $id = shift;

    return undef unless defined $id;
    # 0 means "Global" null would _not_ be ok.
    return 1 if $id eq '0';

    my $q = RT::Queue->new( RT->SystemUser );
    $q->Load( $id );
    return undef unless $q->id;
    return 1;
}



=head2 Types 

Retuns an array of the types of CustomField that are supported

=cut

sub Types {
    return (sort {(($FieldTypes{$a}{sort_order}||999) <=> ($FieldTypes{$b}{sort_order}||999)) or ($a cmp $b)} keys %FieldTypes);
}


=head2 IsSelectionType 

Retuns a boolean value indicating whether the C<Values> method makes sense
to this Custom Field.

=cut

sub IsSelectionType {
    my $self = shift;
    my $type = @_? shift : $self->Type;
    return undef unless $type;
    return $FieldTypes{$type}->{selection_type};
}



=head2 IsExternalValues

=cut

sub IsExternalValues {
    my $self = shift;
    return 0 unless $self->IsSelectionType( @_ );
    return $self->ValuesClass eq 'RT::CustomFieldValues'? 0 : 1;
}

sub ValuesClass {
    my $self = shift;
    return $self->_Value( ValuesClass => @_ ) || 'RT::CustomFieldValues';
}

sub SetValuesClass {
    my $self = shift;
    my $class = shift || 'RT::CustomFieldValues';
    
    if ( $class eq 'RT::CustomFieldValues' ) {
        return $self->_Set( Field => 'ValuesClass', Value => undef, @_ );
    }

    return (0, $self->loc("This Custom Field can not have list of values"))
        unless $self->IsSelectionType;

    unless ( $self->ValidateValuesClass( $class ) ) {
        return (0, $self->loc("Invalid Custom Field values source"));
    }
    return $self->_Set( Field => 'ValuesClass', Value => $class, @_ );
}

sub ValidateValuesClass {
    my $self = shift;
    my $class = shift;

    return 1 if !$class || $class eq 'RT::CustomFieldValues';
    return 1 if grep $class eq $_, RT->Config->Get('CustomFieldValuesSources');
    return undef;
}


=head2 FriendlyType [TYPE, MAX_VALUES]

Returns a localized human-readable version of the custom field type.
If a custom field type is specified as the parameter, the friendly type for that type will be returned

=cut

sub FriendlyType {
    my $self = shift;

    my $type = @_ ? shift : $self->Type;
    my $max  = @_ ? shift : $self->MaxValues;
    $max = 0 unless $max;

    if (my $friendly_type = $FieldTypes{$type}->{labels}->[$max>2 ? 2 : $max]) {
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


=cut

sub ValidateType {
    my $self = shift;
    my $type = shift;

    if ( $type =~ s/(?:Single|Multiple)$// ) {
        RT->Deprecated(
            Arguments => "suffix 'Single' or 'Multiple'",
            Instead   => "MaxValues",
            Remove    => "4.4",
        );
    }

    if ( $FieldTypes{$type} ) {
        return 1;
    }
    else {
        return undef;
    }
}


sub SetType {
    my $self = shift;
    my $type = shift;
    if ($type =~ s/(?:(Single)|Multiple)$//) {
        RT->Deprecated(
            Arguments => "suffix 'Single' or 'Multiple'",
            Instead   => "MaxValues",
            Remove    => "4.4",
        );
        $self->SetMaxValues($1 ? 1 : 0);
    }
    $self->_Set(Field => 'Type', Value =>$type);
}

=head2 SetPattern STRING

Takes a single string representing a regular expression.  Performs basic
validation on that regex, and sets the C<Pattern> field for the CF if it
is valid.

=cut

sub SetPattern {
    my $self = shift;
    my $regex = shift;

    my ($ok, $msg) = $self->_IsValidRegex($regex);
    if ($ok) {
        return $self->_Set(Field => 'Pattern', Value => $regex);
    }
    else {
        return (0, $self->loc("Invalid pattern: [_1]", $msg));
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


=head2 SingleValue

Returns true if this CustomField only accepts a single value. 
Returns false if it accepts multiple values

=cut

sub SingleValue {
    my $self = shift;
    if (($self->MaxValues||0) == 1) {
        return 1;
    } 
    else {
        return undef;
    }
}

sub UnlimitedValues {
    my $self = shift;
    if (($self->MaxValues||0) == 0) {
        return 1;
    } 
    else {
        return undef;
    }
}


=head2 ACLEquivalenceObjects

Returns list of objects via which users can get rights on this custom field. For custom fields
these objects can be set using L<ContextObject|/"ContextObject and SetContextObject">.

=cut

sub ACLEquivalenceObjects {
    my $self = shift;

    my $ctx = $self->ContextObject
        or return;
    return ($ctx, $ctx->ACLEquivalenceObjects);
}

=head2 ContextObject and SetContextObject

Set or get a context for this object. It can be ticket, queue or another
object this CF added to. Used for ACL control, for example
SeeCustomField can be granted on queue level to allow people to see all
fields added to the queue.

=cut

sub SetContextObject {
    my $self = shift;
    return $self->{'context_object'} = shift;
}
  
sub ContextObject {
    my $self = shift;
    return $self->{'context_object'};
}

sub ValidContextType {
    my $self = shift;
    my $class = shift;

    my %valid;
    $valid{$_}++ for split '-', $self->LookupType;
    delete $valid{'RT::Transaction'};

    return $valid{$class};
}

=head2 LoadContextObject

Takes an Id for a Context Object and loads the right kind of RT::Object
for this particular Custom Field (based on the LookupType) and returns it.
This is a good way to ensure you don't try to use a Queue as a Context
Object on a User Custom Field.

=cut

sub LoadContextObject {
    my $self = shift;
    my $type = shift;
    my $contextid = shift;

    unless ( $self->ValidContextType($type) ) {
        RT->Logger->debug("Invalid ContextType $type for Custom Field ".$self->Id);
        return;
    }

    my $context_object = $type->new( $self->CurrentUser );
    my ($id, $msg) = $context_object->LoadById( $contextid );
    unless ( $id ) {
        RT->Logger->debug("Invalid ContextObject id: $msg");
        return;
    }
    return $context_object;
}

=head2 ValidateContextObject

Ensure that a given ContextObject applies to this Custom Field.  For
custom fields that are assigned to Queues or to Classes, this checks
that the Custom Field is actually added to that object.  For Global
Custom Fields, it returns true as long as the Object is of the right
type, because you may be using your permissions on a given Queue of
Class to see a Global CF.  For CFs that are only added globally, you
don't need a ContextObject.

=cut

sub ValidateContextObject {
    my $self = shift;
    my $object = shift;

    return 1 if $self->IsGlobal;

    # global only custom fields don't have objects
    # that should be used as context objects.
    return if $self->IsOnlyGlobal;

    # Otherwise, make sure we weren't passed a user object that we're
    # supposed to treat as a queue.
    return unless $self->ValidContextType(ref $object);

    # Check that it is added correctly
    my ($added_to) = grep {ref($_) eq $self->RecordClassFromLookupType} ($object, $object->ACLEquivalenceObjects);
    return unless $added_to;
    return $self->IsAdded($added_to->id);
}


sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminCustomField') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return $self->SUPER::_Set( @_ );

}



=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {
    my $self  = shift;
    return undef unless $self->id;

    # we need to do the rights check
    unless ( $self->CurrentUserHasRight('SeeCustomField') ) {
        $RT::Logger->debug(
            "Permission denied. User #". $self->CurrentUser->id
            ." has no SeeCustomField right on CF #". $self->id
        );
        return (undef);
    }
    return $self->__Value( @_ );
}


=head2 SetDisabled

Takes a boolean.
1 will cause this custom field to no longer be avaialble for objects.
0 will re-enable this field.

=cut


=head2 SetTypeComposite

Set this custom field's type and maximum values as a composite value

=cut

sub SetTypeComposite {
    my $self = shift;
    my $composite = shift;

    my $old = $self->TypeComposite;

    my ($type, $max_values) = split(/-/, $composite, 2);
    if ( $type ne $self->Type ) {
        my ($status, $msg) = $self->SetType( $type );
        return ($status, $msg) unless $status;
    }
    if ( ($max_values || 0) != ($self->MaxValues || 0) ) {
        my ($status, $msg) = $self->SetMaxValues( $max_values );
        return ($status, $msg) unless $status;
    }
    my $render = $self->RenderType;
    if ( $render and not grep { $_ eq $render } $self->RenderTypes ) {
        # We switched types and our render type is no longer valid, so unset it
        # and use the default
        $self->SetRenderType( undef );
    }
    return 1, $self->loc(
        "Type changed from '[_1]' to '[_2]'",
        $self->FriendlyTypeComposite( $old ),
        $self->FriendlyTypeComposite( $composite ),
    );
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
    return grep !/(?:[Tt]ext|Combobox|Date|DateTime)-0/, map { ("$_-1", "$_-0") } $self->Types;
}

=head2 RenderType

Returns the type of form widget to render for this custom field.  Currently
this only affects fields which return true for L</HasRenderTypes>. 

=cut

sub RenderType {
    my $self = shift;
    return '' unless $self->HasRenderTypes;

    return $self->_Value( 'RenderType', @_ )
        || $self->DefaultRenderType;
}

=head2 SetRenderType TYPE

Sets this custom field's render type.

=cut

sub SetRenderType {
    my $self = shift;
    my $type = shift;
    return (0, $self->loc("This custom field has no Render Types"))
        unless $self->HasRenderTypes;

    if ( !$type || $type eq $self->DefaultRenderType ) {
        return $self->_Set( Field => 'RenderType', Value => undef, @_ );
    }

    if ( not grep { $_ eq $type } $self->RenderTypes ) {
        return (0, $self->loc("Invalid Render Type for custom field of type [_1]",
                                $self->FriendlyType));
    }

    # XXX: Remove this restriction once we support lists and cascaded selects
    if ( $self->BasedOnObj->id and $type =~ /List/ ) {
        return (0, $self->loc("We can't currently render as a List when basing categories on another custom field.  Please use another render type."));
    }

    return $self->_Set( Field => 'RenderType', Value => $type, @_ );
}

=head2 DefaultRenderType [TYPE COMPOSITE]

Returns the default render type for this custom field's type or the TYPE
COMPOSITE specified as an argument.

=cut

sub DefaultRenderType {
    my $self = shift;
    my $composite    = @_ ? shift : $self->TypeComposite;
    my ($type, $max) = split /-/, $composite, 2;
    return unless $type and $self->HasRenderTypes($composite);
    return $FieldTypes{$type}->{render_types}->{ $max == 1 ? 'single' : 'multiple' }[0];
}

=head2 HasRenderTypes [TYPE_COMPOSITE]

Returns a boolean value indicating whether the L</RenderTypes> and
L</RenderType> methods make sense for this custom field.

Currently true only for type C<Select>.

=cut

sub HasRenderTypes {
    my $self = shift;
    my ($type, $max) = split /-/, (@_ ? shift : $self->TypeComposite), 2;
    return undef unless $type;
    return defined $FieldTypes{$type}->{render_types}
        ->{ $max == 1 ? 'single' : 'multiple' };
}

=head2 RenderTypes [TYPE COMPOSITE]

Returns the valid render types for this custom field's type or the TYPE
COMPOSITE specified as an argument.

=cut

sub RenderTypes {
    my $self = shift;
    my $composite    = @_ ? shift : $self->TypeComposite;
    my ($type, $max) = split /-/, $composite, 2;
    return unless $type and $self->HasRenderTypes($composite);
    return @{$FieldTypes{$type}->{render_types}->{ $max == 1 ? 'single' : 'multiple' }};
}

=head2 SetLookupType

Autrijus: care to doc how LookupTypes work?

=cut

sub SetLookupType {
    my $self = shift;
    my $lookup = shift;
    if ( $lookup ne $self->LookupType ) {
        # Okay... We need to invalidate our existing relationships
        RT::ObjectCustomField->new($self->CurrentUser)->DeleteAll( CustomField => $self );
    }
    return $self->_Set(Field => 'LookupType', Value =>$lookup);
}

=head2 LookupTypes

Returns an array of LookupTypes available

=cut


sub LookupTypes {
    my $self = shift;
    return keys %FRIENDLY_OBJECT_TYPES;
}

my @FriendlyObjectTypes = (
    "[_1] objects",            # loc
    "[_1]'s [_2] objects",        # loc
    "[_1]'s [_2]'s [_3] objects",   # loc
);

=head2 FriendlyLookupType

Returns a localized description of the type of this custom field

=cut

sub FriendlyLookupType {
    my $self = shift;
    my $lookup = shift || $self->LookupType;
   
    return ($self->loc( $FRIENDLY_OBJECT_TYPES{$lookup} ))
                     if (defined  $FRIENDLY_OBJECT_TYPES{$lookup} );

    my @types = map { s/^RT::// ? $self->loc($_) : $_ }
      grep { defined and length }
      split( /-/, $lookup )
      or return;
    return ( $self->loc( $FriendlyObjectTypes[$#types], @types ) );
}

sub RecordClassFromLookupType {
    my $self = shift;
    my ($class) = ($self->LookupType =~ /^([^-]+)/);
    unless ( $class ) {
        $RT::Logger->error(
            "Custom Field #". $self->id 
            ." has incorrect LookupType '". $self->LookupType ."'"
        );
        return undef;
    }
    return $class;
}

sub CollectionClassFromLookupType {
    my $self = shift;

    my $record_class = $self->RecordClassFromLookupType;
    return undef unless $record_class;

    my $collection_class;
    if ( UNIVERSAL::can($record_class.'Collection', 'new') ) {
        $collection_class = $record_class.'Collection';
    } elsif ( UNIVERSAL::can($record_class.'es', 'new') ) {
        $collection_class = $record_class.'es';
    } elsif ( UNIVERSAL::can($record_class.'s', 'new') ) {
        $collection_class = $record_class.'s';
    } else {
        $RT::Logger->error("Can not find a collection class for record class '$record_class'");
        return undef;
    }
    return $collection_class;
}

=head2 Groupings

Returns a (sorted and lowercased) list of the groupings in which this custom
field appears.

If called on a loaded object, the returned list is limited to groupings which
apply to the record class this CF applies to (L</RecordClassFromLookupType>).

If passed a loaded object or a class name, the returned list is limited to
groupings which apply to the class of the object or the specified class.

If called on an unloaded object, all potential groupings are returned.

=cut

sub Groupings {
    my $self = shift;
    my $record_class = $self->_GroupingClass(shift);

    my $config = RT->Config->Get('CustomFieldGroupings');
       $config = {} unless ref($config) eq 'HASH';

    my @groups;
    if ( $record_class ) {
        push @groups, sort {lc($a) cmp lc($b)} keys %{ $BUILTIN_GROUPINGS{$record_class} || {} };
        if ( ref($config->{$record_class} ||= []) eq "ARRAY") {
            my @order = @{ $config->{$record_class} };
            while (@order) {
                push @groups, shift(@order);
                shift(@order);
            }
        } else {
            @groups = sort {lc($a) cmp lc($b)} keys %{ $config->{$record_class} };
        }
    } else {
        my %all = (%$config, %BUILTIN_GROUPINGS);
        @groups = sort {lc($a) cmp lc($b)} map {$self->Groupings($_)} grep {$_} keys(%all);
    }

    my %seen;
    return
        grep defined && length && !$seen{lc $_}++,
        @groups;
}

=head2 CustomGroupings

Identical to L</Groupings> but filters out built-in groupings from the the
returned list.

=cut

sub CustomGroupings {
    my $self = shift;
    my $record_class = $self->_GroupingClass(shift);
    return grep !$BUILTIN_GROUPINGS{$record_class}{$_}, $self->Groupings( $record_class );
}

sub _GroupingClass {
    my $self    = shift;
    my $record  = shift;

    my $record_class = ref($record) || $record || '';
    $record_class = $self->RecordClassFromLookupType
        if !$record_class and blessed($self) and $self->id;

    return $record_class;
}

=head2 RegisterBuiltInGroupings

Registers groupings to be considered a fundamental part of RT, either via use
in core RT or via an extension.  These groupings must be rendered explicitly in
Mason by specific calls to F</Elements/ShowCustomFields> and
F</Elements/EditCustomFields>.  They will not show up automatically on normal
display pages like configured custom groupings.

Takes a set of key-value pairs of class names (valid L<RT::Record> subclasses)
and array refs of grouping names to consider built-in.

If a class already contains built-in groupings (such as L<RT::Ticket> and
L<RT::User>), new groupings are appended.

=cut

sub RegisterBuiltInGroupings {
    my $self = shift;
    my %new  = @_;

    while (my ($k,$v) = each %new) {
        $v = [$v] unless ref($v) eq 'ARRAY';
        $BUILTIN_GROUPINGS{$k} = {
            %{$BUILTIN_GROUPINGS{$k} || {}},
            map { $_ => 1 } @$v
        };
    }
    $BUILTIN_GROUPINGS{''} = { map { %$_ } values %BUILTIN_GROUPINGS  };
}

=head1 IsOnlyGlobal

Certain custom fields (users, groups) should only be added globally;
codify that set here for reference.

=cut

sub IsOnlyGlobal {
    my $self = shift;

    return ($self->LookupType =~ /^RT::(?:Group|User)/io);

}
sub ApplyGlobally {
    RT->Deprecated(
        Instead   => "IsOnlyGlobal",
        Remove    => "4.4",
    );
    return shift->IsOnlyGlobal(@_);
}

=head1 AddedTo

Returns collection with objects this custom field is added to.
Class of the collection depends on L</LookupType>.
See all L</NotAddedTo> .

Doesn't takes into account if object is added globally.

=cut

sub AddedTo {
    my $self = shift;
    return RT::ObjectCustomField->new( $self->CurrentUser )
        ->AddedTo( CustomField => $self );
}
sub AppliedTo {
    RT->Deprecated(
        Instead   => "AddedTo",
        Remove    => "4.4",
    );
    shift->AddedTo(@_);
};

=head1 NotAddedTo

Returns collection with objects this custom field is not added to.
Class of the collection depends on L</LookupType>.
See all L</AddedTo> .

Doesn't take into account if the object is added globally.

=cut

sub NotAddedTo {
    my $self = shift;
    return RT::ObjectCustomField->new( $self->CurrentUser )
        ->NotAddedTo( CustomField => $self );
}
sub NotAppliedTo {
    RT->Deprecated(
        Instead   => "NotAddedTo",
        Remove    => "4.4",
    );
    shift->NotAddedTo(@_)
};

=head2 IsAdded

Takes object id and returns corresponding L<RT::ObjectCustomField>
record if this custom field is added to the object. Use 0 to check
if custom field is added globally.

=cut

sub IsAdded {
    my $self = shift;
    my $id = shift;
    my $ocf = RT::ObjectCustomField->new( $self->CurrentUser );
    $ocf->LoadByCols( CustomField => $self->id, ObjectId => $id || 0 );
    return undef unless $ocf->id;
    return $ocf;
}
sub IsApplied {
    RT->Deprecated(
        Instead   => "IsAdded",
        Remove    => "4.4",
    );
    shift->IsAdded(@_);
};

sub IsGlobal { return shift->IsAdded(0) }

=head2 IsAddedToAny

Returns true if custom field is applied to any object.

=cut

sub IsAddedToAny {
    my $self = shift;
    my $id = shift;
    my $ocf = RT::ObjectCustomField->new( $self->CurrentUser );
    $ocf->LoadByCols( CustomField => $self->id );
    return $ocf->id ? 1 : 0;
}

=head2 AddToObject OBJECT

Add this custom field as a custom field for a single object, such as a queue or group.

Takes an object 

=cut

sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
        return ( 0, $self->loc('Lookup type mismatch') );
    }

    unless ( $object->CurrentUserHasRight('AssignCustomFields') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ocf = RT::ObjectCustomField->new( $self->CurrentUser );
    my ( $oid, $msg ) = $ocf->Add(
        CustomField => $self->id, ObjectId => $id,
    );
    return ( $oid, $msg );
}


=head2 RemoveFromObject OBJECT

Remove this custom field  for a single object, such as a queue or group.

Takes an object 

=cut

sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless (index($self->LookupType, ref($object)) == 0) {
        return ( 0, $self->loc('Object type mismatch') );
    }

    unless ( $object->CurrentUserHasRight('AssignCustomFields') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ocf = $self->IsAdded( $id );
    unless ( $ocf ) {
        return ( 0, $self->loc("This custom field cannot be added to that object") );
    }

    # XXX: Delete doesn't return anything
    my ( $oid, $msg ) = $ocf->Delete;
    return ( $oid, $msg );
}


=head2 AddValueForObject HASH

Adds a custom field value for a record object of some kind. 
Takes a param hash of 

Required:

    Object
    Content

Optional:

    LargeContent
    ContentType

=cut

sub AddValueForObject {
    my $self = shift;
    my %args = (
        Object       => undef,
        Content      => undef,
        LargeContent => undef,
        ContentType  => undef,
        @_
    );
    my $obj = $args{'Object'} or return ( 0, $self->loc('Invalid object') );

    unless ( $self->CurrentUserHasRight('ModifyCustomField') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    unless ( $self->MatchPattern($args{'Content'}) ) {
        return ( 0, $self->loc('Input must match [_1]', $self->FriendlyPattern) );
    }

    $RT::Handle->BeginTransaction;

    if ( $self->MaxValues ) {
        my $current_values = $self->ValuesForObject($obj);
        my $extra_values = ( $current_values->Count + 1 ) - $self->MaxValues;

        # (The +1 is for the new value we're adding)

        # If we have a set of current values and we've gone over the maximum
        # allowed number of values, we'll need to delete some to make room.
        # which former values are blown away is not guaranteed

        while ($extra_values) {
            my $extra_item = $current_values->Next;
            unless ( $extra_item->id ) {
                $RT::Logger->crit( "We were just asked to delete "
                    ."a custom field value that doesn't exist!" );
                $RT::Handle->Rollback();
                return (undef);
            }
            $extra_item->Delete;
            $extra_values--;
        }
    }

    if (my $canonicalizer = $self->can('_CanonicalizeValue'.$self->Type)) {
         $canonicalizer->($self, \%args);
    }



    my $newval = RT::ObjectCustomFieldValue->new( $self->CurrentUser );
    my ($val, $msg) = $newval->Create(
        ObjectType   => ref($obj),
        ObjectId     => $obj->Id,
        Content      => $args{'Content'},
        LargeContent => $args{'LargeContent'},
        ContentType  => $args{'ContentType'},
        CustomField  => $self->Id
    );

    unless ($val) {
        $RT::Handle->Rollback();
        return ($val, $self->loc("Couldn't create record: [_1]", $msg));
    }

    $RT::Handle->Commit();
    return ($val);

}



sub _CanonicalizeValueDateTime {
    my $self    = shift;
    my $args    = shift;
    my $DateObj = RT::Date->new( $self->CurrentUser );
    $DateObj->Set( Format => 'unknown',
                   Value  => $args->{'Content'} );
    $args->{'Content'} = $DateObj->ISO;
}

# For date, we need to store Content as ISO date
sub _CanonicalizeValueDate {
    my $self = shift;
    my $args = shift;

    # in case user input date with time, let's omit it by setting timezone
    # to utc so "hour" won't affect "day"
    my $DateObj = RT::Date->new( $self->CurrentUser );
    $DateObj->Set( Format   => 'unknown',
                   Value    => $args->{'Content'},
                 );
    $args->{'Content'} = $DateObj->Date( Timezone => 'user' );
}

=head2 MatchPattern STRING

Tests the incoming string against the Pattern of this custom field object
and returns a boolean; returns true if the Pattern is empty.

=cut

sub MatchPattern {
    my $self = shift;
    my $regex = $self->Pattern or return 1;

    return (( defined $_[0] ? $_[0] : '') =~ $regex);
}




=head2 FriendlyPattern

Prettify the pattern of this custom field, by taking the text in C<(?#text)>
and localizing it.

=cut

sub FriendlyPattern {
    my $self = shift;
    my $regex = $self->Pattern;

    return '' unless length $regex;
    if ( $regex =~ /\(\?#([^)]*)\)/ ) {
        return '[' . $self->loc($1) . ']';
    }
    else {
        return $regex;
    }
}




=head2 DeleteValueForObject HASH

Deletes a custom field value for a ticket. Takes a param hash of Object and Content

Returns a tuple of (STATUS, MESSAGE). If the call succeeded, the STATUS is true. otherwise it's false

=cut

sub DeleteValueForObject {
    my $self = shift;
    my %args = ( Object => undef,
                 Content => undef,
                 Id => undef,
             @_ );


    unless ($self->CurrentUserHasRight('ModifyCustomField')) {
        return (0, $self->loc('Permission Denied'));
    }

    my $oldval = RT::ObjectCustomFieldValue->new($self->CurrentUser);

    if (my $id = $args{'Id'}) {
        $oldval->Load($id);
    }
    unless ($oldval->id) { 
        $oldval->LoadByObjectContentAndCustomField(
            Object => $args{'Object'}, 
            Content =>  $args{'Content'}, 
            CustomField => $self->Id,
        );
    }


    # check to make sure we found it
    unless ($oldval->Id) {
        return(0, $self->loc("Custom field value [_1] could not be found for custom field [_2]", $args{'Content'}, $self->Name));
    }

    # for single-value fields, we need to validate that empty string is a valid value for it
    if ( $self->SingleValue and not $self->MatchPattern( '' ) ) {
        return ( 0, $self->loc('Input must match [_1]', $self->FriendlyPattern) );
    }

    # delete it

    my $ret = $oldval->Delete();
    unless ($ret) {
        return(0, $self->loc("Custom field value could not be found"));
    }
    return($oldval->Id, $self->loc("Custom field value deleted"));
}


=head2 ValuesForObject OBJECT

Return an L<RT::ObjectCustomFieldValues> object containing all of this custom field's values for OBJECT 

=cut

sub ValuesForObject {
    my $self = shift;
    my $object = shift;

    my $values = RT::ObjectCustomFieldValues->new($self->CurrentUser);
    unless ($self->id and $self->CurrentUserHasRight('SeeCustomField')) {
        # Return an empty object if they have no rights to see
        $values->Limit( FIELD => "id", VALUE => 0, SUBCLAUSE => "ACL" );
        return ($values);
    }

    $values->LimitToCustomField($self->Id);
    $values->LimitToObject($object);

    return ($values);
}


=head2 _ForObjectType PATH FRIENDLYNAME

Tell RT that a certain object accepts custom fields

Examples:

    'RT::Queue-RT::Ticket'                 => "Tickets",                # loc
    'RT::Queue-RT::Ticket-RT::Transaction' => "Ticket Transactions",    # loc
    'RT::User'                             => "Users",                  # loc
    'RT::Group'                            => "Groups",                 # loc
    'RT::Queue'                            => "Queues",                 # loc

This is a class method. 

=cut

sub _ForObjectType {
    my $self = shift;
    my $path = shift;
    my $friendly_name = shift;

    $FRIENDLY_OBJECT_TYPES{$path} = $friendly_name;

}


=head2 IncludeContentForValue [VALUE] (and SetIncludeContentForValue)

Gets or sets the  C<IncludeContentForValue> for this custom field. RT
uses this field to automatically include content into the user's browser
as they display records with custom fields in RT.

=cut

sub SetIncludeContentForValue {
    shift->IncludeContentForValue(@_);
}
sub IncludeContentForValue{
    my $self = shift;
    $self->_URLTemplate('IncludeContentForValue', @_);
}



=head2 LinkValueTo [VALUE] (and SetLinkValueTo)

Gets or sets the  C<LinkValueTo> for this custom field. RT
uses this field to make custom field values into hyperlinks in the user's
browser as they display records with custom fields in RT.

=cut


sub SetLinkValueTo {
    shift->LinkValueTo(@_);
}

sub LinkValueTo {
    my $self = shift;
    $self->_URLTemplate('LinkValueTo', @_);

}


=head2 _URLTemplate  NAME [VALUE]

With one argument, returns the _URLTemplate named C<NAME>, but only if
the current user has the right to see this custom field.

With two arguments, attemptes to set the relevant template value.

=cut

sub _URLTemplate {
    my $self          = shift;
    my $template_name = shift;
    if (@_) {

        my $value = shift;
        unless ( $self->CurrentUserHasRight('AdminCustomField') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $self->SetAttribute( Name => $template_name, Content => $value );
        return ( 1, $self->loc('Updated') );
    } else {
        unless ( $self->id && $self->CurrentUserHasRight('SeeCustomField') ) {
            return (undef);
        }

        my @attr = $self->Attributes->Named($template_name);
        my $attr = shift @attr;

        if ($attr) { return $attr->Content }

    }
}

sub SetBasedOn {
    my $self = shift;
    my $value = shift;

    return $self->_Set( Field => 'BasedOn', Value => $value, @_ )
        unless defined $value and length $value;

    my $cf = RT::CustomField->new( $self->CurrentUser );
    $cf->SetContextObject( $self->ContextObject );
    $cf->Load( ref $value ? $value->id : $value );

    return (0, "Permission Denied")
        unless $cf->id && $cf->CurrentUserHasRight('SeeCustomField');

    # XXX: Remove this restriction once we support lists and cascaded selects
    if ( $self->RenderType =~ /List/ ) {
        return (0, $self->loc("We can't currently render as a List when basing categories on another custom field.  Please use another render type."));
    }

    return $self->_Set( Field => 'BasedOn', Value => $value, @_ )
}

sub BasedOnObj {
    my $self = shift;

    my $obj = RT::CustomField->new( $self->CurrentUser );
    $obj->SetContextObject( $self->ContextObject );
    if ( $self->BasedOn ) {
        $obj->Load( $self->BasedOn );
    }
    return $obj;
}






=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


=cut


=head2 Type

Returns the current value of Type. 
(In the database, Type is stored as varchar(200).)



=head2 SetType VALUE


Set Type to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Type will be stored as a varchar(200).)


=cut


=head2 RenderType

Returns the current value of RenderType. 
(In the database, RenderType is stored as varchar(64).)



=head2 SetRenderType VALUE


Set RenderType to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, RenderType will be stored as a varchar(64).)


=cut


=head2 MaxValues

Returns the current value of MaxValues. 
(In the database, MaxValues is stored as int(11).)



=head2 SetMaxValues VALUE


Set MaxValues to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MaxValues will be stored as a int(11).)


=cut


=head2 Pattern

Returns the current value of Pattern. 
(In the database, Pattern is stored as text.)



=head2 SetPattern VALUE


Set Pattern to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Pattern will be stored as a text.)


=cut


=head2 BasedOn

Returns the current value of BasedOn. 
(In the database, BasedOn is stored as int(11).)



=head2 SetBasedOn VALUE


Set BasedOn to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, BasedOn will be stored as a int(11).)


=cut


=head2 Description

Returns the current value of Description. 
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 SortOrder

Returns the current value of SortOrder. 
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 LookupType

Returns the current value of LookupType. 
(In the database, LookupType is stored as varchar(255).)



=head2 SetLookupType VALUE


Set LookupType to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, LookupType will be stored as a varchar(255).)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy. 
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated. 
(In the database, LastUpdated is stored as datetime.)


=cut


=head2 Disabled

Returns the current value of Disabled. 
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {
     
        id =>
        {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Type => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        RenderType => 
        {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        MaxValues => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Pattern => 
        {read => 1, write => 1, sql_type => -4, length => 0,  is_blob => 1,  is_numeric => 0,  type => 'text', default => ''},
        ValuesClass => 
        {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
        BasedOn => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Description => 
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        SortOrder => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LookupType => 
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        Creator => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy => 
        {read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated => 
        {read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        Disabled => 
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};


RT::Base->_ImportOverlays();

1;
