# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::CustomRole;
use base 'RT::Record';

use RT::CustomRoles;
use RT::ObjectCustomRole;

use Role::Basic 'with';
with "RT::Record::Role::LookupType";

=head1 NAME

RT::CustomRole - user-defined role groups

=head1 DESCRIPTION

=head1 METHODS

=head2 Table

Returns table name for records of this class

=cut

sub Table {'CustomRoles'}

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(255) 'Description'.
  int(11) 'MaxValues'.
  varchar(255) 'EntryHint'.
  varchar(255) 'LookupType'.
  smallint(6) 'Disabled'.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => '',
        Description => '',
        MaxValues   => 0,
        EntryHint   => '',
        LookupType  => '',
        Disabled    => 0,
        @_,
    );

    unless ( $self->CurrentUser->HasRight(Object => $RT::System, Right => 'AdminCustomRoles') ) {
        return (0, $self->loc('Permission Denied'));
    }

    {
        my ($val, $msg) = $self->_ValidateName( $args{'Name'} );
        return ($val, $msg) unless $val;
    }

    $args{'Disabled'} ||= 0;
    $args{'MaxValues'} = int $args{'MaxValues'};

    # backwards compatibility; used to be the only possibility
    $args{'LookupType'} ||= 'RT::Queue-RT::Ticket';

    $RT::Handle->BeginTransaction;

    my ($ok, $msg) = $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        MaxValues   => $args{'MaxValues'},
        EntryHint   => $args{'EntryHint'},
        LookupType  => $args{'LookupType'},
        Disabled    => $args{'Disabled'},
    );
    unless ($ok) {
        $RT::Handle->Rollback;
        $RT::Logger->error("Couldn't create CustomRole: $msg");
        return(undef);
    }

    # registration needs to happen before creating the system role group,
    # otherwise its validation that you're creating a group from
    # a valid role will fail
    $self->_RegisterAsRole;

    RT->System->CustomRoleCacheNeedsUpdate(1);

    # create a system role group for assigning rights on a global level
    # to members of this role
    my $system_group = RT::Group->new( RT->SystemUser );
    ($ok, $msg) = $system_group->CreateRoleGroup(
        Name                => $self->GroupType,
        Object              => RT->System,
        Description         => 'SystemRolegroup for internal use',  # loc
        InsideTransaction   => 1,
    );
    unless ($ok) {
        $RT::Handle->Rollback;
        $RT::Logger->error("Couldn't create system custom role group: $msg");
        return(undef);
    }

    $RT::Handle->Commit;

    return ($ok, $msg);
}

sub _RegisterAsRole {
    my $self = shift;
    my $id = $self->Id;

    $self->ObjectTypeFromLookupType->RegisterRole(
        Name                 => $self->GroupType,
        EquivClasses         => [$self->RecordClassFromLookupType],
        Single               => $self->SingleValue,
        UserDefined          => 1,

        # multi-value roles can have queue-level members,
        # single-value roles cannot (just like Owner)
        ACLOnlyInEquiv       => $self->SingleValue,

        # only create role groups for tickets in queues which
        # have this custom role applied
        CreateGroupPredicate => sub {
            my %args = @_;
            my $object = $args{Object};

            my $role = RT::CustomRole->new(RT->SystemUser);
            $role->Load($id);

            if (my $predicate = $role->LookupTypeRegistration($role->LookupType, 'CreateGroupPredicate')) {
                return $predicate->($object, $role);
            }

            return 0;
        },

        # custom roles can apply to only a subset of queues
        AppliesToObjectPredicate => sub {
            my $object = shift;
            my $args = shift;

            # reload the role to avoid capturing $self across requests
            my $role = RT::CustomRole->new(RT->SystemUser);
            $role->Load($id);

            return 0 if $role->Disabled;

            # all roles are also available on RT::System for granting rights
            if ($object->isa('RT::System')) {
                return 1;
            }

            # for callers not specific to any queue, e.g. ColumnMap
            if (!ref($object)) {
                return 1;
            }

            if (my $predicate = $role->LookupTypeRegistration($role->LookupType, 'AppliesToObjectPredicate')) {
                return $predicate->($object, $role, $args);
            }

            return 0;
        },

        LabelGenerator => sub {
            my $object = shift;

            # reload the role to avoid capturing $self across requests
            my $role = RT::CustomRole->new(RT->SystemUser);
            $role->Load($id);

            return $role->Name;
        },
    );
}

sub _UnregisterAsRole {
    my $self = shift;

    $self->ObjectTypeFromLookupType->UnregisterRole($self->GroupType);
}

=head2 Load ID/NAME

Load a custom role.  If the value handed in is an integer, load by ID. Otherwise, load by name.

=cut

sub Load {
    my $self = shift;
    my $id = shift || '';

    if ( $id =~ /^\d+$/ ) {
        return $self->SUPER::Load( $id );
    } else {
        return $self->LoadByCols( Name => $id );
    }
}

=head2 ValidateName NAME

