# {{{ BEGIN BPS TAGGED BLOCK
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2004 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
# }}} END BPS TAGGED BLOCK
=head1 NAME

  RT::Groups - a collection of RT::Group objects

=head1 SYNOPSIS

  use RT::Groups;
  my $groups = $RT::Groups->new($CurrentUser);
  $groups->LimitToReal();
  while (my $group = $groups->Next()) {
     print $group->Id ." is a group id\n";
  }

=head1 DESCRIPTION


=head1 METHODS


=begin testing

ok (require RT::Groups);

=end testing

=cut

use strict;
no warnings qw(redefine);


# {{{ sub _Init

sub _Init { 
  my $self = shift;
  $self->{'table'} = "Groups";
  $self->{'primary_key'} = "id";

  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Name',
		  ORDER => 'ASC');


  return ( $self->SUPER::_Init(@_));
}
# }}}

# {{{ LimiToSystemInternalGroups

=head2 LimitToSystemInternalGroups

Return only SystemInternal Groups, such as "privileged" "unprivileged" and "everyone" 

=cut


sub LimitToSystemInternalGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'SystemInternal');
    # All system internal groups have the same instance. No reason to limit down further
    #$self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '0');
}


# }}}

# {{{ LimiToUserDefinedGroups

=head2 LimitToUserDefined Groups

Return only UserDefined Groups

=cut


sub LimitToUserDefinedGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'UserDefined');
    # All user-defined groups have the same instance. No reason to limit down further
    #$self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
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

    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'Personal');
    $self->Limit(   FIELD => 'Instance',   
                    OPERATOR => '=', 
                    VALUE => $princ,
                    ENTRY_AGGREGATOR => 'OR');
}


# }}}

# {{{ LimitToRolesForQueue

=item LimitToRolesForQueue QUEUE_ID

Limits the set of groups found to role groups for queue QUEUE_ID

=cut

sub LimitToRolesForQueue {
    my $self = shift;
    my $queue = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'RT::Queue-Role');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => $queue);
}

# }}}

# {{{ LimitToRolesForTicket

=item LimitToRolesForTicket Ticket_ID

Limits the set of groups found to role groups for Ticket Ticket_ID

=cut

sub LimitToRolesForTicket {
    my $self = shift;
    my $Ticket = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'RT::Ticket-Role');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '$Ticket');
}

# }}}

# {{{ LimitToRolesForSystem

=item LimitToRolesForSystem System_ID

Limits the set of groups found to role groups for System System_ID

=cut

sub LimitToRolesForSystem {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'RT::System-Role');
}

# }}}

=head2 WithMember {PrincipalId => PRINCIPAL_ID, Recursively => undef}

Limits the set of groups returned to groups which have
Principal PRINCIPAL_ID as a member
   
=begin testing

my $u = RT::User->new($RT::SystemUser);
$u->Create(Name => 'Membertests');
my $g = RT::Group->new($RT::SystemUser);
my ($id, $msg) = $g->CreateUserDefinedGroup(Name => 'Membertests');
ok ($id,$msg);

my ($aid, $amsg) =$g->AddMember($u->id);
ok ($aid, $amsg);
ok($g->HasMember($u->PrincipalObj),"G has member u");

my $groups = RT::Groups->new($RT::SystemUser);
$groups->LimitToUserDefinedGroups();
$groups->WithMember(PrincipalId => $u->id);
ok ($groups->Count == 1,"found the 1 group - " . $groups->Count);
ok ($groups->First->Id == $g->Id, "it's the right one");




=end testing


=cut

sub WithMember {
    my $self = shift;
    my %args = ( PrincipalId => undef,
                 Recursively => undef,
                 @_);
    my $members;

    if ($args{'Recursively'}) {
        $members = $self->NewAlias('CachedGroupMembers');
    } else {
        $members = $self->NewAlias('GroupMembers');
    }
    $self->Join(ALIAS1 => 'main', FIELD1 => 'id',
                ALIAS2 => $members, FIELD2 => 'GroupId');

    $self->Limit(ALIAS => $members, FIELD => 'MemberId', OPERATOR => '=', VALUE => $args{'PrincipalId'});
}


=head2 WithRight { Right => RIGHTNAME, Object => RT::Record, IncludeSystemRights => 1, IncludeSuperusers => 0 }


Find all groups which have RIGHTNAME for RT::Record. Optionally include global rights and superusers. By default, include the global rights, but not the superusers.

=begin testing

my $q = RT::Queue->new($RT::SystemUser);
my ($id, $msg) =$q->Create( Name => 'GlobalACLTest');
ok ($id, $msg);

my $testuser = RT::User->new($RT::SystemUser);
($id,$msg) = $testuser->Create(Name => 'JustAnAdminCc');
ok ($id,$msg);

