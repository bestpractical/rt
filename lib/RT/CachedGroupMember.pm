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

package RT::CachedGroupMember;

use strict;
use warnings;


use base 'RT::Record';

sub Table {'CachedGroupMembers'}

=head1 NAME

  RT::CachedGroupMember

=head1 SYNOPSIS

  use RT::CachedGroupMember;

=head1 DESCRIPTION

=head1 METHODS

=cut

# {{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Principal object

  'Member' is the RT::Principal  of the user or group we're adding to 
  the cache.

  'ImmediateParent' is the RT::Principal of the group that this 
  principal belongs to to get here

  int(11) 'Via' is an internal reference to CachedGroupMembers->Id of
  the "parent" record of this cached group member. It should be empty if 
  this member is a "direct" member of this group. (In that case, it will 
  be set to this cached group member's id after creation)

  This routine should _only_ be called by GroupMember->Create

=cut

sub Create {
    my $self = shift;
    my %args = ( Group           => '',
                 Member          => '',
                 ImmediateParent => '',
                 Via             => '0',
                 Disabled        => '0',
                 @_ );

    unless (    $args{'Member'}
             && UNIVERSAL::isa( $args{'Member'}, 'RT::Principal' )
             && $args{'Member'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Member argument");
    }

    unless (    $args{'Group'}
             && UNIVERSAL::isa( $args{'Group'}, 'RT::Principal' )
             && $args{'Group'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Group argument");
    }

    unless (    $args{'ImmediateParent'}
             && UNIVERSAL::isa( $args{'ImmediateParent'}, 'RT::Principal' )
             && $args{'ImmediateParent'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus ImmediateParent argument");
    }

    # If the parent group for this group member is disabled, it's disabled too, along with all its children
    if ( $args{'ImmediateParent'}->Disabled ) {
        $args{'Disabled'} = $args{'ImmediateParent'}->Disabled;
    }

    my $id = $self->SUPER::Create(
                              GroupId           => $args{'Group'}->Id,
                              MemberId          => $args{'Member'}->Id,
                              ImmediateParentId => $args{'ImmediateParent'}->Id,
                              Disabled          => $args{'Disabled'},
                              Via               => $args{'Via'}, );

    unless ($id) {
        $RT::Logger->warning( "Couldn't create "
                           . $args{'Member'}
                           . " as a cached member of "
                           . $args{'Group'}->Id . " via "
                           . $args{'Via'} );
        return (undef);  #this will percolate up and bail out of the transaction
    }
    if ( $self->__Value('Via') == 0 ) {
        my ( $vid, $vmsg ) = $self->__Set( Field => 'Via', Value => $id );
        unless ($vid) {
            $RT::Logger->warning( "Due to a via error, couldn't create "
                               . $args{'Member'}
                               . " as a cached member of "
                               . $args{'Group'}->Id . " via "
                               . $args{'Via'} );
            return (undef)
              ;          #this will percolate up and bail out of the transaction
        }
    }

    return $id if $args{'Member'}->id == $args{'Group'}->id;

    if ( $args{'Member'}->IsGroup() ) {
        my $GroupMembers = $args{'Member'}->Object->MembersObj();
        while ( my $member = $GroupMembers->Next() ) {
            my $cached_member =
              RT::CachedGroupMember->new( $self->CurrentUser );
            my $c_id = $cached_member->Create(
                                             Group  => $args{'Group'},
                                             Member => $member->MemberObj,
                                             ImmediateParent => $args{'Member'},
                                             Disabled => $args{'Disabled'},
                                             Via      => $id );
            unless ($c_id) {
                return (undef);    #percolate the error upwards.
                     # the caller will log an error and abort the transaction
            }

        }
    }

    return ($id);

}



=head2 Delete

Deletes the current CachedGroupMember from the group it's in and
cascades the delete to all submembers.

=cut

sub Delete {
    my $self = shift;


    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::CachedGroupMembers->new( $self->CurrentUser );

        $deletable->Limit( FIELD    => 'id',
                           OPERATOR => '!=',
                           VALUE    => $self->id );
        $deletable->Limit( FIELD    => 'Via',
                           OPERATOR => '=',
                           VALUE    => $self->id );

        while ( my $kid = $deletable->Next ) {
            my ($ok, $msg) = $kid->Delete();
            unless ($ok) {
                $RT::Logger->error(
                    "Couldn't delete CachedGroupMember " . $kid->Id );
                return ($ok, $msg);
            }
        }
    }
    my ($ok, $msg) = $self->SUPER::Delete();
    $RT::Logger->error( "Couldn't delete CachedGroupMember " . $self->Id ) unless $ok;
    return ($ok, $msg);
}



=head2 SetDisabled

SetDisableds the current CachedGroupMember from the group it's in and cascades 
the SetDisabled to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading SetDisableds.

=cut 

sub SetDisabled {
    my $self = shift;
    my $val = shift;
 
    # if it's already disabled, we're good.
    return (1) if ( $self->__Value('Disabled') == $val);
    my $err = $self->_Set(Field => 'Disabled', Value => $val);
    my ($retval, $msg) = $err->as_array();
    unless ($retval) {
        $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $self->Id .": $msg");
        return ($err);
    }
    
    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::CachedGroupMembers->new( $self->CurrentUser );

        $deletable->Limit( FIELD    => 'Via', OPERATOR => '=', VALUE    => $self->id );
        $deletable->Limit( FIELD    => 'id', OPERATOR => '!=', VALUE    => $self->id );

        while ( my $kid = $deletable->Next ) {
            my $kid_err = $kid->SetDisabled($val );
            unless ($kid_err) {
                $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $kid->Id );
                return ($kid_err);
            }
        }
    }
    return ($err);
}



