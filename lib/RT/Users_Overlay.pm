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

=head2 WhoHaveRight { Right => 'name', Object => $rt_object , IncludeSuperusers => undef, IncludeSubgroupMembers => undef, IncludeSystemRights => undef }

=begin testing

ok(my $users = RT::Users->new($RT::SystemUser));
$users->WhoHaveRight(Object =>$RT::System, Right =>'SuperUser');
ok($users->Count == 1, "There is one privileged superuser - Found ". $users->Count );
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
        my @privgroups;
        my $Groups = RT::Groups->new($RT::SystemUser);
        $Groups->WithRight(Right=> $args{'Right'},
                     Object => $args{'Object'},
                     IncludeSystemRights => $args{'IncludeSystemRights'},
                     IncludeSuperusers => $args{'IncludeSuperusers'});
        while (my $Group = $Groups->Next()) {
                push @privgroups, $Group->Id();
        }


    if (@privgroups) {
        $self->WhoBelongToGroups(Groups => \@privgroups,
                                 IncludeSubgroupMembers => $args{'IncludeSubgroupMembers'});
    }
    else {
	# We don't have any group that matches -- make it impossible.
	$self->Limit( FIELD => 'Id', VALUE => 'IS', OPERATOR => 'NULL' );
    }
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

    # {{{ Tie the users we're returning ($userprinc) to the groups that have rights granted to them ($groupprinc)
    $self->Join( ALIAS1 => $cgm, FIELD1 => 'MemberId',
                 ALIAS2 => $userprinc, FIELD2 => 'id' );
    # }}} 

 #   my $and_check_groups = "($cgm.GroupId = NULL";
    foreach my $groupid (@{$args{'Groups'}}) {
        $self->Limit(ALIAS => $cgm, FIELD => 'GroupId', VALUE => $groupid, QUOTEVALUE => 0, ENTRYAGGREGATOR=> 'OR')

        #$and_check_groups .= " OR $cgm.GroupId = $groupid";
    }
    #$and_check_groups .= ")";

    #$self->_AddSubClause("WhichGroup", $and_check_groups);
}
# }}}


1;
