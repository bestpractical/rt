# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::Users - Collection of RT::User objects

=head1 SYNOPSIS

  use RT::Users;


=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::Users);

=end testing

=cut


package RT::Users;

use strict;
no warnings qw(redefine);

# {{{ sub _Init 
sub _Init {
    my $self = shift;
    $self->{'table'} = 'Users';
        $self->{'primary_key'} = 'id';



    my @result =          $self->SUPER::_Init(@_);
    # By default, order by name
    $self->OrderBy( ALIAS => 'main',
                    FIELD => 'Name',
                    ORDER => 'ASC' );

    $self->{'princalias'} = $self->NewAlias('Principals');

    $self->Join( ALIAS1 => 'main',
                 FIELD1 => 'id',
                 ALIAS2 => $self->{'princalias'},
                 FIELD2 => 'id' );

    return (@result);
}

# }}}

=head2 PrincipalsAlias

Returns the string that represents this Users object's primary "Principals" alias.


=cut

sub PrincipalsAlias {
    my $self = shift;
    return($self->{'princalias'});

}


# {{{ sub _DoSearch 

=head2 _DoSearch

  A subclass of DBIx::SearchBuilder::_DoSearch that makes sure that _Disabled rows never get seen unless
we're explicitly trying to see them.

=cut

sub _DoSearch {
    my $self = shift;

    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->LimitToEnabled();
    }
    return ( $self->SUPER::_DoSearch(@_) );

}

# }}}
# {{{ sub LimitToEnabled

=head2 LimitToEnabled

Only find items that haven\'t been disabled

=cut

sub LimitToEnabled {
    my $self = shift;

    $self->Limit( ALIAS    => $self->{'princalias'},
                  FIELD    => 'Disabled',
                  VALUE    => '0',
                  OPERATOR => '=' );
}

# }}}

# {{{ LimitToEmail

=head2 LimitToEmail

Takes one argument. an email address. limits the returned set to
that email address

=cut

sub LimitToEmail {
    my $self = shift;
    my $addr = shift;
    $self->Limit( FIELD => 'EmailAddress', VALUE => "$addr" );
}

# }}}

# {{{ MemberOfGroup

=head2 MemberOfGroup PRINCIPAL_ID

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub MemberOfGroup {
    my $self  = shift;
    my $group = shift;

    return $self->loc("No group specified") if ( !defined $group );

    my $groupalias = $self->NewAlias('CachedGroupMembers');

    # Join the principal to the groups table
    $self->Join( ALIAS1 => $self->{'princalias'},
                 FIELD1 => 'id',
                 ALIAS2 => $groupalias,
                 FIELD2 => 'MemberId' );

    $self->Limit( ALIAS    => "$groupalias",
                  FIELD    => 'GroupId',
                  VALUE    => "$group",
                  OPERATOR => "=" );
}

# }}}

# {{{ LimitToPrivileged

=head2 LimitToPrivileged

Limits to users who can be made members of ACLs and groups

=cut

sub LimitToPrivileged {
    my $self = shift;

    my $priv = RT::Group->new( $self->CurrentUser );
    $priv->LoadSystemInternalGroup('Privileged');
    unless ( $priv->Id ) {
        $RT::Logger->crit("Couldn't find a privileged users group");
    }
    $self->MemberOfGroup( $priv->PrincipalId );
}

# }}}

# {{{ WhoHaveRight

=head2 WhoHaveRight { Right => 'name', Object => $rt_object , IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef, EquivObjects => [ ] }

=begin testing

ok(my $users = RT::Users->new($RT::SystemUser));
$users->WhoHaveRight(Object =>$RT::System, Right =>'SuperUser');
ok($users->Count == 1, "There is one privileged superuser - Found ". $users->Count );
# TODO: this wants more testing

my $RTxUser = RT::User->new($RT::SystemUser);
($id, $msg) = $RTxUser->Create( Name => 'RTxUser', Comments => "RTx extension user", Privileged => 1);
ok ($id,$msg);

my $group = RT::Group->new($RT::SystemUser);
$group->LoadACLEquivalenceGroup($RTxUser->PrincipalObj);

