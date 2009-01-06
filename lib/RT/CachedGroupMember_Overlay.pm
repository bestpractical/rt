# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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
no warnings qw(redefine);

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

# }}}

# {{{ Delete

=head2 Delete

Deletes the current CachedGroupMember from the group it's in and cascades 
the delete to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading deletes.

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
            my $kid_err = $kid->Delete();
            unless ($kid_err) {
                $RT::Logger->error(
                              "Couldn't delete CachedGroupMember " . $kid->Id );
                return (undef);
            }
        }
    }
    my $err = $self->SUPER::Delete();
    unless ($err) {
        $RT::Logger->error( "Couldn't delete CachedGroupMember " . $self->Id );
        return (undef);
    }

    # Unless $self->GroupObj still has the member recursively $self->MemberObj
    # (Since we deleted the database row above, $self no longer counts)
    unless ( $self->GroupObj->Object->HasMemberRecursively( $self->MemberId ) ) {


        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::ACL->new($RT::SystemUser);
        $acl->LimitToPrincipal( Id => $self->GroupId );


        while ( my $this_ace = $acl->Next() ) {
            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::ACL->new($RT::SystemUser);
            $delegations->DelegatedFrom( Id => $this_ace->Id );
            $delegations->DelegatedBy( Id => $self->MemberId );

            # For each delegation 
            while ( my $delegation = $delegations->Next ) {
                # WHACK IT
                my $del_ret = $delegation->_Delete(InsideTransaction => 1);
                unless ($del_ret) {
                    $RT::Logger->crit("Couldn't delete an ACL delegation that we know exists ". $delegation->Id);
                    return(undef);
                }
            }
        }
    }
    return ($err);
}

# }}}

# {{{ SetDisabled

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
    my $err = $self->SUPER::SetDisabled($val);
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

    # Unless $self->GroupObj still has the member recursively $self->MemberObj
    # (Since we SetDisabledd the database row above, $self no longer counts)
    unless ( $self->GroupObj->Object->HasMemberRecursively( $self->MemberId ) ) {
        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::ACL->new($RT::SystemUser);
        $acl->LimitToPrincipal( Id => $self->GroupId );

        while ( my $this_ace = $acl->Next() ) {
            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::ACL->new($RT::SystemUser);
            $delegations->DelegatedFrom( Id => $this_ace->Id );
            $delegations->DelegatedBy( Id => $self->MemberId );

            # For each delegation,  blow away the delegation
            while ( my $delegation = $delegations->Next ) {
                # WHACK IT
                my $del_ret = $delegation->_Delete(InsideTransaction => 1);
                unless ($del_ret) {
                    $RT::Logger->crit("Couldn't delete an ACL delegation that we know exists ". $delegation->Id);
                    return(undef);
                }
            }
        }
    }
    return ($err);
}

# }}}

# {{{ GroupObj

=head2 GroupObj  

Returns the RT::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->GroupId );
    return ($principal);
}

# }}}

# {{{ ImmediateParentObj

=head2 ImmediateParentObj  

Returns the RT::Principal object for this group ImmediateParent

=cut

sub ImmediateParentObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->ImmediateParentId );
    return ($principal);
}

# }}}

# {{{ MemberObj

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
1;