=head2 GroupObj  

Returns the RT::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->GroupId );
    return ($principal);
}



=head2 ImmediateParentObj  

Returns the RT::Principal object for this group ImmediateParent

=cut

sub ImmediateParentObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->ImmediateParentId );
    return ($principal);
}



=head2 MemberObj  

Returns the RT::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->MemberId );
    return ($principal);
}

# }}}






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 GroupId

Returns the current value of GroupId.
(In the database, GroupId is stored as int(11).)



=head2 SetGroupId VALUE


Set GroupId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, GroupId will be stored as a int(11).)


=cut


=head2 MemberId

Returns the current value of MemberId.
(In the database, MemberId is stored as int(11).)



=head2 SetMemberId VALUE


Set MemberId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MemberId will be stored as a int(11).)


=cut


=head2 Via

Returns the current value of Via.
(In the database, Via is stored as int(11).)



=head2 SetVia VALUE


Set Via to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Via will be stored as a int(11).)


=cut


=head2 ImmediateParentId

Returns the current value of ImmediateParentId.
(In the database, ImmediateParentId is stored as int(11).)



=head2 SetImmediateParentId VALUE


Set ImmediateParentId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ImmediateParentId will be stored as a int(11).)


=cut


=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {

        id =>
                {read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        GroupId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        MemberId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Via =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ImmediateParentId =>
                {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Disabled =>
                {read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};

sub Serialize {
    die "CachedGroupMembers should never be serialized";
}

sub __DependsOn
{
    my $self = shift;
    my %args = (
        Shredder => undef,
        Dependencies => undef,
        @_,
    );
    my $deps = $args{'Dependencies'};
    my $list = [];

# deep memebership
    my $objs = RT::CachedGroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Via', VALUE => $self->Id );
    $objs->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->Id );
    push( @$list, $objs );

# principal lost group membership and lost some rights which he could delegate to
# some body

# XXX: Here is problem cause HasMemberRecursively would return true allways
# cause we didn't delete anything yet. :(
    # if pricipal is not member anymore(could be via other groups) then proceed
    if( $self->GroupObj->Object->HasMemberRecursively( $self->MemberObj ) ) {
        my $acl = RT::ACL->new( $self->CurrentUser );
        $acl->LimitToPrincipal( Id => $self->GroupId );
    }


    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => RT::Shredder::Constants::DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'}
    );

    return $self->SUPER::__DependsOn( %args );
}

RT::Base->_ImportOverlays();

1;
