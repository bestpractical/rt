# $Header: /raid/cvsroot/rt/lib/RT/Users.pm,v 1.2 2001/11/06 23:04:15 jesse Exp $
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

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

no warnings qw(redefine);

# {{{ sub _Init 
sub _Init  {
  my $self = shift;
  $self->{'table'} = "Users";
  $self->{'primary_key'} = "id";

  # By default, order by name
  $self->OrderBy( ALIAS => 'main',
		  FIELD => 'Name',
		  ORDER => 'ASC');

  return ($self->SUPER::_Init(@_));
  
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
    unless($self->{'find_disabled_rows'}) {
	$self->LimitToEnabled();
    }
    
    return($self->SUPER::_DoSearch(@_));
    
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
    $self->Limit(FIELD => 'EmailAddress', VALUE => "$addr");
}

# }}}

# {{{ MemberOfGroup

=head2 MemberOfGroup PRINCIPAL_ID

takes one argument, a group's principal id. Limits the returned set
to members of a given group

=cut

sub MemberOfGroup {
    my $self = shift;
    my $group = shift;
    
    return $self->loc("No group specified") if (!defined $group);

    my $groupalias = $self->NewAlias('CachedGroupMembers');
    my $princalias = $self->NewAlias('Principals');

    $self->Join( ALIAS1 => 'main', FIELD1 => 'id', 
	         ALIAS2 => $princalias,  FIELD2 => 'ObjectId');
	$self->Join (ALIAS1 => $princalias, FIELD1 => id,
				 ALIAS2 => $groupalias, FIELD2 => 'MemberId');

	$self->Limit(ALIAS => $princalias,
				 FIELD => 'PrincipalType',
				 OPERATOR => '=',
				 VALUE => 'User');

		    
    $self->Limit (ALIAS => "$groupalias",
		  FIELD => 'GroupId',
		  VALUE => "$group",
		  OPERATOR => "="
		 );
}

# }}}

# {{{ LimitToPrivileged

=head2 LimitToPrivileged

Limits to users who can be made members of ACLs and groups

=cut

sub LimitToPrivileged {
    my $self = shift;

	my $priv = RT::Group->new($self->CurrentUser);
	$priv->LoadSystemInternalGroup('Privileged');
	unless ($priv->Id) {
		$RT::Logger->crit("Couldn't find a privileged users group");
	}
	$self->MemberOfGroup($priv->PrincipalId);
}

# }}}

# {{{ WhoHaveGroupRight

=head2 WhoHaveRight { Right => 'name', ObjectId => 'id', IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef }

=begin testing

ok(my $users = RT::Users->new($RT::SystemUser));
ok( $users->WhoHaveRight(ObjectType =>'System', Right =>'SuperUser'));
ok($users->Count == 2, "There are two superusers - Found ". $users->Count);
# TODO: this wants more testing

=end testing



=cut


sub WhoHaveRight {

    my $self = shift;
    my %args = ( Right => undef,
                 ObjectType => undef,
                 ObjectId => undef,
                 IncludeSystemRights => undef, 
                 IncludeSuperusers => undef,
                 IncludeSubgroupMembers => undef, 
                 @_);


# find all users who the right Right for this group, either individually
# or as members of groups


}
# }}}

# {{{ WhoHaveRight

=head2 WhoHaveRight { Right => 'name', ObjectType => 'type', ObjectId => 'id', IncludeSuperusers => undef, 



In the future, we'll also allow these parameters:

    IncludeSubgroupMembers => undef, IncludeSystemRights => undef }


=cut

sub WhoHaveRight {

    my $self = shift;
    my %args = (
        Right                  => undef,
        ObjectType             => undef,
        ObjectId               => undef,
        IncludeSystemRights    => undef,
        IncludeSuperusers      => undef,
        IncludeSubgroupMembers => 1,
        @_
    );

    my $users      = 'main';
    my $groups     = $self->NewAlias('Groups');
    my $userprinc  = $self->NewAlias('Principals');
    my $groupprinc = $self->NewAlias('Principals');
    my $acl        = $self->NewAlias('ACL');
    my $cgm;
    if ($args{'IncludeSubgroupMembers'} ) {
        $cgm        = $self->NewAlias('CachedGroupMembers');
     }
     else {
        $cgm        = $self->NewAlias('GroupMembers');
     }

    # Find all users who have this right OR all users who are members of groups 
    # which have this right for this object

    if ( $args{'ObjectType'} eq 'Ticket' ) {
        $or_check_ticket_roles =
          " OR ( $groups.Domain = 'TicketRole' AND $groups.Instance = '"
          . $args{'ObjectId'} . "') ";

        # If we're looking at ticket rights, we also want to look at the associated queue rights.
        # this is a little bit hacky, but basically, now that we've done the ticket roles magic, we load the queue object
        # and ask all the rest of our questions about the queue.
        my $tick = RT::Ticket->new($RT::SystemUser);
        $tick->Load( $args{'ObjectId'} );
        $args{'ObjectType'} = 'Queue';
        $args{'ObjectId'}   = $tick->QueueObj->Id();

    }
    if ( $args{'ObjectType'} eq 'Queue' ) {
        $or_check_roles =
          " OR ( ( ($groups.Domain = 'QueueRole' AND $groups.Instance = '"
          . $args{'ObjectId'}
          . "') $or_check_ticket_roles ) "
          . " AND $groups.Type = $acl.PrincipalType AND $groups.Id = $groupprinc.ObjectId AND $groupprinc.PrincipalType = 'Group') ";
    }

    if ( defined $args{'ObjectType'} ) {
        $or_look_at_object_rights =
          " OR ($acl.ObjectType = '"
          . $args{'ObjectType'}
          . "'  AND $acl.ObjectId = '"
          . $args{'ObjectId'} . "') ";

    }

    $self->Join(
        ALIAS1 => $users,
        FIELD1 => 'id',
        ALIAS2 => $userprinc,
        FIELD2 => 'ObjectId'
    );

    $self->Join(
        ALIAS1 => $cgm,
        FIELD1 => 'MemberId',
        ALIAS2 => $userprinc,
        FIELD2 => 'Id'
    );

    $self->Join(
        ALIAS1 => $cgm,
        FIELD1 => 'GroupId',
        ALIAS2 => $groupprinc,
        FIELD2 => 'Id'
    );

    $self->Limit(
        ALIAS    => $userprinc,
        FIELD    => 'PrincipalType',
        OPERATOR => '=',
        VALUE    => 'User'
    );

    if ( $args{'IncludeSuperusers'} ) {
        $self->Limit(
            ALIAS    => $acl,
            FIELD    => 'RightName',
            OPERATOR => '=',
            VALUE    => 'SuperUser',
	    ENTRYAGGREGATOR => 'OR'
        );
    }

    $self->Limit(
        ALIAS           => $acl,
        FIELD           => 'RightName',
        OPERATOR        => '=',
        VALUE           => $args{Right},
        ENTRYAGGREGATOR => 'OR'
    );

    $self->_AddSubClause( "WhichRight",
        "($acl.ObjectType = 'System' $or_look_at_object_rights)" );
    $self->_AddSubClause( "WhichGroup",
        "( ($acl.PrincipalId = $groupprinc.Id AND $groupprinc.ObjectId = $groups.Id AND $acl.PrincipalType = 'Group' AND "
          . "($groups.Domain = 'SystemInternal' OR $groups.Domain = 'UserDefined' OR $groups.Domain = 'ACLEquivalence')) $or_check_roles)"
    );

}

# }}}


1;

