
package RT::Model::CachedGroupMember;

use strict;
no warnings qw(redefine);

use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
        column GroupId => references RT::Model::Group;
        column MemberId => type is 'integer';
        column Via => type is 'integer';
        column ImmediateParentId => type is 'integer';
    column Disabled      => type is 'integer', default is '0';

};





=head1 NAME

  RT::Model::CachedGroupMember

=head1 SYNOPSIS

  use RT::Model::CachedGroupMember;

=head1 DESCRIPTION

=head1 METHODS

=cut

# {{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Model::Principal object

  'Member' is the RT::Model::Principal  of the user or group we're adding to 
  the cache.

  'ImmediateParent' is the RT::Model::Principal of the group that this 
  principal belongs to to get here

  int(11) 'Via' is an internal reference to CachedGroupMembers->id of
  the "parent" record of this cached group member. It should be empty if 
  this member is a "direct" member of this group. (In that case, it will 
  be set to this cached group member's id after creation)

  This routine should _only_ be called by GroupMember->create

=cut

sub table { 'CachedGroupMembers'}

sub create {
    my $self = shift;
    my %args = ( Group           => '',
                 Member          => '',
                 ImmediateParent => '',
                 Via             => '0',
                 Disabled        => '0',
                 @_ );

    unless (    $args{'Member'}
             && UNIVERSAL::isa( $args{'Member'}, 'RT::Model::Principal' )
             && $args{'Member'}->id ) {
        $RT::Logger->debug("$self->create: bogus Member argument");
    }

    unless (    $args{'Group'}
             && UNIVERSAL::isa( $args{'Group'}, 'RT::Model::Principal' )
             && $args{'Group'}->id ) {
        $RT::Logger->debug("$self->create: bogus Group argument");
    }

    unless (    $args{'ImmediateParent'}
             && UNIVERSAL::isa( $args{'ImmediateParent'}, 'RT::Model::Principal' )
             && $args{'ImmediateParent'}->id ) {
        $RT::Logger->debug("$self->create: bogus ImmediateParent argument");
    }

    # If the parent group for this group member is disabled, it's disabled too, along with all its children
    if ( $args{'ImmediateParent'}->Disabled ) {
        $args{'Disabled'} = $args{'ImmediateParent'}->Disabled;
    }

    my $id = $self->SUPER::create(
                              GroupId           => $args{'Group'}->id,
                              MemberId          => $args{'Member'}->id,
                              ImmediateParentId => $args{'ImmediateParent'}->id,
                              Disabled          => $args{'Disabled'},
                              Via               => $args{'Via'}, );

    unless ($id) {
        $RT::Logger->warning( "Couldn't create "
                           . $args{'Member'}
                           . " as a cached member of "
                           . $args{'Group'}->id . " via "
                           . $args{'Via'} );
        return (undef);  #this will percolate up and bail out of the transaction
    }
    if ( $self->__value('Via') == 0 ) {
        my ( $vid, $vmsg ) = $self->__set( column => 'Via', value => $id );
        unless ($vid) {
            $RT::Logger->warning( "Due to a via error, couldn't create "
                               . $args{'Member'}
                               . " as a cached member of "
                               . $args{'Group'}->id . " via "
                               . $args{'Via'} );
            return (undef)
              ;          #this will percolate up and bail out of the transaction
        }
    }

    if ( $args{'Member'}->IsGroup() ) {
        my $GroupMembers = $args{'Member'}->Object->MembersObj();
        while ( my $member = $GroupMembers->next() ) {
            my $cached_member =
              RT::Model::CachedGroupMember->new( $self->current_user );
            my $c_id = $cached_member->create(
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

sub delete {
    my $self = shift;

    
    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::Model::CachedGroupMemberCollection->new( $self->current_user );

        $deletable->limit( column    => 'id',
                           operator => '!=',
                           value    => $self->id );
        $deletable->limit( column    => 'Via',
                           operator => '=',
                           value    => $self->id );

        while ( my $kid = $deletable->next ) {
            my $kid_err = $kid->delete();
            unless ($kid_err) {
                $RT::Logger->error(
                              "Couldn't delete CachedGroupMember " . $kid->id );
                return (undef);
            }
        }
    }
    my $err = $self->SUPER::delete();
    unless ($err) {
        $RT::Logger->error( "Couldn't delete CachedGroupMember " . $self->id );
        return (undef);
    }


    unless ($self->GroupObj->Object) {

        warn "HEY! NO group object object!!!" . $self->__value('GroupId'); warn YAML::Dump($self); use YAML;
        return undef;
    }
    # Unless $self->GroupObj still has the member recursively $self->MemberObj
    # (Since we deleted the database row above, $self no longer counts)
    unless ( $self->GroupObj->Object->has_member_recursively( $self->MemberObj ) ) {


        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::Model::ACECollection->new(RT->system_user);
        $acl->LimitToPrincipal( Id => $self->GroupId );


        while ( my $this_ace = $acl->next() ) {
            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new(RT->system_user);
            $delegations->DelegatedFrom( Id => $this_ace->id );
            $delegations->DelegatedBy( Id => $self->MemberId );

            # For each delegation 
            while ( my $delegation = $delegations->next ) {
                # WHACK IT
                my $del_ret = $delegation->_delete(InsideTransaction => 1);
                unless ($del_ret) {
                    $RT::Logger->crit("Couldn't delete an ACL delegation that we know exists ". $delegation->id);
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

sub set_Disabled {
    my $self = shift;
    my $val = shift;
 
    # if it's already disabled, we're good.
    return (1) if ( $self->__value('Disabled') == $val);
    my $err = $self->_set(column => 'Disabled', value  => $val);
    my ($retval, $msg) = $err->as_array();
    unless ($retval) {
        $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $self->id .": $msg");
        return ($err);
    }
    
    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::Model::CachedGroupMemberCollection->new( $self->current_user );

        $deletable->limit( column    => 'Via', operator => '=', value    => $self->id );
        $deletable->limit( column    => 'id', operator => '!=', value    => $self->id );

        while ( my $kid = $deletable->next ) {
            my $kid_err = $kid->set_Disabled($val );
            unless ($kid_err) {
                $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $kid->id );
                return ($kid_err);
            }
        }
    }

    # Unless $self->GroupObj still has the member recursively $self->MemberObj
    # (Since we SetDisabledd the database row above, $self no longer counts)
    unless ( $self->GroupObj->Object->has_member_recursively( $self->MemberObj ) ) {
        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::Model::ACECollection->new(RT->system_user);
        $acl->LimitToPrincipal( Id => $self->GroupId );

        while ( my $this_ace = $acl->next() ) {
            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new(RT->system_user);
            $delegations->DelegatedFrom( Id => $this_ace->id );
            $delegations->DelegatedBy( Id => $self->MemberId );

            # For each delegation,  blow away the delegation
            while ( my $delegation = $delegations->next ) {
                # WHACK IT
                my $del_ret = $delegation->_delete(InsideTransaction => 1);
                unless ($del_ret) {
                    $RT::Logger->crit("Couldn't delete an ACL delegation that we know exists ". $delegation->id);
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

Returns the RT::Model::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new( $self->current_user );
    $principal->load( $self->GroupId );
    return ($principal);
}

# }}}

# {{{ ImmediateParentObj

=head2 ImmediateParentObj  

Returns the RT::Model::Principal object for this group ImmediateParent

=cut

sub ImmediateParentObj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new( $self->current_user );
    $principal->load( $self->ImmediateParentId );
    return ($principal);
}

# }}}

# {{{ MemberObj

=head2 MemberObj  

Returns the RT::Model::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new( $self->current_user );
    $principal->load( $self->MemberId );
    return ($principal);
}

# }}}
1;
