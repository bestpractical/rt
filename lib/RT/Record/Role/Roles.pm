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

use strict;
use warnings;

package RT::Record::Role::Roles;
use Role::Basic;
use Scalar::Util qw(blessed);

=head1 NAME

RT::Record::Role::Roles - Common methods for records which "watchers" or "roles"

=head1 REQUIRES

=head2 L<RT::Record::Role>

=cut

with 'RT::Record::Role';

require RT::System;
require RT::Principal;
require RT::Group;
require RT::User;

require RT::EmailParser;

=head1 PROVIDES

=head2 RegisterRole

Registers an RT role which applies to this class for role-based access control.
Arguments:

=over 4

=item Name

Required.  The role name (i.e. Requestor, Owner, AdminCc, etc).

=item EquivClasses

Optional.  Array ref of classes through which this role percolates up to
L<RT::System>.  You can think of this list as:

    map { ref } $record_object->ACLEquivalenceObjects;

You should not include L<RT::System> itself in this list.

Simply calls RegisterRole on each equivalent class.

=item Single

Optional.  A true value indicates that this role may only contain a single user
as a member at any given time.  When adding a new member to a Single role, any
existing member will be removed.  If all members are removed, L<RT/Nobody> is
added automatically.

=item Column

Optional, implies Single.  Specifies a column on the announcing class into
which the single role member's user ID is denormalized.  The column will be
kept updated automatically as the role member changes.  This is used, for
example, for ticket owners and makes searching simpler (among other benefits).

=item ACLOnly

Optional.  A true value indicates this role is only used for ACLs and should
not be populated with members.

This flag is advisory only, and the Perl API still allows members to be added
to ACLOnly roles.

=item ACLOnlyInEquiv

Optional.  Automatically sets the ACLOnly flag for all EquivClasses, but not
the announcing class.

=item SortOrder

Optional.  A numeric value indicating the position of this role when sorted
ascending with other roles in a list.  Roles with the same sort order are
ordered alphabetically by name within themselves.

=item UserDefined

Optional.  A true value indicates that this role was created by the user and
as such is not managed by the core codebase or an extension.

=item CreateGroupPredicate

Optional.  A subroutine whose return value indicates whether the group for this
role should be created as part of L</_CreateRoleGroups>.  When this subroutine
is not provided, the group will be created.  The same parameters that will be
passed to L<RT::Group/CreateRoleGroup> are passed to your predicate (including
C<Object>)

=item AppliesToObjectPredicate

Optional.  A subroutine which decides whether a specific object in the class
has the role or not.

=item LabelGenerator

Optional.  A subroutine which returns the name of the role as suitable for
displaying to the end user. Will receive as an argument a specific object.

=back

=cut

sub RegisterRole {
    my $self  = shift;
    my $class = ref($self) || $self;
    my %role  = (
        Name                     => undef,
        EquivClasses             => [],
        SortOrder                => 0,
        UserDefined              => 0,
        CreateGroupPredicate     => undef,
        AppliesToObjectPredicate => undef,
        LabelGenerator           => undef,
        @_
    );
    return unless $role{Name};

    # Keep track of the class this role came from originally
    $role{ Class } ||= $class;

    # Some groups are limited to a single user
    $role{ Single } = 1 if $role{Column};

    # Stash the role on ourself
    $class->_ROLES->{ $role{Name} } = { %role };

    # Register it with any equivalent classes...
    my $equiv = delete $role{EquivClasses} || [];

    # ... and globally unless we ARE global
    unless ($class eq "RT::System") {
        push @$equiv, "RT::System";
    }

    # ... marked as "for ACLs only" if flagged as such by the announcing class
    $role{ACLOnly} = 1 if delete $role{ACLOnlyInEquiv};

    $_->RegisterRole(%role) for @$equiv;

    # XXX TODO: Register which classes have roles on them somewhere?

    return 1;
}

=head2 UnregisterRole

Removes an RT role which applies to this class for role-based access control.
Any roles on equivalent classes (via EquivClasses passed to L</RegisterRole>)
are also unregistered.

Takes a role name as the sole argument.

B<Use this carefully:> Objects created after a role is unregistered will not
have an associated L<RT::Group> for the removed role.  If you later decide to
stop unregistering the role, operations on those objects created in the
meantime will fail when trying to interact with the missing role groups.

B<Unregistering a role may break code which assumes the role exists.>

=cut

sub UnregisterRole {
    my $self  = shift;
    my $class = ref($self) || $self;
    my $name  = shift
        or return;

    my $role = delete $self->_ROLES->{$name}
        or return;

    $_->UnregisterRole($name)
        for "RT::System", reverse @{$role->{EquivClasses}};
}

=head2 Role

Takes a role name; returns a hashref describing the role.  This hashref
contains the same attributes used to register the role (see L</RegisterRole>),
as well as some extras, including:

=over

=item Class

The original class which announced the role.  This is set automatically by
L</RegisterRole> and is the same across all EquivClasses.

=back

Returns an empty hashref if the role doesn't exist.

=cut

sub Role {
    return \%{ $_[0]->_ROLES->{$_[1]} || {} };
}

=head2 Roles

Returns a list of role names registered for this object, sorted ascending by
SortOrder and then alphabetically by name.

Optionally takes a hash specifying attributes the returned roles must possess
or lack.  Testing is done on a simple truthy basis and the actual values of
the role attributes and arguments you pass are not compared string-wise or
numerically; they must simply evaluate to the same truthiness.

For example:

    # Return role names which are not only for ACL purposes
    $object->Roles( ACLOnly => 0 );

    # Return role names which are denormalized into a column; note that the
    # role's Column attribute contains a string.
    $object->Roles( Column => 1 );

=cut

sub Roles {
    my $self = shift;
    my %attr = @_;

    return   map { $_->[0] }
            sort {   $a->[1]{SortOrder} <=> $b->[1]{SortOrder}
                  or $a->[0] cmp $b->[0] }
            grep {
                my $ok = 1;
                for my $k (keys %attr) {
                    $ok = 0, last if $attr{$k} xor $_->[1]{$k};
                }
                $ok }
            grep { !$_->[1]{AppliesToObjectPredicate}
                 or $_->[1]{AppliesToObjectPredicate}->($self) }
             map { [ $_, $self->Role($_) ] }
            keys %{ $self->_ROLES };
}

{
    my %ROLES;
    sub _ROLES {
        my $class = ref($_[0]) || $_[0];
        return $ROLES{$class} ||= {};
    }
}

=head2 HasRole

Returns true if the name provided is a registered role for this class.
Otherwise returns false.

=cut

sub HasRole {
    my $self = shift;
    my $type = shift;
    return scalar grep { $type eq $_ } $self->Roles;
}

=head2 RoleGroup

Expects a role name as the first parameter which is used to load the
L<RT::Group> for the specified role on this record.  Returns an unloaded
L<RT::Group> object on failure.

=cut

sub RoleGroup {
    my $self  = shift;
    my $name  = shift;
    my %args  = @_;

    my $group = RT::Group->new( $self->CurrentUser );

    if ($args{CheckRight}) {
        return $group if !$self->CurrentUserHasRight($args{CheckRight});
    }

    if ($self->HasRole($name)) {
        $group->LoadRoleGroup(
            Object  => $self,
            Name    => $name,
        );
    }
    return $group;
}

=head2 CanonicalizePrincipal

Takes some description of a principal (see below) and returns the corresponding
L<RT::Principal>. C<Type>, as in role name, is a required parameter for
producing error messages.

=over 4

=item Principal

The L<RT::Principal> if you've already got it.

=item PrincipalId

The ID of the L<RT::Principal> object.

=item User

The Name or EmailAddress of an L<RT::User>.  If an email address is given, but
a user matching it cannot be found, a new user will be created.

=item Group

The Name of an L<RT::Group>.

=back

=cut

sub CanonicalizePrincipal {
    my $self = shift;
    my %args = (@_);

    return (0, $self->loc("One, and only one, of Principal/PrincipalId/User/Group is required"))
        if 1 != grep { $_ } @args{qw/Principal PrincipalId User Group/};

    if ($args{Principal}) {
        return $args{Principal};
    }
    elsif ($args{PrincipalId}) {
        # Check the PrincipalId for loops
        my $principal = RT::Principal->new( $self->CurrentUser );
        $principal->Load($args{'PrincipalId'});
        if ( $principal->id and $principal->IsUser and my $email = $principal->Object->EmailAddress ) {
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop",
                                  $email, $self->loc($args{Type})))
                if RT::EmailParser->IsRTAddress( $email );
        }
    } else {
        if ($args{User}) {
            my $name = delete $args{User};
            # Sanity check the address
            return (0, $self->loc("[_1] is an address RT receives mail at. Adding it as a '[_2]' would create a mail loop",
                                  $name, $self->loc($args{Type}) ))
                if RT::EmailParser->IsRTAddress( $name );

            # Create as the SystemUser, not the current user
            my $user = RT::User->new(RT->SystemUser);
            my ($ok, $msg);
            if ($name =~ /@/) {
                ($ok, $msg) = $user->LoadOrCreateByEmail( $name );
            } else {
                ($ok, $msg) = $user->Load( $name );
            }
            unless ($user->Id) {
                # If we can't find this watcher, we need to bail.
                $RT::Logger->error("Could not load or create a user '$name' to add as a watcher: $msg");
                return (0, $self->loc("Could not find or create user '[_1]'", $name));
            }
            $args{PrincipalId} = $user->PrincipalId;
        }
        elsif ($args{Group}) {
            my $name = delete $args{Group};
            my $group = RT::Group->new( $self->CurrentUser );
            $group->LoadUserDefinedGroup($name);
            unless ($group->id) {
                $RT::Logger->error("Could not load group '$name' to add as a watcher");
                return (0, $self->loc("Could not find group '[_1]'", $name));
            }
            $args{PrincipalId} = $group->PrincipalObj->id;
        }
    }

    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $args{PrincipalId} );

    return $principal;
}