Takes a custom role name. Returns true if it's an ok name for
a new custom role. Returns undef if it's not valid.

=cut

sub ValidateName {
    my $self = shift;
    my $name = shift;

    my ($ok, $msg) = $self->_ValidateName($name);

    return $ok ? 1 : 0;
}

sub _ValidateName {
    my $self = shift;
    my $name = shift;

    return (undef, "Role name is required") unless length $name;

    # Validate via the superclass first
    unless ( my $ok = $self->SUPER::ValidateName($name) ) {
        return ($ok, $self->loc("'[_1]' is not a valid name.", $name));
    }

    return (1);
}

=head2 Delete

Delete this object. You should Disable instead.

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminCustomRoles') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    RT::ObjectCustomRole->new( $self->CurrentUser )->DeleteAll( CustomRole => $self );

    $self->_UnregisterAsRole;
    RT->System->CustomRoleCacheNeedsUpdate(1);

    return ( $self->SUPER::Delete(@_) );
}

=head2 IsAdded

Takes an object id and returns a boolean indicating whether the custom role applies to that object

=cut

sub IsAdded {
    my $self = shift;
    my $record = RT::ObjectCustomRole->new( $self->CurrentUser );
    $record->LoadByCols( CustomRole => $self->id, ObjectId => shift );
    return undef unless $record->id;
    return $record;
}

=head2 IsAddedToAny

Returns a boolean of whether this custom role has been applied to any objects

=cut

sub IsAddedToAny {
    my $self = shift;
    my $record = RT::ObjectCustomRole->new( $self->CurrentUser );
    $record->LoadByCols( CustomRole => $self->id );
    return $record->id ? 1 : 0;
}

=head2 AddedTo

Returns a collection of objects this custom role is applied to

=cut

sub AddedTo {
    my $self = shift;
    return RT::ObjectCustomRole->new( $self->CurrentUser )
        ->AddedTo( CustomRole => $self );
}

=head2 NotAddedTo

Returns a collection of objects this custom role is not applied to

=cut

sub NotAddedTo {
    my $self = shift;
    return RT::ObjectCustomRole->new( $self->CurrentUser )
        ->NotAddedTo( CustomRole => $self );
}

=head2 AddToObject

Adds (applies) this custom role to the provided object (ObjectId).

Accepts a param hash of:

=over

=item C<ObjectId>

Object id of the class corresponding with L</LookupType>.

=item C<SortOrder>

Number indicating the relative order of the custom role

=back

Returns (val, message). If val is false, the message contains an error
message.

=cut

sub AddToObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $class = $self->RecordClassFromLookupType;
    my $object = $class->new( $self->CurrentUser );
    $object->Load( $args{'ObjectId'} );
    unless ($object->id) {
        RT->Logger->warn("Unable to load $class '$args{'ObjectId'}' for custom role " . $self->Id);
        return (0, $self->loc('Unable to load [_1]', $args{'ObjectId'}))
    }

    $args{'ObjectId'} = $object->id;

    return ( 0, $self->loc('Permission Denied') )
        unless $object->CurrentUserHasRight('AdminCustomRoles');

    my $rec = RT::ObjectCustomRole->new( $self->CurrentUser );
    return $rec->Add( %args, CustomRole => $self );
}

=head2 RemoveFromObject

Removes this custom role from the provided object (ObjectId).

Accepts a param hash of:

=over

=item C<ObjectId>

Object id of the class corresponding with L</LookupType>.

=back

Returns (val, message). If val is false, the message contains an error
message.

=cut

sub RemoveFromObject {
    my $self = shift;
    my %args = @_%2? (ObjectId => @_) : (@_);

    my $class = $self->RecordClassFromLookupType;
    my $object = $class->new( $self->CurrentUser );
    $object->Load( $args{'ObjectId'} );
    unless ($object->id) {
        RT->Logger->warn("Unable to load $class '$args{'ObjectId'}' for custom role " . $self->Id);
        return (0, $self->loc('Unable to load [_1]', $args{'ObjectId'}))
    }

    $args{'ObjectId'} = $object->id;

    return ( 0, $self->loc('Permission Denied') )
        unless $object->CurrentUserHasRight('AdminCustomRoles');

    my $rec = RT::ObjectCustomRole->new( $self->CurrentUser );
    $rec->LoadByCols( CustomRole => $self->id, ObjectId => $args{'ObjectId'} );
    return (0, $self->loc('Custom role is not added') ) unless $rec->id;
    return $rec->Delete;
}

=head2 SingleValue

Returns true if this custom role accepts only a single member.
Returns false if it accepts multiple members.

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

=head2 UnlimitedValues

Returns true if this custom role accepts multiple members.
Returns false if it accepts only a single member.

=cut

sub UnlimitedValues {
    my $self = shift;
    if (($self->MaxValues||0) == 0) {
        return 1;
    }
    else {
        return undef;
    }
}

=head2 GroupType

The C<Name> that groups for this custom role will have.

=cut

