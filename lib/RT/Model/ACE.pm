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

=head1 SYNOPSIS

  use RT::Model::ACE;
  my $ace = RT::Model::ACE->new( current_user => $CurrentUser );


=head1 description



=head1 METHODS


=cut

package RT::Model::ACE;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use RT::Model::PrincipalCollection;
use RT::Model::QueueCollection;
use RT::Model::GroupCollection;

use base qw/RT::Record/;

sub table {'ACL'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column type =>
        max_length is 25,
        type is 'varchar(25)',
    ;
    column principal => references RT::Model::Principal;
    column right_name => max_length is 25, type is 'varchar(25)', is mandatory;
    column object_type =>
        type is 'varchar(25)',
        max_length is 25,
        default is '',
    ;
    column object_id => type is 'int', default is '0';
};

use vars qw (
    %LOWERCASERIGHTNAMES
    %OBJECT_TYPES
    %TICKET_METAPRINCIPALS
);


=head1 rights

# queue rights are the sort of queue rights that can only be granted
# to real people or groups



=cut



%TICKET_METAPRINCIPALS = (
    owner     => 'The owner of a ticket',                # loc_pair
    requestor => 'The requestor of a ticket',            # loc_pair
    cc        => 'The CC of a ticket',                   # loc_pair
    admin_cc  => 'The administrative CC of a ticket',    # loc_pair
);



=head2 load_by_cols PARAMHASH

Load an ACE by specifying a paramhash with the following fields:

    principal  => undef,
    type       => undef,
    right_name => undef,

And either:

    object => undef,

or

    object_type => undef,
    object_id   => undef

=cut

sub load_by_cols {
    my $self = shift;
    my %args = ( @_ );

    if ( $args{'object'} || defined $args{'object_id'} || $args{'object_type'} ) {
        my ( $object, $object_type, $object_id ) = $self->_parse_object_arg(%args);
        unless ($object) {
            return ( 0, _("System error. Right not granted.") );
        }
        delete $args{'object'};
        $args{'object_type'} = $object_type;
        $args{'object_id'} = $object_id;
    }

    if ( defined $args{'principal'} ) {
        my ($group, $msg) = $self->principal_to_acl_group( $args{'principal'} );
        unless ( $group ) {
            return ( 0, $msg );
        }
        $args{'principal'} = $group->id;
    }

    $self->SUPER::load_by_cols( %args );
    unless ( $self->id ) {
        return ( 0, _("ACE not found") );
    }

    # if we could
    return ( $self->id, _("Right Loaded") );
}

=head2 create <PARAMS>

PARAMS is a parameter hash with the following elements:

   principal => The id of an RT::Model::Principal object
   type => "User" "Group" or any Role type
   right_name => the name of a right. in any case


    Either:

   object => An object to create rights for. ususally, an RT::Model::Queue or RT::Model::Group
             This should always be a Jifty::DBI::Record subclass

        OR

   object_type => the type of the object in question (ref ($object))
   object_id => the id of the object in question $object->id



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's false.



=cut

sub create {
    my $self = shift;
    my %args = (
        principal  => undef,
        type       => undef,
        right_name => undef,
        object     => undef,
        @_
    );

    unless ( $args{'right_name'} ) {
        return ( 0, _('No right specified') );
    }

    #if we haven't specified any sort of object, we're talking about a global right
    if (   !defined $args{'object'}
        && !defined $args{'object_id'}
        && !defined $args{'object_type'} )
    {
        $args{'object'} = RT->system;
    }
    ( $args{'object'}, $args{'object_type'}, $args{'object_id'} ) = $self->_parse_object_arg(%args);
    unless ( $args{'object'} ) {
        return ( 0, _("System error. Right not granted.") );
    }

    my ($acl_group, $msg) = $self->principal_to_acl_group( $args{'principal'} );
    unless ( $acl_group ) {
        return ( 0, $msg );
    }

    $args{'type'} ||= $acl_group->type_for_acl;

    # {{{ Check the ACL

    if ( $args{'object'}->isa('RT::Model::Group') ) {
        unless (
            $self->current_user->has_right(
                object => $args{'object'},
                right  => 'AdminGroup'
            )
            )
        {
            return ( 0, _('Permission Denied') );
        }
    }

    else {
        unless (
            $self->current_user->has_right(
                object => $args{'object'},
                right  => 'ModifyACL'
            )
            )
        {
            return ( 0, _('Permission Denied') );
        }
    }

    # }}}

    # {{{ canonicalize_ and check the right name
    my $canonic_name = $self->canonicalize_right_name( $args{'right_name'} );
    unless ($canonic_name) {
        return (
            0,
            _(
                "Invalid right. Couldn't canonicalize right '%1'",
                $args{'right_name'}
            )
        );
    }
    $args{'right_name'} = $canonic_name;

    #check if it's a valid right_name
    if ( $args{'object'}->can('available_rights') ) {
        unless ( exists $args{'object'}->available_rights->{ $args{'right_name'} } ) {
            Jifty->log->warn( "Couldn't validate right name '$args{'right_name'}'" . " for object of " . ref( $args{'object'} ) . " class" );
            return ( 0, _('Invalid right') );
        }
    }

    # }}}

    # Make sure the right doesn't already exist.
    $self->load_by_cols(
        principal   => $acl_group->id,
        type        => $args{'type'},
        right_name  => $args{'right_name'},
        object_type => $args{'object_type'},
        object_id   => $args{'object_id'},
    );
    if ( $self->id ) {
        return ( 0, _('That principal already has that right') );
    }

    my $id = $self->SUPER::create(
        principal   => $acl_group->id,
        type        => $args{'type'},
        right_name  => $args{'right_name'},
        object_type => ref( $args{'object'} ),
        object_id   => $args{'object'}->id,
    );

    #Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    RT::Model::Principal->invalidate_acl_cache();

    if ($id) {
        return ( $id, _('Right granted') );
    } else {
        return ( 0, _('System error. Right not granted.') );
    }
}

