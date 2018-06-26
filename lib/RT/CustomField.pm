# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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
use 5.010;

use Scalar::Util 'blessed';

use base 'RT::Record';

use Role::Basic 'with';
with "RT::Record::Role::Rights";

sub Table {'CustomFields'}

use Scalar::Util qw(blessed);
use RT::CustomFieldValues;
use RT::ObjectCustomFields;
use RT::ObjectCustomFieldValues;

our %FieldTypes = (
    Select => {
        sort_order => 10,
        selection_type => 1,
        canonicalizes => 0,

        labels => [ 'Select multiple values',               # loc
                    'Select one value',                     # loc
                    'Select up to [quant,_1,value,values]', # loc
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
        canonicalizes => 1,

        labels => [ 'Enter multiple values',               # loc
                    'Enter one value',                     # loc
                    'Enter up to [quant,_1,value,values]', # loc
                  ]
                },
    Text => {
        sort_order => 30,
        selection_type => 0,
        canonicalizes => 1,
        labels         => [
                    'Fill in multiple text areas',                   # loc
                    'Fill in one text area',                         # loc
                    'Fill in up to [quant,_1,text area,text areas]', # loc
                  ]
            },
    Wikitext => {
        sort_order => 40,
        selection_type => 0,
        canonicalizes => 1,
        labels         => [
                    'Fill in multiple wikitext areas',                       # loc
                    'Fill in one wikitext area',                             # loc
                    'Fill in up to [quant,_1,wikitext area,wikitext areas]', # loc
                  ]
                },

    Image => {
        sort_order => 50,
        selection_type => 0,
        canonicalizes => 0,
        labels         => [
                    'Upload multiple images',               # loc
                    'Upload one image',                     # loc
                    'Upload up to [quant,_1,image,images]', # loc
                  ]
             },
    Binary => {
        sort_order => 60,
        selection_type => 0,
        canonicalizes => 0,
        labels         => [
                    'Upload multiple files',              # loc
                    'Upload one file',                    # loc
                    'Upload up to [quant,_1,file,files]', # loc
                  ]
              },

    Combobox => {
        sort_order => 70,
        selection_type => 1,
        canonicalizes => 1,
        labels         => [
                    'Combobox: Select or enter multiple values',               # loc
                    'Combobox: Select or enter one value',                     # loc
                    'Combobox: Select or enter up to [quant,_1,value,values]', # loc
                  ]
                },
    Autocomplete => {
        sort_order => 80,
        selection_type => 1,
        canonicalizes => 1,
        labels         => [
                    'Enter multiple values with autocompletion',               # loc
                    'Enter one value with autocompletion',                     # loc
                    'Enter up to [quant,_1,value,values] with autocompletion', # loc
                  ]
    },

    Date => {
        sort_order => 90,
        selection_type => 0,
        canonicalizes => 0,
        labels         => [
                    'Select multiple dates',              # loc
                    'Select date',                        # loc
                    'Select up to [quant,_1,date,dates]', # loc
                  ]
            },
    DateTime => {
        sort_order => 100,
        selection_type => 0,
        canonicalizes => 0,
        labels         => [
                    'Select multiple datetimes',                  # loc
                    'Select datetime',                            # loc
                    'Select up to [quant,_1,datetime,datetimes]', # loc
                  ]
                },

    IPAddress => {
        sort_order => 110,
        selection_type => 0,
        canonicalizes => 0,

        labels => [ 'Enter multiple IP addresses',                    # loc
                    'Enter one IP address',                           # loc
                    'Enter up to [quant,_1,IP address,IP addresses]', # loc
                  ]
                },
    IPAddressRange => {
        sort_order => 120,
        selection_type => 0,
        canonicalizes => 0,

        labels => [ 'Enter multiple IP address ranges',                          # loc
                    'Enter one IP address range',                                # loc
                    'Enter up to [quant,_1,IP address range,IP address ranges]', # loc
                  ]
                },
);


my %BUILTIN_GROUPINGS;
my %FRIENDLY_LOOKUP_TYPES = ();

__PACKAGE__->RegisterLookupType( 'RT::Queue-RT::Ticket' => "Tickets", );    #loc
__PACKAGE__->RegisterLookupType( 'RT::Queue-RT::Ticket-RT::Transaction' => "Ticket Transactions", ); #loc
__PACKAGE__->RegisterLookupType( 'RT::User'  => "Users", );                           #loc
__PACKAGE__->RegisterLookupType( 'RT::Queue'  => "Queues", );                         #loc
__PACKAGE__->RegisterLookupType( 'RT::Group' => "Groups", );                          #loc

__PACKAGE__->RegisterBuiltInGroupings(
    'RT::Ticket'    => [ qw(Basics Dates Links People) ],
    'RT::User'      => [ 'Identity', 'Access control', 'Location', 'Phones' ],
    'RT::Group'     => [ 'Basics' ],
);

__PACKAGE__->AddRight( General => SeeCustomField         => 'View custom fields'); # loc
__PACKAGE__->AddRight( Admin   => AdminCustomField       => 'Create, modify and delete custom fields'); # loc
__PACKAGE__->AddRight( Admin   => AdminCustomFieldValues => 'Create, modify and delete custom fields values'); # loc
__PACKAGE__->AddRight( Staff   => ModifyCustomField      => 'Add, modify and delete custom field values for objects'); # loc
__PACKAGE__->AddRight( Staff   => SetInitialCustomField  => 'Add custom field values only at object creation time'); # loc

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
  varchar(255) 'EntryHint'.
  smallint(6) 'Disabled'.

C<LookupType> is generally the result of either
C<RT::Ticket->CustomFieldLookupType> or C<RT::Transaction->CustomFieldLookupType>.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name                   => '',
        Type                   => '',
        MaxValues              => 0,
        Pattern                => '',
        Description            => '',
        Disabled               => 0,
        LookupType             => '',
        LinkValueTo            => '',
        IncludeContentForValue => '',
        EntryHint              => undef,
        UniqueValues           => 0,
        CanonicalizeClass      => undef,
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

    if ( $args{'CanonicalizeClass'} ||= undef ) {
        return (0, $self->loc("This custom field can not have a canonicalizer"))
            unless $self->IsCanonicalizeType( $args{'Type'} );

        unless ( $self->ValidateCanonicalizeClass( $args{'CanonicalizeClass'} ) ) {
            return (0, $self->loc("Invalid custom field values canonicalizer"));
        }
    }

    $args{'Disabled'} ||= 0;

    (my $rv, $msg) = $self->SUPER::Create(
        Name              => $args{'Name'},
        Type              => $args{'Type'},
        RenderType        => $args{'RenderType'},
        MaxValues         => $args{'MaxValues'},
        Pattern           => $args{'Pattern'},
        BasedOn           => $args{'BasedOn'},
        ValuesClass       => $args{'ValuesClass'},
        Description       => $args{'Description'},
        Disabled          => $args{'Disabled'},
        LookupType        => $args{'LookupType'},
        UniqueValues      => $args{'UniqueValues'},
        CanonicalizeClass => $args{'CanonicalizeClass'},
    );

    if ($rv) {
        if ( exists $args{'LinkValueTo'}) {
            $self->SetLinkValueTo($args{'LinkValueTo'});
        }

        $self->SetEntryHint( $args{EntryHint} // $self->FriendlyType );

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



=head2 LoadByName Name => C<NAME>, [...]

Loads the Custom field named NAME.  As other optional parameters, takes:

=over

=item LookupType => C<LOOKUPTYPE>

The type of Custom Field to look for; while this parameter is not
required, it is highly suggested, or you may not find the Custom Field
you are expecting.  It should be passed a C<LookupType> such as
L<RT::Ticket/CustomFieldLookupType> or
L<RT::User/CustomFieldLookupType>.

=item ObjectType => C<CLASS>

The class of object that the custom field is applied to.  This can be
intuited from the provided C<LookupType>.

=item ObjectId => C<ID>

limits the custom field search to one applied to the relevant id.  For
example, if a C<LookupType> of C<< RT::Ticket->CustomFieldLookupType >>
is used, this is which Queue the CF must be applied to.  Pass 0 to only
search custom fields that are applied globally.

=item IncludeDisabled => C<BOOLEAN>

Whether it should return Disabled custom fields if they match; defaults
to on, though non-Disabled custom fields are returned preferentially.

=item IncludeGlobal => C<BOOLEAN>

Whether to also search global custom fields, even if a value is provided
for C<ObjectId>; defaults to off.  Non-global custom fields are returned
preferentially.

=back

For backwards compatibility, a value passed for C<Queue> is equivalent
to specifying a C<LookupType> of L<RT::Ticket/CustomFieldLookupType>,
and a C<ObjectId> of the value passed as C<Queue>.

If multiple custom fields match the above constraints, the first
according to C<SortOrder> will be returned; ties are broken by C<id>,
lowest-first.

=head2 LoadNameAndQueue

=head2 LoadByNameAndQueue

Deprecated alternate names for L</LoadByName>.

=cut

# Compatibility for API change after 3.0 beta 1
*LoadNameAndQueue = \&LoadByName;
# Change after 3.4 beta.
*LoadByNameAndQueue = \&LoadByName;

sub LoadByName {
    my $self = shift;
    my %args = (
        Name       => undef,
        LookupType => undef,
        ObjectType => undef,
        ObjectId   => undef,

        IncludeDisabled => 1,
        IncludeGlobal   => 0,

        # Back-compat
        Queue => undef,

        @_,
    );

    unless ( defined $args{'Name'} && length $args{'Name'} ) {
        $RT::Logger->error("Couldn't load Custom Field without Name");
        return wantarray ? (0, $self->loc("No name provided")) : 0;
    }

    if ( defined $args{'Queue'} ) {
        # Set a LookupType for backcompat, otherwise we'll calculate
        # one of RT::Queue from your ContextObj.  Older code was relying
        # on us defaulting to RT::Queue-RT::Ticket in old LimitToQueue call.
        $args{LookupType} ||= 'RT::Queue-RT::Ticket';
        $args{ObjectId}   //= delete $args{Queue};
    }

    # Default the ObjectType to the top category of the LookupType; it's
    # what the CFs are assigned on.
    $args{ObjectType} ||= $1 if $args{LookupType} and $args{LookupType} =~ /^([^-]+)/;

    # Resolve the ObjectId/ObjectType; this is necessary to properly
    # limit ObjectId, and also possibly useful to set a ContextObj if we
    # are currently lacking one.  It is not strictly necessary if we
    # have a context object and were passed a numeric ObjectId, but it
    # cannot hurt to verify its sanity.  Skip if we have a false
    # ObjectId, which means "global", or if we lack an ObjectType
    if ($args{ObjectId} and $args{ObjectType}) {
        my ($obj, $ok, $msg);
        eval {
            $obj = $args{ObjectType}->new( $self->CurrentUser );
            ($ok, $msg) = $obj->Load( $args{ObjectId} );
        };

        if ($ok) {
            $args{ObjectId} = $obj->id;
            $self->SetContextObject( $obj )
                unless $self->ContextObject;
        } else {
            $RT::Logger->warning("Failed to load $args{ObjectType} '$args{ObjectId}'");
            if ($args{IncludeGlobal}) {
                # Fall back to acting like we were only asked about the
                # global case
                $args{ObjectId} = 0;
            } else {
                # If they didn't also want global results, there's no
                # point in searching; abort
                return wantarray ? (0, $self->loc("Not found")) : 0;
            }
        }
    } elsif (not $args{ObjectType} and $args{ObjectId}) {
        # If we skipped out on the above due to lack of ObjectType, make
        # sure we clear out ObjectId of anything lingering
        $RT::Logger->warning("No LookupType or ObjectType passed; ignoring ObjectId");
        delete $args{ObjectId};
    }

    my $CFs = RT::CustomFields->new( $self->CurrentUser );
    $CFs->SetContextObject( $self->ContextObject );
    my $field = $args{'Name'} =~ /\D/? 'Name' : 'id';
    $CFs->Limit( FIELD => $field, VALUE => $args{'Name'}, CASESENSITIVE => 0);

    # The context object may be a ticket, for example, as context for a
    # queue CF.  The valid lookup types are thus the entire set of
    # ACLEquivalenceObjects for the context object.
    $args{LookupType} ||= [
        map {$_->CustomFieldLookupType}
            ($self->ContextObject, $self->ContextObject->ACLEquivalenceObjects) ]
        if $self->ContextObject;

    # Apply LookupType limits
    $args{LookupType} = [ $args{LookupType} ]
        if $args{LookupType} and not ref($args{LookupType});
    $CFs->Limit( FIELD => "LookupType", OPERATOR => "IN", VALUE => $args{LookupType} )
        if $args{LookupType};

    # Default to by SortOrder and id; this mirrors the standard ordering
    # of RT::CustomFields (minus the Name, which is guaranteed to be
    # fixed)
    my @order = (
        { FIELD => 'SortOrder',
          ORDER => 'ASC' },
        { FIELD => 'id',
          ORDER => 'ASC' },
    );

    if (defined $args{ObjectId}) {
        # The join to OCFs is distinct -- either we have a global
        # application or an objectid match, but never both.  Even if
        # this were not the case, we care only for the first row.
        my $ocfs = $CFs->_OCFAlias( Distinct => 1);
        if ($args{IncludeGlobal}) {
            $CFs->Limit(
                ALIAS    => $ocfs,
                FIELD    => 'ObjectId',
                OPERATOR => 'IN',
                VALUE    => [ $args{ObjectId}, 0 ],
            );
            # Find the queue-specific first
            unshift @order, { ALIAS => $ocfs, FIELD => "ObjectId", ORDER => "DESC" };
        } else {
            $CFs->Limit(
                ALIAS => $ocfs,
                FIELD => 'ObjectId',
                VALUE => $args{ObjectId},
            );
        }
    }

    if ($args{IncludeDisabled}) {
        # Load disabled fields, but return them only as a last resort.
        # This goes at the front of @order, as we prefer the
        # non-disabled global CF to the disabled Queue-specific CF.
        $CFs->FindAllRows;
        unshift @order, { FIELD => "Disabled", ORDER => 'ASC' };
    }

    # Apply the above orderings
    $CFs->OrderByCols( @order );

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
        $class->require or die "Can't load $class: $@";
    }
    my $cf_values = $class->new( $self->CurrentUser );
    $cf_values->SetCustomFieldObject( $self );
    # if the user has no rights, return an empty object
    if ( $self->id && $self->CurrentUserCanSee ) {
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

    my ($ok, $msg) = $val_to_del->Delete;
    unless ( $ok ) {
        return (0, $self->loc("Custom field value could not be deleted"));
    }
    return ($ok, $self->loc("Custom field value deleted"));
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

Returns a boolean value indicating whether the C<Values> method makes sense
to this Custom Field.

=cut

sub IsSelectionType {
    my $self = shift;
    my $type = @_ ? shift : $self->Type;
    return undef unless $type;
    return $FieldTypes{$type}->{selection_type};
}

=head2 IsCanonicalizeType

Returns a boolean value indicating whether the type of this custom field
permits using a canonicalizer.

=cut

sub IsCanonicalizeType {
    my $self = shift;
    my $type = @_ ? shift : $self->Type;
    return undef unless $type;
    return $FieldTypes{$type}->{canonicalizes};
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

=head2 SetValuesClass CLASS

Writer method for the ValuesClass field; validates that the custom field can
use a ValuesClass, and that the provided ValuesClass passes
L</ValidateValuesClass>.

=cut

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

=head2 ValidateValuesClass CLASS

Validates a potential ValuesClass value; the ValuesClass may be C<undef> or
the string C<"RT::CustomFieldValues"> (both of which make this custom field
use the ordinary values implementation), or a class name in the listed in
the L<RT_Config/@CustomFieldValuesSources> setting.

Returns true if valid; false if invalid.

=cut

sub ValidateValuesClass {
    my $self = shift;
    my $class = shift;

    return 1 if !$class || $class eq 'RT::CustomFieldValues';
    return 1 if grep $class eq $_, RT->Config->Get('CustomFieldValuesSources');
    return undef;
}

=head2 SetCanonicalizeClass CLASS

Writer method for the CanonicalizeClass field; validates that the custom
field can use a CanonicalizeClass, and that the provided CanonicalizeClass
passes L</ValidateCanonicalizeClass>.

=cut

sub SetCanonicalizeClass {
    my $self = shift;
    my $class = shift;

    if ( !$class ) {
        return $self->_Set( Field => 'CanonicalizeClass', Value => undef, @_ );
    }

    return (0, $self->loc("This custom field can not have a canonicalizer"))
        unless $self->IsCanonicalizeType;

    unless ( $self->ValidateCanonicalizeClass( $class ) ) {
        return (0, $self->loc("Invalid custom field values canonicalizer"));
    }
    return $self->_Set( Field => 'CanonicalizeClass', Value => $class, @_ );
}

=head2 ValidateCanonicalizeClass CLASS

Validates a potential CanonicalizeClass value; the CanonicalizeClass may be
C<undef> (which make this custom field use no special canonicalization), or
a class name in the listed in the
L<RT_Config/@CustomFieldValuesCanonicalizers> setting.

Returns true if valid; false if invalid.

=cut

sub ValidateCanonicalizeClass {
    my $self = shift;
    my $class = shift;

    return 1 if !$class;
    return 1 if grep $class eq $_, RT->Config->Get('CustomFieldValuesCanonicalizers');
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
    my $need_to_update_hint;
    $need_to_update_hint = 1 if $self->EntryHint && $self->EntryHint eq $self->FriendlyType;
    my ( $ret, $msg ) = $self->_Set( Field => 'Type', Value => $type );
    $self->SetEntryHint($self->FriendlyType) if $need_to_update_hint && $ret;
    return ( $ret, $msg );
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
    my %args = @_;
    unless ( $self->CurrentUserHasRight('AdminCustomField') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    my ($ret, $msg) = $self->SUPER::_Set( @_ );
    if ( $args{Field} =~ /^(?:MaxValues|Type|LookupType|ValuesClass|CanonicalizeClass)$/ ) {
        $self->CleanupDefaultValues;
    }
    return ($ret, $msg);
}



=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value {
    my $self  = shift;
    return undef unless $self->id;

    # we need to do the rights check
    unless ( $self->CurrentUserCanSee ) {
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

sub SetDisabled {
    my $self = shift;
    my $val = shift;

    my ($status, $msg) = $self->_Set(Field => 'Disabled', Value => $val);

    unless ($status) {
        return ($status, $msg);
    }

    if ( $val == 1 ) {
        return (1, $self->loc("Disabled"));
    } else {
        return (1, $self->loc("Enabled"));
    }
}

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
    return sort keys %FRIENDLY_LOOKUP_TYPES;
}

=head2 FriendlyLookupType

Returns a localized description of the type of this custom field

=cut

sub FriendlyLookupType {
    my $self = shift;
    my $lookup = shift || $self->LookupType;

    return ($self->loc( $FRIENDLY_LOOKUP_TYPES{$lookup} ))
        if defined $FRIENDLY_LOOKUP_TYPES{$lookup};

    my @types = map { s/^RT::// ? $self->loc($_) : $_ }
      grep { defined and length }
      split( /-/, $lookup )
      or return;

    state $LocStrings = [
        "[_1] objects",            # loc
        "[_1]'s [_2] objects",        # loc
        "[_1]'s [_2]'s [_3] objects",   # loc
    ];
    return ( $self->loc( $LocStrings->[$#types], @types ) );
}

=head1 RecordClassFromLookupType

Returns the type of Object referred to by ObjectCustomFields' ObjectId column

Optionally takes a LookupType to use instead of using the value on the loaded
record.  In this case, the method may be called on the class instead of an
object.

=cut

sub RecordClassFromLookupType {
    my $self = shift;
    my $type = shift || $self->LookupType;
    my ($class) = ($type =~ /^([^-]+)/);
    unless ( $class ) {
        if (blessed($self) and $self->LookupType eq $type) {
            $RT::Logger->error(
                "Custom Field #". $self->id
                ." has incorrect LookupType '$type'"
            );
        } else {
            RT->Logger->error("Invalid LookupType passed as argument: $type");
        }
        return undef;
    }
    return $class;
}

=head1 ObjectTypeFromLookupType

Returns the ObjectType used in ObjectCustomFieldValues rows for this CF

Optionally takes a LookupType to use instead of using the value on the loaded
record.  In this case, the method may be called on the class instead of an
object.

=cut

sub ObjectTypeFromLookupType {
    my $self = shift;
    my $type = shift || $self->LookupType;
    my ($class) = ($type =~ /([^-]+)$/);
    unless ( $class ) {
        if (blessed($self) and $self->LookupType eq $type) {
            $RT::Logger->error(
                "Custom Field #". $self->id
                ." has incorrect LookupType '$type'"
            );
        } else {
            RT->Logger->error("Invalid LookupType passed as argument: $type");
        }
        return undef;
    }
    return $class;
}

sub CollectionClassFromLookupType {
    my $self = shift;
    my $record_class = shift || $self->RecordClassFromLookupType;

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
    my $oid = $ocf->Add(
        CustomField => $self->id, ObjectId => $id,
    );

    my $msg;
    # If object has no id, it represents all objects
    if ($object->id) {
        $msg = $self->loc( 'Added custom field [_1] to [_2].', $self->Name, $object->Name );
    } else {
        $msg = $self->loc( 'Globally added custom field [_1].', $self->Name );
    }

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

    my ($ok, $msg) = $ocf->Delete;
    return ($ok, $msg) unless $ok;

    # If object has no id, it represents all objects
    if ($object->id) {
        return (1, $self->loc( 'Removed custom field [_1] from [_2].', $self->Name, $object->Name ) );
    } else {
        return (1, $self->loc( 'Globally removed custom field [_1].', $self->Name ) );
    }
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
        ForCreation  => 0,
        @_
    );
    my $obj = $args{'Object'} or return ( 0, $self->loc('Invalid object') );

    unless (
        $self->CurrentUserHasRight('ModifyCustomField') ||
        ($args{ForCreation} && $self->CurrentUserHasRight('SetInitialCustomField'))
    ) {
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

    if ($self->UniqueValues) {
        my $class = $self->CollectionClassFromLookupType($self->ObjectTypeFromLookupType);
        my $collection = $class->new(RT->SystemUser);
        $collection->LimitCustomField(CUSTOMFIELD => $self->Id, OPERATOR => '=', VALUE => $args{'LargeContent'} // $args{'Content'});

        if ($collection->Count) {
            $RT::Logger->debug( "Non-unique custom field value for CF #" . $self->Id ." with object custom field value " . $collection->First->Id );
            $RT::Handle->Rollback();
            return ( 0, $self->loc('That is not a unique value') );
        }
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


sub _CanonicalizeValue {
    my $self = shift;
    my $args = shift;

    my $type = $self->__Value('Type');
    return 1 unless $type;

    $self->_CanonicalizeValueWithCanonicalizer($args);

    my $method = '_CanonicalizeValue'. $type;
    return 1 unless $self->can($method);
    $self->$method($args);
}

sub _CanonicalizeValueWithCanonicalizer {
    my $self = shift;
    my $args = shift;

    return 1 if !$self->CanonicalizeClass;

    my $class = $self->CanonicalizeClass;
    $class->require or die "Can't load $class: $@";
    my $canonicalizer = $class->new($self->CurrentUser);

    $args->{'Content'} = $canonicalizer->CanonicalizeValue(
        CustomField => $self,
        Content     => $args->{'Content'},
    );

    return 1;
}

sub _CanonicalizeValueDateTime {
    my $self    = shift;
    my $args    = shift;
    my $DateObj = RT::Date->new( $self->CurrentUser );
    $DateObj->Set( Format => 'unknown',
                   Value  => $args->{'Content'} );
    $args->{'Content'} = $DateObj->ISO;
    return 1;
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
    return 1;
}

sub _CanonicalizeValueIPAddress {
    my $self = shift;
    my $args = shift;

    $args->{Content} = RT::ObjectCustomFieldValue->ParseIP( $args->{Content} );
    return (0, $self->loc("Content is not a valid IP address"))
        unless $args->{Content};
    return 1;
}

sub _CanonicalizeValueIPAddressRange {
    my $self = shift;
    my $args = shift;

    my $content = $args->{Content};
    $content .= "-".$args->{LargeContent} if $args->{LargeContent};

    ($args->{Content}, $args->{LargeContent})
        = RT::ObjectCustomFieldValue->ParseIPRange( $content );

    $args->{ContentType} = 'text/plain';
    return (0, $self->loc("Content is not a valid IP address range"))
        unless $args->{Content};
    return 1;
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

    my ($ok, $msg) = $oldval->Delete();
    unless ($ok) {
        return(0, $self->loc("Custom field value could not be deleted"));
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
    unless ($self->id and $self->CurrentUserCanSee) {
        # Return an empty object if they have no rights to see
        $values->Limit( FIELD => "id", VALUE => 0, SUBCLAUSE => "ACL" );
        return ($values);
    }

    $values->LimitToCustomField($self->Id);
    $values->LimitToObject($object);

    return ($values);
}

=head2 CurrentUserCanSee

If the user has SeeCustomField they can see this custom field and its details.

Otherwise, if the user has SetInitialCustomField and this is being used in a
"create" context, then they can see this custom field and its details. This
allows you to set up custom fields that are only visible on create pages and
are then inaccessible.

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return 1 if $self->CurrentUserHasRight('SeeCustomField');

    return 1 if $self->{include_set_initial}
             && $self->CurrentUserHasRight('SetInitialCustomField');

    return 0;
}

=head2 RegisterLookupType LOOKUPTYPE FRIENDLYNAME

Tell RT that a certain object accepts custom fields via a lookup type and
provide a friendly name for such CFs.

Examples:

    'RT::Queue-RT::Ticket'                 => "Tickets",                # loc
    'RT::Queue-RT::Ticket-RT::Transaction' => "Ticket Transactions",    # loc
    'RT::User'                             => "Users",                  # loc
    'RT::Group'                            => "Groups",                 # loc
    'RT::Queue'                            => "Queues",                 # loc

This is a class method. 

=cut

sub RegisterLookupType {
    my $self = shift;
    my $path = shift;
    my $friendly_name = shift;

    $FRIENDLY_LOOKUP_TYPES{$path} = $friendly_name;
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
        if (length $value and defined $value) {
            $self->SetAttribute( Name => $template_name, Content => $value );
        } else {
            $self->DeleteAttribute( $template_name );
        }
        return ( 1, $self->loc('Updated') );
    } else {
        unless ( $self->id && $self->CurrentUserCanSee ) {
            return (undef);
        }

        my ($attr) = $self->Attributes->Named($template_name);
        return undef unless $attr;
        return $attr->Content;
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
        unless $cf->id && $cf->CurrentUserCanSee;

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


sub SupportDefaultValues {
    my $self = shift;
    return 0 unless $self->id;
    return 0 unless $self->LookupType =~ /RT::(?:Ticket|Transaction|Asset)$/;
    return $self->Type !~ /^(?:Image|Binary)$/;
}

sub DefaultValues {
    my $self = shift;
    my %args = (
        Object => RT->System,
        @_,
    );
    my $attr = $args{Object}->FirstAttribute('CustomFieldDefaultValues');
    my $values;
    $values = $attr->Content->{$self->id} if $attr && $attr->Content;
    return $values if defined $values;

    if ( !$args{Object}->isa( 'RT::System' ) ) {
        my $system_attr = RT::System->FirstAttribute( 'CustomFieldDefaultValues' );
        $values = $system_attr->Content->{$self->id} if $system_attr && $system_attr->Content;
        return $values if defined $values;
    }
    return undef;
}

sub SetDefaultValues {
    my $self = shift;
    my %args = (
        Object => RT->System,
        Values => undef,
        @_,
    );
    my $attr = $args{Object}->FirstAttribute( 'CustomFieldDefaultValues' );
    my ( $old_values, $old_content, $new_values );
    if ( $attr && $attr->Content ) {
        $old_content = $attr->Content;
        $old_values = $old_content->{ $self->id };
    }

    if ( !$args{Object}->isa( 'RT::System' ) && !defined $old_values ) {
        my $system_attr = RT::System->FirstAttribute( 'CustomFieldDefaultValues' );
        if ( $system_attr && $system_attr->Content ) {
            $old_values = $system_attr->Content->{ $self->id };
        }
    }

    if ( defined $old_values && length $old_values ) {
        $old_values = join ', ', @$old_values if ref $old_values eq 'ARRAY';
    }

    $new_values = $args{Values};
    if ( defined $new_values && length $new_values ) {
        $new_values = join ', ', @$new_values if ref $new_values eq 'ARRAY';
    }

    return 1 if ( $new_values // '' ) eq ( $old_values // '' );

    my ($ret, $msg) = $args{Object}->SetAttribute(
        Name    => 'CustomFieldDefaultValues',
        Content => {
            %{ $old_content || {} }, $self->id => $args{Values},
        },
    );

    $old_values = $self->loc('(no value)') unless defined $old_values && length $old_values;
    $new_values = $self->loc( '(no value)' ) unless defined $new_values && length $new_values;

    if ( $ret ) {
        return ( $ret, $self->loc( 'Default values changed from [_1] to [_2]', $old_values, $new_values ) );
    }
    else {
        return ( $ret, $self->loc( "Can't change default values from [_1] to [_2]: [_3]", $old_values, $new_values, $msg ) );
    }
}

sub CleanupDefaultValues {
    my $self  = shift;
    my $attrs = RT::Attributes->new( $self->CurrentUser );
    $attrs->Limit( FIELD => 'Name', VALUE => 'CustomFieldDefaultValues' );

    my @values;
    if ( $self->Type eq 'Select' ) {
        # Select has a limited list valid values, we need to exclude invalid ones
        @values = map { $_->Name } @{ $self->Values->ItemsArrayRef || [] };
    }

    while ( my $attr = $attrs->Next ) {
        my $content = $attr->Content;
        next unless $content;
        my $changed;
        if ( $self->SupportDefaultValues ) {
            if ( $self->MaxValues == 1 && ref $content->{ $self->id } eq 'ARRAY' ) {
                $content->{ $self->id } = $content->{ $self->id }[ 0 ];
                $changed = 1;
            }

            my $default_values = $content->{ $self->id };
            if ( $default_values ) {
                if ( $self->Type eq 'Select' ) {
                    if ( ref $default_values ne 'ARRAY' && $default_values =~ /\n/ ) {

                        # e.g. multiple values Freeform cf has 2 default values: foo and "bar",
                        # the values will be stored as "foo\nbar".  so we need to convert it to ARRAY for Select cf.
                        # this could happen when we change a Freeform cf into a Select one

                        $default_values = [ split /\s*\n+\s*/, $default_values ];
                        $content->{ $self->id } = $default_values;
                        $changed = 1;
                    }

                    if ( ref $default_values eq 'ARRAY' ) {
                        my @new_defaults;
                        for my $default ( @$default_values ) {
                            if ( grep { $_ eq $default } @values ) {
                                push @new_defaults, $default;
                            }
                            else {
                                $changed = 1;
                            }
                        }

                        $content->{ $self->id } = \@new_defaults if $changed;
                    }
                    elsif ( !grep { $_ eq $default_values } @values ) {
                        delete $content->{ $self->id };
                        $changed = 1;
                    }
                }
                else {
                    # ARRAY default values only happen for Select cf. we need to convert it to a scalar for other cfs.
                    # this could happen when we change a Select cf into a Freeform one

                    if ( ref $default_values eq 'ARRAY' ) {
                        $content->{ $self->id } = join "\n", @$default_values;
                        $changed = 1;
                    }

                    if ($self->MaxValues == 1) {
                        my $args = { Content => $default_values };
                        $self->_CanonicalizeValueWithCanonicalizer($args);
                        if ($args->{Content} ne $default_values) {
                            $content->{ $self->id } = $default_values;
                            $changed = 1;
                        }
                    }
                    else {
                        my @new_values;
                        my $multi_changed = 0;
                        for my $value (split /\s*\n+\s*/, $default_values) {
                            my $args = { Content => $value };
                            $self->_CanonicalizeValueWithCanonicalizer($args);
                            push @new_values, $args->{Content};
                            $multi_changed = 1 if $args->{Content} ne $value;
                        }

                        if ($multi_changed) {
                            $content->{ $self->id } = join "\n", @new_values;
                            $changed = 1;
                        }
                    }
                }
            }
        }
        else {
            if ( exists $content->{ $self->id } ) {
                delete $content->{ $self->id };
                $changed = 1;
            }
        }
        $attr->SetContent( $content ) if $changed;
    }
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

=head2 SetEntryHint VALUE


Set EntryHint to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, EntryHint will be stored as a varchar(255).)


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
        EntryHint =>
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0, is_numeric => 0,  type => 'varchar(255)', default => undef },
        UniqueValues =>
        {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},
        CanonicalizeClass =>
        {read => 1, write => 1, sql_type => 12, length => 64,  is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => ''},
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

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->BasedOnObj )
        if $self->BasedOnObj->id;

    my $applied = RT::ObjectCustomFields->new( $self->CurrentUser );
    $applied->LimitToCustomField( $self->id );
    $deps->Add( in => $applied );

    $deps->Add( in => $self->Values ) if $self->ValuesClass eq "RT::CustomFieldValues";
}

sub __DependsOn {
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Custom field values
    push( @$list, $self->Values );

# Applications of this CF
    my $applied = RT::ObjectCustomFields->new( $self->CurrentUser );
    $applied->LimitToCustomField( $self->Id );
    push @$list, $applied;

# Ticket custom field values
    my $objs = RT::ObjectCustomFieldValues->new( $self->CurrentUser );
    $objs->LimitToCustomField( $self->Id );
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );
    return $self->SUPER::__DependsOn( %args );
}

=head2 LoadByNameAndCatalog

Loads the described asset custom field, if one is found, into the current
object.  This method only consults custom fields applied to L<RT::Catalog> for
L<RT::Asset> objects.

Takes a hash with the keys:

=over

=item Name

A L<RT::CustomField> ID or Name which applies to L<assets|RT::Asset>.

=item Catalog

Optional.  An L<RT::Catalog> ID or Name.

=back

If Catalog is specified, only a custom field added to that Catalog will be loaded.

If Catalog is C<0>, only global asset custom fields will be loaded.

If no Catalog is specified, all asset custom fields are searched including
global and catalog-specific CFs.

Please note that this method may load a Disabled custom field if no others
matching the same criteria are found.  Enabled CFs are preferentially loaded.

=cut

# To someday be merged into RT::CustomField::LoadByName
sub LoadByNameAndCatalog {
    my $self = shift;
    my %args = (
                Catalog => undef,
                Name  => undef,
                @_,
               );

    unless ( defined $args{'Name'} && length $args{'Name'} ) {
        $RT::Logger->error("Couldn't load Custom Field without Name");
        return wantarray ? (0, $self->loc("No name provided")) : 0;
    }

    # if we're looking for a catalog by name, make it a number
    if ( defined $args{'Catalog'} && ($args{'Catalog'} =~ /\D/ || !$self->ContextObject) ) {
        my $CatalogObj = RT::Catalog->new( $self->CurrentUser );
        my ($ok, $msg) = $CatalogObj->Load( $args{'Catalog'} );
        if ( $ok ){
            $args{'Catalog'} = $CatalogObj->Id;
        }
        elsif ($args{'Catalog'}) {
            RT::Logger->error("Unable to load catalog " . $args{'Catalog'} . $msg);
            return (0, $msg);
        }
        $self->SetContextObject( $CatalogObj )
          unless $self->ContextObject;
    }

    my $CFs = RT::CustomFields->new( $self->CurrentUser );
    $CFs->SetContextObject( $self->ContextObject );
    my $field = $args{'Name'} =~ /\D/? 'Name' : 'id';
    $CFs->Limit( FIELD => $field, VALUE => $args{'Name'}, CASESENSITIVE => 0);

    # Limit to catalog, if provided. This will also limit to RT::Asset types.
    $CFs->LimitToCatalog( $args{'Catalog'} );

    # When loading by name, we _can_ load disabled fields, but prefer
    # non-disabled fields.
    $CFs->FindAllRows;
    $CFs->OrderByCols(
                      {
                       FIELD => "Disabled", ORDER => 'ASC' },
                     );

    # We only want one entry.
    $CFs->RowsPerPage(1);

    return (0, $self->loc("Not found")) unless my $first = $CFs->First;
    return $self->LoadById( $first->id );
}


RT::Base->_ImportOverlays();

1;
