# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
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

    $self->Limit( ALIAS    => $self->{'princalias'},
                  FIELD    => 'PrincipalType',
                  OPERATOR => '=',
                  VALUE    => 'User' );
    return (@result);
}

# }}}

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

=head2 WhoHaveRight { Right => 'name', Object => $rt_object , IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef }

=begin testing

ok(my $users = RT::Users->new($RT::SystemUser));
ok( $users->WhoHaveRight(Object =>$RT::System, Right =>'SuperUser'));
ok($users->Count == 2, "There are two superusers - Found ". $users->Count);
# TODO: this wants more testing


=end testing


find all users who the right Right for this group, either individually
or as members of groups





=cut

sub WhoHaveRight {

    my $self = shift;
    my %args = ( Right                  => undef,
                 Object =>              => undef,
                 IncludeSystemRights    => undef,
                 IncludeSuperusers      => undef,
                 IncludeSubgroupMembers => 1,
                 @_ );


    if (defined $args{'ObjectType'} || defined $args{'ObjectId'}) {
        $RT::Logger->crit("$self WhoHaveRight called with the Obsolete ObjectId/ObjectType API");
        return(undef);
    }

    my $users      = 'main';
    my $groups     = $self->NewAlias('Groups');
    my $userprinc  = $self->NewAlias('Principals');
    my $groupprinc = $self->NewAlias('Principals');
    my $acl        = $self->NewAlias('ACL');
    my $cgm;
    if ( $args{'IncludeSubgroupMembers'} ) {
        $cgm = $self->NewAlias('CachedGroupMembers');
    }
    else {
        $cgm = $self->NewAlias('GroupMembers');
    }

    $self->LimitToPrivileged();


    # Find all users who have this right OR all users who are members of groups 
    # which have this right for this object

    my ($or_check_ticket_roles, $or_check_roles, $or_look_at_object_rights);

    if ( defined $args{'Object'} ) {
    if ( ref($args{'Object'}) eq 'RT::Ticket' ) {
        $or_check_ticket_roles =
          " OR ( $groups.Domain = 'RT::Ticket-Role' AND $groups.Instance = '"
          . $args{'Object'}->Id . "') ";

        # If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        $args{'Object'}   = $args{'Object'}->QueueObj;

    }
    # TODO XXX This really wants some refactoring
    if ( ref($args{'Object'}) eq 'RT::Queue' ) {
        $or_check_roles =
          " OR ( ( ($groups.Domain = 'RT::Queue-Role' AND $groups.Instance = '"
          . $args{'Object'}->Id
          . "') $or_check_ticket_roles ) "
          . " AND $groups.Type = $acl.PrincipalType AND $groups.Id = $groupprinc.id AND $groupprinc.PrincipalType = 'Group') ";
    }

        $or_look_at_object_rights =
          " OR ($acl.ObjectType = '"
          . ref($args{'Object'})
          . "'  AND $acl.ObjectId = '"
          . $args{'Object'}->Id . "') ";

    }

    $self->Join( ALIAS1 => $users,
                 FIELD1 => 'id',
                 ALIAS2 => $userprinc,
                 FIELD2 => 'id' );

    $self->Join( ALIAS1 => $cgm,
                 FIELD1 => 'MemberId',
                 ALIAS2 => $userprinc,
                 FIELD2 => 'Id' );

    $self->Join( ALIAS1 => $cgm,
                 FIELD1 => 'GroupId',
                 ALIAS2 => $groupprinc,
                 FIELD2 => 'Id' );

    $self->Limit( ALIAS    => $userprinc,
                  FIELD    => 'PrincipalType',
                  OPERATOR => '=',
                  VALUE    => 'User' );

    if ( $args{'IncludeSuperusers'} ) {
        $self->Limit( ALIAS           => $acl,
                      FIELD           => 'RightName',
                      OPERATOR        => '=',
                      VALUE           => 'SuperUser',
                      ENTRYAGGREGATOR => 'OR' );
    }

    $self->Limit( ALIAS           => $acl,
                  FIELD           => 'RightName',
                  OPERATOR        => '=',
                  VALUE           => $args{Right},
                  ENTRYAGGREGATOR => 'OR' );

    $self->_AddSubClause( "WhichRight",
                     "($acl.ObjectType = 'RT::System' $or_look_at_object_rights)" );
    $self->_AddSubClause( "WhichGroup",
"( ($acl.PrincipalId = $groupprinc.Id AND $groupprinc.id = $groups.Id AND $acl.PrincipalType = 'Group' AND "
          . "($groups.Domain = 'SystemInternal' OR $groups.Domain = 'UserDefined' OR $groups.Domain = 'ACLEquivalence')) $or_check_roles)"
    );

}

# }}}

1;

