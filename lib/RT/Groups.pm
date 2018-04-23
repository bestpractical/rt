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

=head1 NAME

  RT::Groups - a collection of RT::Group objects

=head1 SYNOPSIS

  use RT::Groups;
  my $groups = RT::Groups->new($CurrentUser);
  $groups->UnLimit();
  while (my $group = $groups->Next()) {
     print $group->Id ." is a group id\n";
  }

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Groups;

use strict;
use warnings;

use base 'RT::SearchBuilder';

sub Table { 'Groups'}

use RT::Group;
use RT::Users;

# XXX: below some code is marked as subject to generalize in Groups, Users classes.
# RUZ suggest name Principals::Generic or Principals::Base as abstract class, but
# Jesse wants something that doesn't imply it's a Principals.pm subclass.
# See comments below for candidats.



sub _Init { 
  my $self = shift;
  $self->{'with_disabled_column'} = 1;

  my @result = $self->SUPER::_Init(@_);

  $self->OrderBy( ALIAS => 'main',
                  FIELD => 'Name',
                  ORDER => 'ASC');

  # XXX: this code should be generalized
  $self->{'princalias'} = $self->Join(
    ALIAS1 => 'main',
    FIELD1 => 'id',
    TABLE2 => 'Principals',
    FIELD2 => 'id'
  );

  # even if this condition is useless and ids in the Groups table
  # only match principals with type 'Group' this could speed up
  # searches in some DBs.
  $self->Limit( ALIAS => $self->{'princalias'},
                FIELD => 'PrincipalType',
                VALUE => 'Group',
              );

  return (@result);
}

=head2 PrincipalsAlias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized, code duplication
sub PrincipalsAlias {
    my $self = shift;
    return($self->{'princalias'});

}



=head2 LimitToSystemInternalGroups

Return only SystemInternal Groups, such as "privileged" "unprivileged" and "everyone" 

=cut


sub LimitToSystemInternalGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'SystemInternal', CASESENSITIVE => 0 );
    # All system internal groups have the same instance. No reason to limit down further
    #$self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '0');
}




=head2 LimitToUserDefinedGroups

Return only UserDefined Groups

=cut


sub LimitToUserDefinedGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'UserDefined', CASESENSITIVE => 0 );
    # All user-defined groups have the same instance. No reason to limit down further
    #$self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
}

=head2 LimitToRolesForObject OBJECT

Limits the set of groups to role groups specifically for the object in question
based on the object's class and ID.  If the object has no ID, the roles are not
limited by group C<Instance>.  That is, calling this method on an unloaded
object will find all role groups for that class of object.

Replaces L</LimitToRolesForQueue>, L</LimitToRolesForTicket>, and
L</LimitToRolesForSystem>.

=cut

sub LimitToRolesForObject {
    my $self   = shift;
    my $object = shift;
    $self->Limit(FIELD => 'Domain',   OPERATOR => '=', VALUE => ref($object) . "-Role", CASESENSITIVE => 0 );
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => $object->id);
}

=head2 WithMember {PrincipalId => PRINCIPAL_ID, Recursively => undef}

Limits the set of groups returned to groups which have
Principal PRINCIPAL_ID as a member. Returns the alias used for the join.

=cut

sub WithMember {
    my $self = shift;
    my %args = ( PrincipalId => undef,
                 Recursively => undef,
                 @_);
    my $members = $self->Join(
        ALIAS1 => 'main', FIELD1 => 'id',
        $args{'Recursively'}
            ? (TABLE2 => 'CachedGroupMembers')
            # (GroupId, MemberId) is unique in GM table
            : (TABLE2 => 'GroupMembers', DISTINCT => 1)
        ,
        FIELD2 => 'GroupId',
    );

    $self->Limit(ALIAS => $members, FIELD => 'MemberId', OPERATOR => '=', VALUE => $args{'PrincipalId'});
    $self->Limit(ALIAS => $members, FIELD => 'Disabled', VALUE => 0)
        if $args{'Recursively'};

    return $members;
}

sub WithCurrentUser {
    my $self = shift;
    $self->{with_current_user} = 1;
    return $self->WithMember(
        PrincipalId => $self->CurrentUser->PrincipalId,
        Recursively => 1,
    );
}

sub WithoutMember {
    my $self = shift;
    my %args = (
        PrincipalId => undef,
        Recursively => undef,
        @_
    );

    my $members = $args{'Recursively'} ? 'CachedGroupMembers' : 'GroupMembers';
    my $members_alias = $self->Join(
        TYPE   => 'LEFT',
        FIELD1 => 'id',
        TABLE2 => $members,
        FIELD2 => 'GroupId',
        DISTINCT => $members eq 'GroupMembers',
    );
    $self->Limit(
        LEFTJOIN => $members_alias,
        ALIAS    => $members_alias,
        FIELD    => 'MemberId',
        OPERATOR => '=',
        VALUE    => $args{'PrincipalId'},
    );
    $self->Limit(
        LEFTJOIN => $members_alias,
        ALIAS    => $members_alias,
        FIELD    => 'Disabled',
        VALUE    => 0
    ) if $args{'Recursively'};
    $self->Limit(
        ALIAS    => $members_alias,
        FIELD    => 'MemberId',
        OPERATOR => 'IS',
        VALUE    => 'NULL',
        QUOTEVALUE => 0,
    );
}

