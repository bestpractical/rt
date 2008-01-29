
package RT::Model::CachedGroupMember;

use strict;
no warnings qw(redefine);

use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column GroupId           => references RT::Model::Group;
    column MemberId          => type is 'integer';
    column Via               => type is 'integer';
    column ImmediateParentId => type is 'integer';
    column disabled          => type is 'integer', default is '0';

};

=head1 name

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

sub table {'CachedGroupMembers'}

sub create {
    my $self = shift;
    my %args = (
        Group           => '',
        Member          => '',
        ImmediateParent => '',
        Via             => '0',
        disabled        => '0',
        @_
    );

    unless ( $args{'Member'}
        && UNIVERSAL::isa( $args{'Member'}, 'RT::Model::Principal' )
        && $args{'Member'}->id )
    {
        Jifty->log->debug("$self->create: bogus Member argument");
    }

    unless ( $args{'Group'}
        && UNIVERSAL::isa( $args{'Group'}, 'RT::Model::Principal' )
        && $args{'Group'}->id )
    {
        Jifty->log->debug("$self->create: bogus Group argument");
    }

    unless ( $args{'ImmediateParent'}
        && UNIVERSAL::isa( $args{'ImmediateParent'}, 'RT::Model::Principal' )
        && $args{'ImmediateParent'}->id )
    {
        Jifty->log->debug("$self->create: bogus ImmediateParent argument");
    }

# If the parent group for this group member is disabled, it's disabled too, along with all its children
    if ( $args{'ImmediateParent'}->disabled ) {
        $args{'disabled'} = $args{'ImmediateParent'}->disabled;
    }

    my $id = $self->SUPER::create(
        GroupId           => $args{'Group'}->id,
        MemberId          => $args{'Member'}->id,
        ImmediateParentId => $args{'ImmediateParent'}->id,
        disabled          => $args{'disabled'},
        Via               => $args{'Via'},
    );

    unless ($id) {
        Jifty->log->warn( "Couldn't create "
                . $args{'Member'}
                . " as a cached member of "
                . $args{'Group'}->id . " via "
                . $args{'Via'} );
        return (undef)
            ;    #this will percolate up and bail out of the transaction
    }
    if ( $self->__value('Via') == 0 ) {
        my ( $vid, $vmsg ) = $self->__set( column => 'Via', value => $id );
        unless ($vid) {
            Jifty->log->warn( "Due to a via error, couldn't create "
                    . $args{'Member'}
                    . " as a cached member of "
                    . $args{'Group'}->id . " via "
                    . $args{'Via'} );
            return (undef)
                ;    #this will percolate up and bail out of the transaction
        }
    }

    if ( $args{'Member'}->is_group() ) {
        my $GroupMembers = $args{'Member'}->object->members_obj();
        while ( my $member = $GroupMembers->next() ) {
            my $cached_member = RT::Model::CachedGroupMember->new;
            my $c_id          = $cached_member->create(
                Group           => $args{'Group'},
                Member          => $member->member_obj,
                ImmediateParent => $args{'Member'},
                disabled        => $args{'disabled'},
                Via             => $id
            );
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

    my $member = $self->member_obj();
    if ( $member->is_group ) {
        my $deletable = RT::Model::CachedGroupMemberCollection->new;

        $deletable->limit(
            column   => 'id',
            operator => '!=',
            value    => $self->id
        );
        $deletable->limit(
            column   => 'Via',
            operator => '=',
            value    => $self->id
        );

        while ( my $kid = $deletable->next ) {
            my $kid_err = $kid->delete();
            unless ($kid_err) {
                Jifty->log->error(
                    "Couldn't delete CachedGroupMember " . $kid->id );
                return (undef);
            }
        }
    }
    my $err = $self->SUPER::delete();
    unless ($err) {
        Jifty->log->error( "Couldn't delete CachedGroupMember " . $self->id );
        return (undef);
    }

    unless ( $self->group_obj->object ) {

        warn "HEY! NO group object object!!!" . $self->__value('GroupId');
        warn YAML::Dump($self);
        use YAML;
        return undef;
    }

  # Unless $self->group_obj still has the member recursively $self->member_obj
  # (Since we deleted the database row above, $self no longer counts)
    unless (
        $self->group_obj->object->has_member_recursively( $self->MemberId ) )
    {

        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::Model::ACECollection->new(
            current_user => RT->system_user );
        $acl->limit_to_principal( id => $self->GroupId );

        while ( my $this_ace = $acl->next() ) {

      #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new(
                current_user => RT->system_user );
            $delegations->delegated_from( id => $this_ace->id );
            $delegations->delegated_by( id => $self->MemberId );

            # For each delegation
            while ( my $delegation = $delegations->next ) {

                # WHACK IT
                my $del_ret = $delegation->_delete( inside_transaction => 1 );
                unless ($del_ret) {
                    Jifty->log->fatal(
                        "Couldn't delete an ACL delegation that we know exists "
                            . $delegation->id );
                    return (undef);
                }
            }
        }
    }
    return ($err);
}

# }}}

# {{{ Setdisabled

=head2 Setdisabled

Setdisableds the current CachedGroupMember from the group it's in and cascades 
the Setdisabled to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading Setdisableds.

=cut 

sub set_disabled {
    my $self = shift;
    my $val  = shift;

    # if it's already disabled, we're good.
    return (1) if ( $self->__value('disabled') == $val );
    my $err = $self->_set( column => 'disabled', value => $val );
    my ( $retval, $msg ) = $err->as_array();
    unless ($retval) {
        Jifty->log->error( "Couldn't Setdisabled CachedGroupMember "
                . $self->id
                . ": $msg" );
        return ($err);
    }

    my $member = $self->member_obj();
    if ( $member->is_group ) {
        my $deletable = RT::Model::CachedGroupMemberCollection->new;

        $deletable->limit(
            column   => 'Via',
            operator => '=',
            value    => $self->id
        );
        $deletable->limit(
            column   => 'id',
            operator => '!=',
            value    => $self->id
        );

        while ( my $kid = $deletable->next ) {
            my $kid_err = $kid->set_disabled($val);
            unless ($kid_err) {
                Jifty->log->error(
                    "Couldn't Setdisabled CachedGroupMember " . $kid->id );
                return ($kid_err);
            }
        }
    }

  # Unless $self->group_obj still has the member recursively $self->member_obj
  # (Since we Setdisabledd the database row above, $self no longer counts)
    unless (
        $self->group_obj->object->has_member_recursively( $self->MemberId ) )
    {

        #   Find all ACEs granted to $self->GroupId
        my $acl = RT::Model::ACECollection->new(
            current_user => RT->system_user );
        $acl->limit_to_principal( id => $self->GroupId );

        while ( my $this_ace = $acl->next() ) {

      #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new(
                current_user => RT->system_user );
            $delegations->delegated_from( id => $this_ace->id );
            $delegations->delegated_by( id => $self->MemberId );

            # For each delegation,  blow away the delegation
            while ( my $delegation = $delegations->next ) {

                # WHACK IT
                my $del_ret = $delegation->_delete( inside_transaction => 1 );
                unless ($del_ret) {
                    Jifty->log->fatal(
                        "Couldn't delete an ACL delegation that we know exists "
                            . $delegation->id );
                    return (undef);
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

sub group_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->GroupId );
    return ($principal);
}

# }}}

# {{{ ImmediateParentObj

=head2 ImmediateParentObj  

Returns the RT::Model::Principal object for this group ImmediateParent

=cut

sub immediate_parent_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->ImmediateParentId );
    return ($principal);
}

# }}}

# {{{ MemberObj

=head2 MemberObj  

Returns the RT::Model::Principal object for this group member

=cut

sub member_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->MemberId );
    return ($principal);
}

# }}}
1;
