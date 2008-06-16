# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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
# http://www.gnu.org/copyleft/gpl.html.
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
package RT::Model::CachedGroupMember;

use strict;
no warnings qw(redefine);

use base qw/RT::Record/;

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column group_id            => references RT::Model::Group;
    column member_id           => references RT::Model::Principal;
    column via                 => references RT::Model::CachedGroupMember;
    column immediate_parent_id => references RT::Model::CachedGroupMember;
    column disabled            => type is 'integer', default is '0';

};

=head1 name

  RT::Model::CachedGroupMember

=head1 SYNOPSIS

  use RT::Model::CachedGroupMember;

=head1 description

=head1 METHODS

=cut

# {{ Create

=head2 create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Model::Principal object

  'Member' is the RT::Model::Principal  of the user or group we're adding to 
  the cache.

  'immediate_parent' is the RT::Model::Principal of the group that this 
  principal belongs to to get here

  int 'via' is an internal reference to CachedGroupMembers->id of
  the "parent" record of this cached group member. It should be empty if 
  this member is a "direct" member of this group. (In that case, it will 
  be set to this cached group member's id after creation)

  This routine should _only_ be called by GroupMember->create

=cut

sub table {'CachedGroupMembers'}

sub create {
    my $self = shift;
    my %args = (
        group            => '',
        member           => '',
        immediate_parent => '',
        via              => '0',
        disabled         => '0',
        @_
    );

    unless ( $args{'member'}
        && UNIVERSAL::isa( $args{'member'}, 'RT::Model::Principal' )
        && $args{'member'}->id )
    {
        Jifty->log->debug("$self->create: bogus Member argument");
    }

    unless ( $args{'group'}
        && UNIVERSAL::isa( $args{'group'}, 'RT::Model::Principal' )
        && $args{'group'}->id )
    {
        Jifty->log->debug("$self->create: bogus Group argument");
    }

    unless ( $args{'immediate_parent'}
        && UNIVERSAL::isa( $args{'immediate_parent'}, 'RT::Model::Principal' )
        && $args{'immediate_parent'}->id )
    {
        Jifty->log->debug("$self->create: bogus immediate_parent argument");
    }

    # If the parent group for this group member is disabled, it's disabled too, along with all its children
    if ( $args{'immediate_parent'}->disabled ) {
        $args{'disabled'} = $args{'immediate_parent'}->disabled;
    }

    my $id = $self->SUPER::create(
        group_id            => $args{'group'}->id,
        member_id           => $args{'member'}->id,
        immediate_parent_id => $args{'immediate_parent'}->id,
        disabled            => $args{'disabled'},
        via                 => $args{'via'},
    );

    unless ($id) {
        Jifty->log->warn( "Couldn't create " . $args{'member'} . " as a cached member of " . $args{'group'}->id . " via " . $args{'via'} );
        return (undef);    #this will percolate up and bail out of the transaction
    }
    if ( $self->__value('via') == 0 ) {
        my ( $vid, $vmsg ) = $self->__set( column => 'via', value => $id );
        unless ($vid) {
            Jifty->log->warn( "Due to a via error, couldn't create " . $args{'member'} . " as a cached member of " . $args{'group'}->id . " via " . $args{'via'} );
            return (undef);    #this will percolate up and bail out of the transaction
        }
    }

    if ( $args{'member'}->is_group() ) {
        my $GroupMembers = $args{'member'}->object->members_obj();
        while ( my $member = $GroupMembers->next() ) {
            my $cached_member = RT::Model::CachedGroupMember->new;
            my $c_id          = $cached_member->create(
                group            => $args{'group'},
                member           => $member->member_obj,
                immediate_parent => $args{'member'},
                disabled         => $args{'disabled'},
                via              => $id
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

=head2 delete

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
            column   => 'via',
            operator => '=',
            value    => $self->id
        );

        while ( my $kid = $deletable->next ) {
            my $kid_err = $kid->delete();
            unless ($kid_err) {
                Jifty->log->error( "Couldn't delete CachedGroupMember " . $kid->id );
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

        warn "HEY! NO group object object!!!" . $self->__value('group_id');
        warn YAML::Dump($self);
        use YAML;
        return undef;
    }

    # Unless $self->group_obj still has the member recursively $self->member_obj
    # (Since we deleted the database row above, $self no longer counts)
    unless ( $self->group_obj->object->has_member_recursively( $self->member_id ) ) {

        #   Find all ACEs granted to $self->group_id
        my $acl = RT::Model::ACECollection->new( current_user => RT->system_user );
        $acl->limit_to_principal( id => $self->group_id );

        while ( my $this_ace = $acl->next() ) {

            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new( current_user => RT->system_user );
            $delegations->delegated_from( id => $this_ace->id );
            $delegations->delegated_by( id => $self->member_id );

            # For each delegation
            while ( my $delegation = $delegations->next ) {

                # WHACK IT
                my $del_ret = $delegation->_delete( inside_transaction => 1 );
                unless ($del_ret) {
                    Jifty->log->fatal( "Couldn't delete an ACL delegation that we know exists " . $delegation->id );
                    return (undef);
                }
            }
        }
    }
    return ($err);
}

# }}}

# {{{ Setdisabled

=head2 setdisabled

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
        Jifty->log->error( "Couldn't Setdisabled CachedGroupMember " . $self->id . ": $msg" );
        return ($err);
    }

    my $member = $self->member_obj();
    if ( $member->is_group ) {
        my $deletable = RT::Model::CachedGroupMemberCollection->new;

        $deletable->limit(
            column   => 'via',
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
                Jifty->log->error( "Couldn't Setdisabled CachedGroupMember " . $kid->id );
                return ($kid_err);
            }
        }
    }

    # Unless $self->group_obj still has the member recursively $self->member_obj
    # (Since we Setdisabledd the database row above, $self no longer counts)
    unless ( $self->group_obj->object->has_member_recursively( $self->member_id ) ) {

        #   Find all ACEs granted to $self->group_id
        my $acl = RT::Model::ACECollection->new( current_user => RT->system_user );
        $acl->limit_to_principal( id => $self->group_id );

        while ( my $this_ace = $acl->next() ) {

            #       Find all ACEs which $self-MemberObj has delegated from $this_ace
            my $delegations = RT::Model::ACECollection->new( current_user => RT->system_user );
            $delegations->delegated_from( id => $this_ace->id );
            $delegations->delegated_by( id => $self->member_id );

            # For each delegation,  blow away the delegation
            while ( my $delegation = $delegations->next ) {

                # WHACK IT
                my $del_ret = $delegation->_delete( inside_transaction => 1 );
                unless ($del_ret) {
                    Jifty->log->fatal( "Couldn't delete an ACL delegation that we know exists " . $delegation->id );
                    return (undef);
                }
            }
        }
    }
    return ($err);
}

# }}}

# {{{ GroupObj

=head2 group_obj  

Returns the RT::Model::Principal object for this group Group

=cut

sub group_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->group_id );
    return ($principal);
}

# }}}

# {{{ immediate_parentObj

=head2 immediate_parent_obj  

Returns the RT::Model::Principal object for this group immediate_parent

=cut

sub immediate_parent_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->immediate_parent_id );
    return ($principal);
}

# }}}

# {{{ MemberObj

=head2 member_obj  

Returns the RT::Model::Principal object for this group member

=cut

sub member_obj {
    my $self      = shift;
    my $principal = RT::Model::Principal->new;
    $principal->load( $self->member_id );
    return ($principal);
}

# }}}
1;