my $RTxSysObj = {};
bless $RTxSysObj, 'RTx::System';
*RTx::System::Id = sub { 1; };
*RTx::System::id = *RTx::System::Id;
my $ace = RT::Record->new($RT::SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($_TABLE_ATTR->{ref($self)});
($id, $msg) = $ace->Create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System', ObjectId  => 1 );
ok ($id, "ACL for RTxSysObj created");

my $RTxObj = {};
bless $RTxObj, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 4; };
*RTx::System::Record::id = *RTx::System::Record::Id;

$users = RT::Users->new($RT::SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxSysObj);
is($users->Count, 1, "RTxUserRight found for RTxSysObj");

$users = RT::Users->new($RT::SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj);
is($users->Count, 0, "RTxUserRight not found for RTxObj");

$users = RT::Users->new($RT::SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj, EquivObjects => [ $RTxSysObj ]);
is($users->Count, 1, "RTxUserRight found for RTxObj using EquivObjects");

$ace = RT::Record->new($RT::SystemUser);
$ace->Table('ACL');
$ace->_BuildTableAttributes unless ($_TABLE_ATTR->{ref($self)});
($id, $msg) = $ace->Create( PrincipalId => $group->id, PrincipalType => 'Group', RightName => 'RTxUserRight', ObjectType => 'RTx::System::Record', ObjectId => 5 );
ok ($id, "ACL for RTxObj created");

my $RTxObj2 = {};
bless $RTxObj2, 'RTx::System::Record';
*RTx::System::Record::Id = sub { 5; };
*RTx::System::Record::id = sub { 5; };

$users = RT::Users->new($RT::SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2);
is($users->Count, 1, "RTxUserRight found for RTxObj2");

$users = RT::Users->new($RT::SystemUser);
$users->WhoHaveRight(Right => 'RTxUserRight', Object => $RTxObj2, EquivObjects => [ $RTxSysObj ]);
is($users->Count, 1, "RTxUserRight found for RTxObj2");


=end testing


find all users who the right Right for this group, either individually
or as members of groups


If passed a queue object, with no id, it will find users who have that right for _any_ queue



=cut

sub WhoHaveRight {
    my $self = shift;
    my %args = (
        Right                  => undef,
        Object                 => undef,
        IncludeSystemRights    => undef,
        IncludeSuperusers      => undef,
        IncludeSubgroupMembers => 1,
        EquivObjects           => [ ],
        @_
    );

    if ( defined $args{'ObjectType'} || defined $args{'ObjectId'} ) {
        $RT::Logger->crit( "$self WhoHaveRight called with the Obsolete ObjectId/ObjectType API");
        return (undef);
    }
    

    # Find only members of groups that have the right.

    my $acl       = $self->NewAlias('ACL');
    my $groups    = $self->NewAlias('Groups');
    my $userprinc = $self->{'princalias'};

# The cachedgroupmembers table is used for unrolling group memberships to allow fast lookups
# if we bind to CachedGroupMembers, we'll find all members of groups recursively.
# if we don't we'll find only 'direct' members of the group in question
    my $cgm;

    if ( $args{'IncludeSubgroupMembers'} ) {
        $cgm = $self->NewAlias('CachedGroupMembers');
    }
    else {
        $cgm = $self->NewAlias('GroupMembers');
    }

#Tie the users we're returning ($userprinc) to the groups that have rights granted to them ($groupprinc)
    $self->Join(
        ALIAS1 => $cgm,
        FIELD1 => 'MemberId',
        ALIAS2 => $userprinc,
        FIELD2 => 'id'
    );

    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'id',
        ALIAS2 => $cgm,
        FIELD2 => 'GroupId'
    );

