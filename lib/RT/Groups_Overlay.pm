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
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
}


# }}}

# {{{ LimiToUserDefinedGroups

=head2 LimitToUserDefined Groups

Return only UserDefined Groups

=cut


sub LimitToUserDefinedGroups {
    my $self = shift;
    $self->Limit(FIELD => 'Domain', OPERATOR => '=', VALUE => 'UserDefined');
    $self->Limit(FIELD => 'Instance', OPERATOR => '=', VALUE => '');
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
    $self->Join(ALIAS1 => 'main', FIELD1 => 'Id',
                ALIAS2 => $members, FIELD2 => 'GroupId');

    $self->Limit(ALIAS => $members, FIELD => 'MemberId', OPERATOR => '=', VALUE => $args{'PrincipalId'});
}

1;