sub GroupType {
    my $self = shift;
    return 'RT::CustomRole-' . $self->id;
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

=head2 Description

Returns the current value of Description.
(In the database, Description is stored as varchar(255).)

=head2 SetDescription VALUE

Set Description to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)

=cut

=head2 MaxValues

Returns the current value of MaxValues.
(In the database, MaxValues is stored as int(11).)

=head2 SetMaxValues VALUE

Set MaxValues to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MaxValues will be stored as a int(11).)

=cut

sub SetMaxValues {
    my $self = shift;
    my $value = shift;

    my ($ok, $msg) = $self->_Set( Field => 'MaxValues', Value => $value );

    # update single/multi value declaration
    $self->_RegisterAsRole;
    RT->System->CustomRoleCacheNeedsUpdate(1);

    return ($ok, $msg);
}

=head2 LookupType

Returns the current value of LookupType.
(In the database, LookupType is stored as varchar(255).)

=head2 SetLookupType VALUE


Set LookupType to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, LookupType will be stored as a varchar(255).)

=cut

sub SetLookupType {
    my $self = shift;
    my $lookup = shift;
    if ( $lookup ne $self->LookupType ) {
        # Okay... We need to invalidate our existing relationships
        RT::ObjectCustomRole->new($self->CurrentUser)->DeleteAll( CustomRole => $self );
    }

    $self->_UnregisterAsRole;

    my ($ok, $msg) = $self->_Set(Field => 'LookupType', Value => $lookup);

    # update EquivClasses declaration
    $self->_RegisterAsRole;
    RT->System->CustomRoleCacheNeedsUpdate(1);

    return ($ok, $msg);
}

=head2 EntryHint

Returns the current value of EntryHint.
(In the database, EntryHint is stored as varchar(255).)

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

sub _SetGroupsDisabledForObject {
    my $self = shift;
    my $value = shift;
    my $object = shift;

    # set disabled on the object group
    my $object_group = RT::Group->new($self->CurrentUser);
    $object_group->LoadRoleGroup(
        Name   => $self->GroupType,
        Object => $object,
    );

    if (!$object_group->Id) {
        $RT::Handle->Rollback;
        $RT::Logger->error("Couldn't find role group for " . $self->GroupType . " on " . ref($object) . " #" . $object->Id);
        return(undef);
    }

    my ($ok, $msg) = $object_group->SetDisabled($value);
    unless ($ok) {
        $RT::Handle->Rollback;
        $RT::Logger->error("Couldn't SetDisabled($value) on role group: $msg");
        return(undef);
    }

    my $subgroup_config = $self->LookupTypeRegistration($self->LookupType, 'Subgroup');
    if ($subgroup_config) {
        # disable each existant ticket group
        my $groups = RT::Groups->new($self->CurrentUser);

        if ($value) {
            $groups->LimitToEnabled;
        }
        else {
            $groups->LimitToDeleted;
        }

        $groups->Limit(FIELD => 'Domain', OPERATOR => 'LIKE', VALUE => $subgroup_config->{Domain}, CASESENSITIVE => 0 );
        $groups->Limit(FIELD => 'Name', OPERATOR => '=', VALUE => $self->GroupType, CASESENSITIVE => 0);

        my $objects = $groups->Join(
            ALIAS1 => 'main',
            FIELD1 => 'Instance',
            TABLE2 => $subgroup_config->{Table},
            FIELD2 => 'Id',
        );
        $groups->Limit(
            ALIAS => $objects,
            FIELD => $subgroup_config->{Parent},
            VALUE => $object->Id,
        );

        while (my $group = $groups->Next) {
            my ($ok, $msg) = $group->SetDisabled($value);
            unless ($ok) {
                $RT::Handle->Rollback;
                $RT::Logger->error("Couldn't SetDisabled($value) role group: $msg");
                return(undef);
            }
        }
    }
}

sub SetDisabled {
    my $self = shift;
    my $value = shift;

    $RT::Handle->BeginTransaction();

    my ($ok, $msg) = $self->_Set( Field => 'Disabled', Value => $value );
    unless ($ok) {
        $RT::Handle->Rollback();
        $RT::Logger->warning("Couldn't ".(($value == 0) ? "enable" : "disable")." custom role ".$self->Name.": $msg");
        return ($ok, $msg);
    }

    # we can't unconditionally re-enable all role groups because
    # if you add a role to queues A and B, add users and privileges and
    # tickets on both, remove the role from B, disable the role, then re-enable
    # the role, we shouldn't re-enable B because it's still removed
    my $objects = $self->AddedTo;
    while (my $object = $objects->Next) {
        $self->_SetGroupsDisabledForObject($value, $object);
    }

    $RT::Handle->Commit();

    if ( $value == 0 ) {
        return (1, $self->loc("Custom role enabled"));
    } else {
        return (1, $self->loc("Custom role disabled"));
    }
}

sub _CoreAccessible {
    {
        id =>
        {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Name =>
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description =>
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        MaxValues =>
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        EntryHint =>
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
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