=head2 WithRight { Right => RIGHTNAME, Object => RT::Record, IncludeSystemRights => 1, IncludeSuperusers => 0, EquivObjects => [ ] }


Find all groups which have RIGHTNAME for RT::Record. Optionally include global rights and superusers. By default, include the global rights, but not the superusers.



=cut

#XXX: should be generilized
sub WithRight {
    my $self = shift;
    my %args = ( Right                  => undef,
                 Object =>              => undef,
                 IncludeSystemRights    => 1,
                 IncludeSuperusers      => undef,
                 IncludeSubgroupMembers => 0,
                 EquivObjects           => [ ],
                 @_ );

    my $from_role = $self->Clone;
    $from_role->WithRoleRight( %args );

    my $from_group = $self->Clone;
    $from_group->WithGroupRight( %args );

    #XXX: DIRTY HACK
    use DBIx::SearchBuilder::Union;
    my $union = DBIx::SearchBuilder::Union->new();
    $union->add($from_role);
    $union->add($from_group);
    %$self = %$union;
    bless $self, ref($union);

    return;
}

#XXX: methods are active aliases to Users class to prevent code duplication
# should be generalized
sub _JoinGroups {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'IncludeSubgroupMembers'};
    return $self->RT::Users::_JoinGroups( %args );
}
sub _JoinGroupMembers {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'IncludeSubgroupMembers'};
    return $self->RT::Users::_JoinGroupMembers( %args );
}
sub _JoinGroupMembersForGroupRights {
    my $self = shift;
    my %args = (@_);
    my $group_members = $self->_JoinGroupMembers( %args );
    unless( $group_members eq 'main' ) {
        return $self->RT::Users::_JoinGroupMembersForGroupRights( %args );
    }
    $self->Limit( ALIAS => $args{'ACLAlias'},
                  FIELD => 'PrincipalId',
                  VALUE => "main.id",
                  QUOTEVALUE => 0,
                );
}
sub _JoinACL                  { return (shift)->RT::Users::_JoinACL( @_ ) }
sub _RoleClauses              { return (shift)->RT::Users::_RoleClauses( @_ ) }
sub _WhoHaveRoleRightSplitted { return (shift)->RT::Users::_WhoHaveRoleRightSplitted( @_ ) }
sub _GetEquivObjects          { return (shift)->RT::Users::_GetEquivObjects( @_ ) }
sub WithGroupRight            { return (shift)->RT::Users::WhoHaveGroupRight( @_ ) }
sub WithRoleRight             { return (shift)->RT::Users::WhoHaveRoleRight( @_ ) }

sub ForWhichCurrentUserHasRight {
    my $self = shift;
    my %args = (
        Right => undef,
        IncludeSuperusers => undef,
        @_,
    );

    # Non-disabled groups...
    $self->LimitToEnabled;

    # ...which are the target object of an ACL with that right, or
    # where the target is the system object (a global right)
    my $acl = $self->_JoinACL( %args );
    $self->_AddSubClause(
        ACLObjects => "( (main.id = $acl.ObjectId AND $acl.ObjectType = 'RT::Group')"
                   . " OR $acl.ObjectType = 'RT::System')");

    # ...and where that right is granted to any group..
    my $member = $self->Join(
        ALIAS1 => $acl,
        FIELD1 => 'PrincipalId',
        TABLE2 => 'CachedGroupMembers',
        FIELD2 => 'GroupId',
    );
    $self->Limit(
        ALIAS => $member,
        FIELD => 'Disabled',
        VALUE => '0',
    );

    # ...with the current user in it
    $self->Limit(
        ALIAS => $member,
        FIELD => 'MemberId',
        VALUE => $self->CurrentUser->Id,
    );

    return;
}

=head2 LimitToEnabled

Only find items that haven't been disabled

=cut

sub LimitToEnabled {
    my $self = shift;

    $self->{'handled_disabled_column'} = 1;
    $self->Limit(
        ALIAS => $self->PrincipalsAlias,
        FIELD => 'Disabled',
        VALUE => '0',
    );
}


=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    $self->{'handled_disabled_column'} = $self->{'find_disabled_rows'} = 1;
    $self->Limit(
        ALIAS => $self->PrincipalsAlias,
        FIELD => 'Disabled',
        VALUE => 1,
    );
}



sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    # If we've explicitly limited to groups the user is a member of (for
    # dashboard or savedsearch privacy objects), skip the ACL.
    return unless $self->{with_current_user}
        or $record->CurrentUserHasRight('SeeGroup');

    return $self->SUPER::AddRecord( $record );
}



sub _DoSearch {
    my $self = shift;

    #unless we really want to find disabled rows, make sure we're only finding enabled ones.
    unless($self->{'find_disabled_rows'}) {
        $self->LimitToEnabled();
    }

    return($self->SUPER::_DoSearch(@_));

}

RT::Base->_ImportOverlays();

1;
