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
=head1 NAME

  RT::Model::Groups - a collection of RT::Model::Group objects

=head1 SYNOPSIS

  use RT::Model::Groups;
  my $groups = RT::Model::Groups->new($CurrentUser);
  $groups->find_all_rows();
  while (my $group = $groups->next()) {
     print $group->id ." is a group id\n";
  }

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Model::Groups;

use strict;
no warnings qw(redefine);

use RT::Model::Users;

# XXX: below some code is marked as subject to generalize in Groups, Users classes.
# RUZ suggest name Principals::Generic or Principals::Base as abstract class, but
# Jesse wants something that doesn't imply it's a Principals.pm subclass.
# See comments below for candidats.


# {{{ sub _init

sub _init { 
  my $self = shift;
  $self->{'table'} = "Groups";
  $self->{'primary_key'} = "id";

  my @result = $self->SUPER::_init(@_);

  $self->order_by( alias => 'main',
		  column => 'Name',
		  order => 'ASC');

  # XXX: this code should be generalized
  $self->{'princalias'} = $self->join(
    alias1 => 'main',
    column1 => 'id',
    table2 => 'Principals',
    column2 => 'id'
  );

  # even if this condition is useless and ids in the Groups table
  # only match principals with type 'Group' this could speed up
  # searches in some DBs.
  $self->limit( alias => $self->{'princalias'},
                column => 'PrincipalType',
                value => 'Group',
              );

  return (@result);
}
# }}}

=head2 PrincipalsAlias

Returns the string that represents this Users object's primary "Principals" alias.

=cut

# XXX: should be generalized, code duplication
sub PrincipalsAlias {
    my $self = shift;
    return($self->{'princalias'});

}


# {{{ LimiToSystemInternalGroups

=head2 LimitToSystemInternalGroups

Return only SystemInternal Groups, such as "privileged" "unprivileged" and "everyone" 

=cut


sub LimitToSystemInternalGroups {
    my $self = shift;
    $self->limit(column => 'Domain', operator => '=', value => 'SystemInternal');
    # All system internal groups have the same instance. No reason to limit down further
    #$self->limit(column => 'Instance', operator => '=', value => '0');
}


# }}}

# {{{ LimiToUserDefinedGroups

=head2 LimitToUserDefined Groups

Return only UserDefined Groups

=cut


sub LimitToUserDefinedGroups {
    my $self = shift;
    $self->limit(column => 'Domain', operator => '=', value => 'UserDefined');
    # All user-defined groups have the same instance. No reason to limit down further
    #$self->limit(column => 'Instance', operator => '=', value => '');
}


# }}}

# {{{ LimiToPersonalGroups

=head2 LimitToPersonalGroupsFor PRINCIPAL_ID

Return only Personal Groups for the user whose principal id 
is PRINCIPAL_ID

=cut


sub LimitToPersonalGroupsFor {
    my $self = shift;
    my $princ = shift;

    $self->limit(column => 'Domain', operator => '=', value => 'Personal');
    $self->limit(   column => 'Instance',   
                    operator => '=', 
                    value => $princ);
}


# }}}

# {{{ LimitToRolesForQueue

=head2 LimitToRolesForQueue QUEUE_ID

Limits the set of groups found to role groups for queue QUEUE_ID

=cut

sub LimitToRolesForQueue {
    my $self = shift;
    my $queue = shift;
    $self->limit(column => 'Domain', operator => '=', value => 'RT::Model::Queue-Role');
    $self->limit(column => 'Instance', operator => '=', value => $queue);
}

# }}}

# {{{ LimitToRolesForTicket

=head2 LimitToRolesForTicket Ticket_ID

Limits the set of groups found to role groups for Ticket Ticket_ID

=cut

sub LimitToRolesForTicket {
    my $self = shift;
    my $Ticket = shift;
    $self->limit(column => 'Domain', operator => '=', value => 'RT::Model::Ticket-Role');
    $self->limit(column => 'Instance', operator => '=', value => '$Ticket');
}