=head2 AddRoleMember

Adds the described L<RT::Principal> to the specified role group for this record.

Takes a set of key-value pairs:

=over 4

=item Principal, PrincipalId, User, or Group

Required. Canonicalized through L</CanonicalizePrincipal>.

=item Type

Required.  One of the valid roles for this record, as returned by L</Roles>.

=item ACL

Optional.  A subroutine reference which will be passed the role type and
principal being added.  If it returns false, the method will fail with a
status of "Permission denied".

=back

Returns a tuple of (principal object which was added, message).

=cut

sub AddRoleMember {
    my $self = shift;
    my %args = (@_);

    my ($principal, $msg) = $self->CanonicalizePrincipal(%args);
    return (0, $msg) if !$principal;

    my $type = delete $args{Type};
    return (0, $self->loc("That role is invalid for this object"))
        unless $type and $self->HasRole($type);

    my $acl = delete $args{ACL};
    return (0, $self->loc("Permission denied"))
        if $acl and not $acl->($type => $principal);

    my $group = $self->RoleGroup( $type );
    if (!$group->id) {
        $group = $self->_CreateRoleGroup($type);
        if (!$group || !$group->id) {
            return (0, $self->loc("Role group '[_1]' not found", $type));
        }
    }

    return (0, $self->loc('[_1] is already [_2]',
                          $principal->Object->Name, $group->Label) )
            if $group->HasMember( $principal );

    return (0, $self->loc('[_1] cannot be a group', $group->Label) )
                if $group->SingleMemberRoleGroup and $principal->IsGroup;

    ( (my $ok), $msg ) = $group->_AddMember( %args, PrincipalId => $principal->Id, RecordTransaction => !$args{Silent} );
    unless ($ok) {
        $RT::Logger->error("Failed to add principal ".$principal->Id." as a member of group ".$group->Id.": ".$msg);

        return ( 0, $self->loc('Could not make [_1] a [_2]',
                    $principal->Object->Name, $group->Label) );
    }

    return ($principal, $msg);
}

=head2 DeleteRoleMember

Removes the specified L<RT::Principal> from the specified role group for this
record.

Takes a set of key-value pairs:

=over 4

=item PrincipalId

Optional.  The ID of the L<RT::Principal> object to remove.

=item User

Optional.  The Name or EmailAddress of an L<RT::User> to use as the
principal

=item Type

Required.  One of the valid roles for this record, as returned by L</Roles>.

=item ACL

Optional.  A subroutine reference which will be passed the role type and
principal being removed.  If it returns false, the method will fail with a
status of "Permission denied".

=back

One, and only one, of I<PrincipalId> or I<User> is required.

Returns a tuple of (principal object that was removed, message).

=cut

sub DeleteRoleMember {
    my $self = shift;
    my %args = (@_);

    return (0, $self->loc("That role is invalid for this object"))
        unless $args{Type} and $self->HasRole($args{Type});

    if ($args{User}) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->LoadByEmail( $args{User} );
        $user->Load( $args{User} ) unless $user->id;
        return (0, $self->loc("Could not load user '[_1]'", $args{User}) )
            unless $user->id;
        $args{PrincipalId} = $user->PrincipalId;
    }

    return (0, $self->loc("No valid PrincipalId"))
        unless $args{PrincipalId};

    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $args{PrincipalId} );

    my $acl = delete $args{ACL};
    return (0, $self->loc("Permission denied"))
        if $acl and not $acl->($args{Type} => $principal);

    my $group = $self->RoleGroup( $args{Type} );
    return (0, $self->loc("Role group '[_1]' not found", $args{Type}))
        unless $group->id;

    return ( 0, $self->loc( '[_1] is not a [_2]',
                            $principal->Object->Name, $self->loc($args{Type}) ) )
        unless $group->HasMember($principal);

    my ($ok, $msg) = $group->_DeleteMember($args{PrincipalId}, RecordTransaction => !$args{Silent});
    unless ($ok) {
        $RT::Logger->error("Failed to remove $args{PrincipalId} as a member of group ".$group->Id.": ".$msg);

        return ( 0, $self->loc('Could not remove [_1] as a [_2]',
                    $principal->Object->Name, $self->loc($args{Type})) );
    }

    return ($principal, $msg);
}