=head2 delete

Delete this object. This method should ONLY ever be called from RT::Model::User or RT::Model::Group (or from itself)

=cut

sub check_delete_rights {
    my $self = shift;

    return $self->current_user->has_right(
        right  => 'ModifyACL',
        object => $self->object,
    );
    return 1;
}

=head2 delete

Delete this record object from the database.

=cut

sub delete {
    my $self = shift;
    my ($rv) = $self->SUPER::delete;
    if ($rv) {
        return ( $rv, _("Right revoked") );
    } else {

        return ( 0, _("Right could not be revoked") );
    }
}

# Helper for Delete with no ACL check
sub _delete { return (shift)->__delete( @_ ) }
sub __delete {
    my $self = shift;

    my $inside_transaction = Jifty->handle->transaction_depth;
    Jifty->handle->begin_transaction unless $inside_transaction;

    my ($status, $msg) = $self->SUPER::__delete(@_);
    unless ( $status ) {
        Jifty->handle->rollback unless $inside_transaction;
        return ( 0, _('Right could not be revoked') );
    }

    # Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    # TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();
    Jifty->handle->commit unless $inside_transaction;
    return ( 1, _('Right revoked') );
}


=head2 canonicalize_right_name <RIGHT>

Takes a queue or system right name in any case and returns it in
the correct case. If it's not found, will return undef.

=cut

sub canonicalize_right_name {
    my $self  = shift;
    my $right = shift;
    return $LOWERCASERIGHTNAMES{ lc $right } || $right;
}



=head2 object

If the object this ACE applies to is a queue, returns the queue object. 
If the object this ACE applies to is a group, returns the group object. 
If it's the system object, returns undef. 

If the user has no rights, returns undef.

=cut

sub object {
    my $self = shift;

    my $appliesto_obj;

    if (   $self->__value('object_type')
        && $OBJECT_TYPES{ $self->__value('object_type') } )
    {
        $appliesto_obj = $self->__value('object_type')->new;
        unless ( ref($appliesto_obj) eq $self->__value('object_type') ) {
            return undef;
        }
        $appliesto_obj->load( $self->__value('object_id') );
        return ($appliesto_obj);
    } else {
        Jifty->log->warn( "$self -> object called for an object " . "of an unknown type:" . $self->__value('object_type') );
        return (undef);
    }
}



=head2 principal

Returns the L<RT::Model::Principal> object for this ACE. 

=cut

sub _set {
    my $self = shift;
    return ( 0, _("ACEs can only be created and deleted.") );
}

sub _value {
    my $self = shift;

    if ( $self->principal->is_group
        && $self->principal->object->has_member( principal =>  $self->current_user->principal, recursively => 1 ) )
    {
        return ( $self->__value(@_) );
    } elsif (
        $self->current_user->has_right(
            right  => 'ShowACL',
            object => $self->object
        )
        )
    {
        return ( $self->__value(@_) );
    } else {
        return undef;
    }
}

=head2 principal_to_acl_group

Takes a principal either an object or id. Resolves it to the proper acl
equivalence group. Returns a tuple of (L<RT::Model::Group>, message). On
errors object is empty and message is the error.

=cut

sub principal_to_acl_group {
    my $self = shift;
    my $principal = shift;

    return $principal->acl_equivalence_group
        if blessed $principal;

    my $tmp = RT::Model::Principal->new( current_user => $self->current_user );
    $tmp->load( $principal );
    unless ( $tmp->id ) {
        return (undef, _( 'Principal %1 not found.', $principal ));
        return undef;
    }
    return $tmp->acl_equivalence_group;
}

sub _parse_object_arg {
    my $self = shift;
    my %args = (
        object      => undef,
        object_id   => undef,
        object_type => undef,
        @_
    );

    if ( $args{'object'} && ( $args{'object_id'} || $args{'object_type'} ) ) {
        Jifty->log->fatal( "Method called with an object_type or an object_id and object args" );
        return ();
    } elsif ( $args{'object'} && !UNIVERSAL::can( $args{'object'}, 'id' ) ) {
        Jifty->log->fatal("Method called with object that has no id method");
        return ();
    } elsif ( $args{'object'} ) {
        my $obj = $args{'object'};
        return ( $obj, ref $obj, $obj->id );
    } elsif ( $args{'object_type'} ) {
        my $obj = $args{'object_type'}->new;
        $obj->load( $args{'object_id'} );
        return ( $obj, ref $obj, $obj->id );
    } else {
        Carp::confess;
        Jifty->log->fatal("Method called with wrong args");
        return ();
    }
}

1;