# }}}

# {{{ LimitToRolesForSystem

=head2 LimitToRolesForSystem System_ID

Limits the set of groups found to role groups for System System_ID

=cut

sub LimitToRolesForSystem {
    my $self = shift;
    $self->limit(column => 'Domain', operator => '=', value => 'RT::System-Role');
}

# }}}

=head2 WithMember {PrincipalId => PRINCIPAL_ID, Recursively => undef}

Limits the set of groups returned to groups which have
Principal PRINCIPAL_ID as a member
   


=cut

sub WithMember {
    my $self = shift;
    my %args = ( PrincipalId => undef,
                 Recursively => undef,
                 @_);
    my $members;

    if ($args{'Recursively'}) {
        $members = $self->new_alias('CachedGroupMembers');
    } else {
        $members = $self->new_alias('GroupMembers');
    }
    $self->join(alias1 => 'main', column1 => 'id',
                alias2 => $members, column2 => 'GroupId');

    $self->limit(alias => $members, column => 'MemberId', operator => '=', value => $args{'PrincipalId'});
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

    my $from_role = $self->clone;
    $from_role->WithRoleRight( %args );

    my $from_group = $self->clone;
    $from_group->WithGroupRight( %args );

    #XXX: DIRTY HACK
    use Jifty::DBI::Collection::Union;
    my $union = new Jifty::DBI::Collection::Union;
    $union->add($from_role);
    $union->add($from_group);
    %$self = %$union;
    bless $self, ref($union);

    return;
}

#XXX: methods are active aliases to Users class to prevent code duplication
# should be generalized
sub _joinGroups {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'IncludeSubgroupMembers'};
    return $self->RT::Model::Users::_joinGroups( %args );
}
sub _joinGroupMembers {
    my $self = shift;
    my %args = (@_);
    return 'main' unless $args{'IncludeSubgroupMembers'};
    return $self->RT::Model::Users::_joinGroupMembers( %args );
}
sub _joinGroupMembersForGroupRights {
    my $self = shift;
    my %args = (@_);
    my $group_members = $self->_joinGroupMembers( %args );
    unless( $group_members eq 'main' ) {
        return $self->RT::Model::Users::_joinGroupMembersForGroupRights( %args );
    }
    $self->limit( alias => $args{'ACLAlias'},
                  column => 'PrincipalId',
                  value => "main.id",
                  quote_value => 0,
                );
}
sub _joinACL          { return (shift)->RT::Model::Users::_joinACL( @_ ) }
sub _GetEquivObjects  { return (shift)->RT::Model::Users::_GetEquivObjects( @_ ) }
sub WithGroupRight    { return (shift)->RT::Model::Users::WhoHaveGroupRight( @_ ) }
sub WithRoleRight     { return (shift)->RT::Model::Users::WhoHaveRoleRight( @_ ) }

# {{{ sub LimitToEnabled

=head2 LimitToEnabled

Only find items that haven\'t been disabled

=cut

sub LimitToEnabled {
    my $self = shift;
    
    $self->limit( alias => $self->PrincipalsAlias,
		          column => 'Disabled',
		          value => '0',
		          operator => '=',
                );
}
# }}}

# {{{ sub LimitToDisabled

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    $self->{'find_disabled_rows'} = 1;
    $self->limit( alias => $self->PrincipalsAlias,
                  column => 'Disabled',
                  operator => '=',
                  value => 1,
                );
}
# }}}

# {{{ sub Next

sub Next {
    my $self = shift;

    # Don't show groups which the user isn't allowed to see.

    my $Group = $self->SUPER::Next();
    if ((defined($Group)) and (ref($Group))) {
	unless ($Group->current_user_has_right('SeeGroup')) {
	    return $self->next();
	}
	
	return $Group;
    }
    else {
	return undef;
    }
}



sub _do_search {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_disabled_rows'}) {
	$self->LimitToEnabled();
    }
    
    return($self->SUPER::_do_search(@_));
    
}

1;