sub _ResolveRoles {
    my $self = shift;
    my ($roles, %args) = (@_);

    my @errors;
    for my $role ($self->Roles) {
        if ($self->_ROLES->{$role}{Single}) {
            # Default to nobody if unspecified
            my $value = $args{$role} || RT->Nobody;
               $value = $value->[0] if ref $value eq 'ARRAY';
            if (Scalar::Util::blessed($value) and $value->isa("RT::User")) {
                # Accept a user; it may not be loaded, which we catch below
                $roles->{$role} = $value->PrincipalObj;
            } else {
                # Try loading by id, name, then email.  If all fail, catch that below
                my $user = RT::User->new( $self->CurrentUser );
                $user->Load( $value );
                # XXX: LoadOrCreateByEmail ?
                $user->LoadByEmail( $value ) unless $user->id;
                $roles->{$role} = $user->PrincipalObj;
            }
            unless (Scalar::Util::blessed($roles->{$role}) and $roles->{$role}->id) {
                push @errors, $self->loc("Invalid value for [_1]",$self->loc($role));
                $roles->{$role} = RT->Nobody->PrincipalObj;
            }
            # For consistency, we always return an arrayref
            $roles->{$role} = [ $roles->{$role} ];
        } else {
            $roles->{$role} = [];
            my @values = ref $args{ $role } ? @{ $args{$role} } : ($args{$role});
            for my $value (grep {defined} @values) {
                if ( $value =~ /^\d+$/ ) {
                    # This implicitly allows groups, if passed by id.
                    my $principal = RT::Principal->new( $self->CurrentUser );
                    my ($ok, $msg) = $principal->Load( $value );
                    if ($ok) {
                        push @{ $roles->{$role} }, $principal;
                    } else {
                        push @errors,
                            $self->loc("Couldn't load principal: [_1]", $msg);
                    }
                } else {
                    my @addresses = RT::EmailParser->ParseEmailAddress( $value );
                    for my $address ( @addresses ) {
                        my $user = RT::User->new( RT->SystemUser );
                        my ($id, $msg) = $user->LoadOrCreateByEmail( $address );
                        if ( $id ) {
                            # Load it back as us, not as the system
                            # user, to be completely safe.
                            $user = RT::User->new( $self->CurrentUser );
                            $user->Load( $id );
                            push @{ $roles->{$role} }, $user->PrincipalObj;
                        } else {
                            push @errors,
                                $self->loc("Couldn't load or create user: [_1]", $msg);
                        }
                    }
                }
            }
        }
    }
    return (@errors);
}

sub _CreateRoleGroup {
    my $self = shift;
    my $name = shift;
    my %args = (
        @_,
    );

    my $role = $self->Role($name);

    my %create = (
        Name    => $name,
        Object  => $self,
        %args,
    );

    return (0) if $role->{CreateGroupPredicate}
               && !$role->{CreateGroupPredicate}->(%create);

    my $type_obj = RT::Group->new($self->CurrentUser);
    my ($id, $msg) = $type_obj->CreateRoleGroup(%create);

    unless ($id) {
        $RT::Logger->error("Couldn't create a role group of type '$name' for ".ref($self)." ".
                               $self->id.": ".$msg);
        return(undef);
    }

    return $type_obj;
}

sub _CreateRoleGroups {
    my $self = shift;
    my %args = (@_);
    for my $name ($self->Roles) {
        my ($ok) = $self->_CreateRoleGroup($name, %args);
        return(undef) if !$ok;
    }
    return(1);
}

sub _AddRolesOnCreate {
    my $self = shift;
    my ($roles, %acls) = @_;

    my @errors;
    {
        my $changed = 0;

        for my $role (keys %{$roles}) {
            my $group = $self->RoleGroup($role);
            my @left;
            for my $principal (@{$roles->{$role}}) {
                if ($acls{$role}->($principal)) {
                    next if $group->HasMember($principal);
                    my ($ok, $msg) = $group->_AddMember(
                        PrincipalId       => $principal->id,
                        InsideTransaction => 1,
                        RecordTransaction => 0,
                        Object            => $self,
                    );
                    push @errors, $self->loc("Couldn't set [_1] watcher: [_2]", $role, $msg)
                        unless $ok;
                    $changed++;
                } else {
                    push @left, $principal;
                }
            }
            $roles->{$role} = [ @left ];
        }

        redo if $changed;
    }

    return @errors;
}

=head2 LabelForRole

Returns a label suitable for displaying the passed-in role to an end user.

=cut

sub LabelForRole {
    my $self = shift;
    my $name = shift;
    my $role = $self->Role($name);
    if ($role->{LabelGenerator}) {
        return $role->{LabelGenerator}->($self);
    }
    return $role->{Name};
}


1;