# {{{ Find only rows where the right granted is the one we're looking up or _possibly_ superuser
    $self->Limit(
        ALIAS    => $acl,
        FIELD    => 'RightName',
        OPERATOR => ( $args{Right} ? '=' : 'IS NOT' ),
        VALUE => $args{Right} || 'NULL',
        ENTRYAGGREGATOR => 'OR'
    );

    if ( $args{'IncludeSuperusers'} and $args{'Right'} ) {
        $self->Limit(
            ALIAS           => $acl,
            FIELD           => 'RightName',
            OPERATOR        => '=',
            VALUE           => 'SuperUser',
            ENTRYAGGREGATOR => 'OR'
        );
    }

    # }}}

    my ( $or_check_ticket_roles, $or_check_roles );
    my $which_object = "$acl.ObjectType = 'RT::System'";

    if ( defined $args{'Object'} ) {
        if ( ref( $args{'Object'} ) eq 'RT::Ticket' ) {
            $or_check_ticket_roles = " OR ( $groups.Domain = 'RT::Ticket-Role' AND $groups.Instance = " . $args{'Object'}->Id . ") ";

# If we're looking at ticket rights, we also want to look at the associated queue rights.
# this is a little bit hacky, but basically, now that we've done the ticket roles magic,
# we load the queue object and ask all the rest of our questions about the queue.
            $args{'Object'} = $args{'Object'}->QueueObj;
        }

        # TODO XXX This really wants some refactoring
        if ( ref( $args{'Object'} ) eq 'RT::Queue' ) {
            $or_check_roles = " OR ( ( ($groups.Domain = 'RT::Queue-Role' ";
            $or_check_roles .= "AND $groups.Instance = " . $args{'Object'}->id if ( $args{'Object'}->id );
            $or_check_roles .= ") $or_check_ticket_roles ) " . " AND $groups.Type = $acl.PrincipalType) ";
        }
        if ( $args{'IncludeSystemRights'} ) {
            $which_object .= ' OR ';
        }
        else {
            $which_object = '';
        }
        foreach my $obj ( @{ $args{'EquivObjects'} } ) {
            $which_object .= "($acl.ObjectType = '" . ref( $obj ) . "' AND $acl.ObjectId = " . $obj->id . ") OR ";
        }
        $which_object .= " ($acl.ObjectType = '" . ref( $args{'Object'} ) . "'";
        if ( $args{'Object'}->id ) {
            $which_object .= " AND $acl.ObjectId = " . $args{'Object'}->id;
        }

        $which_object .=  ") ";
    }
    $self->_AddSubClause( "WhichObject", "($which_object)" );
    $self->_AddSubClause(
        "WhichGroup",
            qq{ ( (    $acl.PrincipalId = $groups.id AND $acl.PrincipalType = 'Group' 
                AND (   $groups.Domain = 'SystemInternal' OR $groups.Domain = 'UserDefined' OR $groups.Domain = 'ACLEquivalence')) 
                $or_check_roles) }
    );
    # only include regular RT users
    $self->LimitToEnabled;

    # no system user
    $self->Limit( ALIAS => $userprinc, FIELD => 'id', OPERATOR => '!=', VALUE => $RT::SystemUser->id);

}
# }}}

# {{{ WhoBelongToGroups 

=head2 WhoBelongToGroups { Groups => ARRAYREF, IncludeSubgroupMembers => 1 }

=cut

sub WhoBelongToGroups {
    my $self = shift;
    my %args = ( Groups                 => undef,
                 IncludeSubgroupMembers => 1,
                 @_ );

    # Unprivileged users can't be granted real system rights. 
    # is this really the right thing to be saying?
    $self->LimitToPrivileged();

    my $userprinc  = $self->{'princalias'};
    my $cgm;

    # The cachedgroupmembers table is used for unrolling group memberships to allow fast lookups 
    # if we bind to CachedGroupMembers, we'll find all members of groups recursively.
    # if we don't we'll find only 'direct' members of the group in question

    if ( $args{'IncludeSubgroupMembers'} ) {
        $cgm = $self->NewAlias('CachedGroupMembers');
    }
    else {
        $cgm = $self->NewAlias('GroupMembers');
    }

    #Tie the users we're returning ($userprinc) to the groups that have rights granted to them ($groupprinc)
    $self->Join( ALIAS1 => $cgm, FIELD1 => 'MemberId',
                 ALIAS2 => $userprinc, FIELD2 => 'id' );

    foreach my $groupid (@{$args{'Groups'}}) {
        $self->Limit(ALIAS => $cgm, FIELD => 'GroupId', VALUE => $groupid, QUOTEVALUE => 0, ENTRYAGGREGATOR=> 'OR')

    }
}
# }}}


1;