my $global_admin_cc = RT::Group->new($RT::SystemUser);
$global_admin_cc->LoadSystemRoleGroup('AdminCc');
ok($global_admin_cc->id, "Found the global admincc group");
my $groups = RT::Groups->new($RT::SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
is($groups->Count, 1);
($id, $msg) = $global_admin_cc->PrincipalObj->GrantRight(Right =>'OwnTicket', Object=> $RT::System);
ok ($id,$msg);
ok (!$testuser->HasRight(Object => $q, Right => 'OwnTicket') , "The test user does not have the right to own tickets in the test queue");
($id, $msg) = $q->AddWatcher(Type => 'AdminCc', PrincipalId => $testuser->id);
ok($id,$msg);
ok ($testuser->HasRight(Object => $q, Right => 'OwnTicket') , "The test user does have the right to own tickets now. thank god.");

$groups = RT::Groups->new($RT::SystemUser);
$groups->WithRight(Right => 'OwnTicket', Object => $q);
ok ($id,$msg);
is($groups->Count, 2);

=end testing


=cut


sub WithRight {
    my $self = shift;
    my %args = ( Right                  => undef,
                 Object =>              => undef,
                 IncludeSystemRights    => 1,
                 IncludeSuperusers      => undef,
                 @_ );

    my $acl        = $self->NewAlias('ACL');

    # {{{ Find only rows where the right granted is the one we're looking up or _possibly_ superuser 
    $self->Limit( ALIAS           => $acl,
                  FIELD           => 'RightName',
                  OPERATOR        => ($args{Right} ? '=' : 'IS NOT'),
                  VALUE           => $args{Right} || 'NULL',
                  ENTRYAGGREGATOR => 'OR' );

    if ( $args{'IncludeSuperusers'} and $args{'Right'} ) {
        $self->Limit( ALIAS           => $acl,
                      FIELD           => 'RightName',
                      OPERATOR        => '=',
                      VALUE           => 'SuperUser',
                      ENTRYAGGREGATOR => 'OR' );
    }
    # }}}

    my ($or_check_ticket_roles, $or_check_roles);
    my $which_object = "$acl.ObjectType = 'RT::System'";

    if ( defined $args{'Object'} ) {
        if ( ref($args{'Object'}) eq 'RT::Ticket' ) {
            $or_check_ticket_roles =
                " OR ( main.Domain = 'RT::Ticket-Role' AND main.Instance = " . $args{'Object'}->Id . ") ";

            # If we're looking at ticket rights, we also want to look at the associated queue rights.
            # this is a little bit hacky, but basically, now that we've done the ticket roles magic,
            # we load the queue object and ask all the rest of our questions about the queue.
            $args{'Object'}   = $args{'Object'}->QueueObj;
        }
        # TODO XXX This really wants some refactoring
        if ( ref($args{'Object'}) eq 'RT::Queue' ) {
            $or_check_roles =
                " OR ( ( (main.Domain = 'RT::Queue-Role' AND main.Instance = " .
                $args{'Object'}->Id . ") $or_check_ticket_roles ) " .
                " AND main.Type = $acl.PrincipalType) ";
        }

	if ( $args{'IncludeSystemRights'} ) {
	    $which_object .= ' OR ';
	}
	else {
	    $which_object = '';
	}
        $which_object .=
            " ($acl.ObjectType = '" . ref($args{'Object'}) . "'" .
            " AND $acl.ObjectId = " . $args{'Object'}->Id . ") ";
    }

    $self->_AddSubClause( "WhichObject", "($which_object)" );

    $self->_AddSubClause( "WhichGroup",
        qq{
          ( (    $acl.PrincipalId = main.id
             AND $acl.PrincipalType = 'Group'
             AND (   main.Domain = 'SystemInternal'
                  OR main.Domain = 'UserDefined'
                  OR main.Domain = 'ACLEquivalence'))
           $or_check_roles)
        }
    );
}

# {{{ sub LimitToEnabled

=head2 LimitToEnabled

Only find items that haven\'t been disabled

=cut

sub LimitToEnabled {
    my $self = shift;
    
    my $alias = $self->Join(
	TYPE   => 'left',
	ALIAS1 => 'main',
	FIELD1 => 'id',
	TABLE2 => 'Principals',
	FIELD2 => 'id'
    );

    $self->Limit( ALIAS => $alias,
		  FIELD => 'Disabled',
		  VALUE => '0',
		  OPERATOR => '=' );
}
# }}}

# {{{ sub LimitToDisabled

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    my $alias = $self->Join(
	TYPE   => 'left',
	ALIAS1 => 'main',
	FIELD1 => 'id',
	TABLE2 => 'Principals',
	FIELD2 => 'id'
    );

    $self->{'find_disabled_rows'} = 1;
    $self->Limit( ALIAS => $alias,
		  FIELD => 'Disabled',
		  OPERATOR => '=',
		  VALUE => '1'
		);
}
# }}}

sub _DoSearch {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_disabled_rows'}) {
	$self->LimitToEnabled();
    }
    
    return($self->SUPER::_DoSearch(@_));
    
}

1;

