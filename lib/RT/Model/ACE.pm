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
  my $ace = RT::Model::ACE->new($CurrentUser);


=head1 DESCRIPTION



=head1 METHODS


=cut

package RT::Model::ACE;

use strict;
no warnings qw(redefine);
use RT::Model::PrincipalCollection;
use RT::Model::QueueCollection;
use RT::Model::GroupCollection;

use base qw/RT::Record/;

sub table {'ACL'}

use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column
        principal_type => max_length is 25,
        type is 'varchar(25)', default is '';
    column principal_id => type is 'int(11)', default is '0';
    column
        right_name => max_length is 25,
        type is 'varchar(25)', default is '';
    column
        object_type => max_length is 25,
        type is 'varchar(25)', default is '';
    column object_id     => type is 'int(11)', default is '0';
    column DelegatedBy   => type is 'int(11)', default is '0';
    column DelegatedFrom => type is 'int(11)', default is '0';
};

use vars qw (
    %LOWERCASERIGHTNAMES
    %OBJECT_TYPES
    %TICKET_METAPRINCIPALS
);

# {{{ Descriptions of rights

=head1 Rights

# Queue rights are the sort of queue rights that can only be granted
# to real people or groups



=cut

# }}}

# {{{ Descriptions of principals

%TICKET_METAPRINCIPALS = (
    Owner     => 'The owner of a ticket',                # loc_pair
    Requestor => 'The requestor of a ticket',            # loc_pair
    Cc        => 'The CC of a ticket',                   # loc_pair
    AdminCc   => 'The administrative CC of a ticket',    # loc_pair
);

# }}}

# {{{ sub load_by_values

=head2 LoadByValues PARAMHASH

Load an ACE by specifying a paramhash with the following fields:

              principal_id => undef,
              principal_type => undef,
	      right_name => undef,

        And either:

	      Object => undef,

            OR

	      object_type => undef,
	      object_id => undef

=cut

sub load_by_values {
    my $self = shift;
    my %args = (
        principal_id   => undef,
        principal_type => undef,
        right_name     => undef,
        Object         => undef,
        object_id      => undef,
        object_type    => undef,
        @_
    );

    my $princ_obj;
    ( $princ_obj, $args{'principal_type'} )
        = $self->canonicalize_principal( $args{'principal_id'},
        $args{'principal_type'} );

    unless ( $princ_obj->id ) {
        return ( 0, _( 'Principal %1 not found.', $args{'principal_id'} ) );
    }

    my ( $object, $object_type, $object_id )
        = $self->_parse_object_arg(%args);
    unless ($object) {
        return ( 0, _("System error. Right not granted.") );
    }

    $self->load_by_cols(
        principal_id   => $princ_obj->id,
        principal_type => $args{'principal_type'},
        right_name     => $args{'right_name'},
        object_type    => $object_type,
        object_id      => $object_id
    );

    #If we couldn't load it.
    unless ( $self->id ) {
        return ( 0, _("ACE not found") );
    }

    # if we could
    return ( $self->id, _("Right Loaded") );

}

# }}}

# {{{ sub create

=head2 Create <PARAMS>

PARAMS is a parameter hash with the following elements:

   principal_id => The id of an RT::Model::Principal object
   principal_type => "User" "Group" or any Role type
   right_name => the name of a right. in any case
   DelegatedBy => The Principal->id of the user delegating the right
   DelegatedFrom => The id of the ACE which this new ACE is delegated from


    Either:

   Object => An object to create rights for. ususally, an RT::Model::Queue or RT::Model::Group
             This should always be a Jifty::DBI::Record subclass

        OR

   object_type => the type of the object in question (ref ($object))
   object_id => the id of the object in question $object->id



   Returns a tuple of (STATUS, MESSAGE);  If the call succeeded, STATUS is true. Otherwise it's false.



=cut

sub create {
    my $self = shift;
    my %args = (
        principal_id   => undef,
        principal_type => undef,
        right_name     => undef,
        Object         => undef,
        @_
    );

    unless ( $args{'right_name'} ) {
        return ( 0, _('No right specified') );
    }

#if we haven't specified any sort of right, we're talking about a global right
    if (   !defined $args{'Object'}
        && !defined $args{'object_id'}
        && !defined $args{'object_type'} )
    {
        $args{'Object'} = RT->system;
    }
    ( $args{'Object'}, $args{'object_type'}, $args{'object_id'} )
        = $self->_parse_object_arg(%args);
    unless ( $args{'Object'} ) {
        return ( 0, _("System error. Right not granted.") );
    }

    # {{{ Validate the principal
    my $princ_obj;
    ( $princ_obj, $args{'principal_type'} )
        = $self->canonicalize_principal( $args{'principal_id'},
        $args{'principal_type'} );

    unless ( $princ_obj->id ) {
        return ( 0, _( 'Principal %1 not found.', $args{'principal_id'} ) );
    }

    # }}}

    # {{{ Check the ACL

    if ( ref( $args{'Object'} ) eq 'RT::Model::Group' ) {
        unless (
            $self->current_user->has_right(
                Object => $args{'Object'},
                Right  => 'AdminGroup'
            )
            )
        {
            return ( 0, _('Permission Denied') );
        }
    }

    else {
        unless (
            $self->current_user->has_right(
                Object => $args{'Object'},
                Right  => 'ModifyACL'
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
            _(  "Invalid right. Couldn't canonicalize_ right '$args{'right_name'}'"
            )
        );
    }
    $args{'right_name'} = $canonic_name;

    #check if it's a valid right_name
    if ( $args{'Object'}->can('available_rights') ) {
        unless (
            exists $args{'Object'}
            ->available_rights->{ $args{'right_name'} } )
        {
            Jifty->log->warn(
                      "Couldn't validate right name '$args{'right_name'}'"
                    . " for object of "
                    . ref( $args{'Object'} )
                    . " class" );
            return ( 0, _('Invalid right') );
        }
    }

    # }}}

    # Make sure the right doesn't already exist.
    $self->load_by_cols(
        principal_id   => $princ_obj->id,
        principal_type => $args{'principal_type'},
        right_name     => $args{'right_name'},
        object_type    => $args{'object_type'},
        object_id      => $args{'object_id'},
        DelegatedBy    => 0,
        DelegatedFrom  => 0
    );
    if ( $self->id ) {
        return ( 0, _('That principal already has that right') );
    }

    my $id = $self->SUPER::create(
        principal_id   => $princ_obj->id,
        principal_type => $args{'principal_type'},
        right_name     => $args{'right_name'},
        object_type    => ref( $args{'Object'} ),
        object_id      => $args{'Object'}->id,
        DelegatedBy    => 0,
        DelegatedFrom  => 0
    );

#Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
    RT::Model::Principal->invalidate_acl_cache();

    if ($id) {
        return ( $id, _('Right Granted') );
    } else {
        return ( 0, _('System error. Right not granted.') );
    }
}

# }}}

# {{{ sub Delegate

=head2 Delegate <PARAMS>

This routine delegates the current ACE to a principal specified by the
B<principal_id>  parameter.

Returns an error if the current user doesn't have the right to be delegated
or doesn't have the right to delegate rights.

Always returns a tuple of (ReturnValue, Message)


=cut

sub delegate {
    my $self = shift;
    my %args = (
        principal_id => undef,
        @_
    );

    unless ( $self->id ) {
        return ( 0, _("Right not loaded.") );
    }
    my $princ_obj;
    ( $princ_obj, $args{'principal_type'} )
        = $self->canonicalize_principal( $args{'principal_id'},
        $args{'principal_type'} );

    unless ( $princ_obj->id ) {
        return ( 0, _( 'Principal %1 not found.', $args{'principal_id'} ) );
    }

    # }}}

    # {{{ Check the ACL

    # First, we check to se if the user is delegating rights and
    # they have the permission to
    unless (
        $self->current_user->has_right(
            Right  => 'DelegateRights',
            Object => $self->object
        )
        )
    {
        return ( 0, _("Permission Denied") );
    }

    unless ( $self->principal_object->is_group ) {
        return ( 0, _("System Error") );
    }
    unless (
        $self->principal_object->object->has_member_recursively(
            $self->current_user->principal_object
        )
        )
    {
        return ( 0, _("Permission Denied") );
    }

    # }}}

    my $concurrency_check
        = RT::Model::ACE->new( current_user => RT->system_user );
    $concurrency_check->load( $self->id );
    unless ( $concurrency_check->id ) {
        Jifty->log->fatal(
            "Trying to delegate a right which had already been deleted");
        return ( 0, _('Permission Denied') );
    }

    my $delegated_ace = RT::Model::ACE->new;

    # Make sure the right doesn't already exist.
    $delegated_ace->load_by_cols(
        principal_id   => $princ_obj->id,
        principal_type => 'Group',
        right_name     => $self->__value('right_name'),
        object_type    => $self->__value('object_type'),
        object_id      => $self->__value('object_id'),
        DelegatedBy    => $self->current_user->id,
        DelegatedFrom  => $self->id
    );
    if ( $delegated_ace->id ) {
        return ( 0, _('That principal already has that right') );
    }
    my $id = $delegated_ace->SUPER::create(
        principal_id   => $princ_obj->id,
        principal_type => 'Group',          # do we want to hardcode this?
        right_name    => $self->__value('right_name'),
        object_type   => $self->__value('object_type'),
        object_id     => $self->__value('object_id'),
        DelegatedBy   => $self->current_user->id,
        DelegatedFrom => $self->id
    );

#Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
# TODO what about the groups key cache?
    RT::Model::Principal->invalidate_acl_cache();

    if ( $id > 0 ) {
        return ( $id, _('Right Delegated') );
    } else {
        return ( 0, _('System error. Right not delegated.') );
    }
}

# }}}

# {{{ sub delete

=head2 Delete { inside_transaction => undef}

Delete this object. This method should ONLY ever be called from RT::Model::User or RT::Model::Group (or from itself)
If this is being called from within a transaction, specify a true value for the parameter inside_transaction.
Really, Jifty::DBI should use and/or fake subtransactions

This routine will also recurse and delete any delegations of this right

=cut

sub delete {
    my $self = shift;

    unless ( $self->id ) {
        return ( 0, _('Right not loaded.') );
    }

# A user can delete an ACE if the current user has the right to modify it and it's not a delegated ACE
# or if it's a delegated ACE and it was delegated by the current user
    unless (
        (   $self->current_user->has_right(
                Right  => 'ModifyACL',
                Object => $self->object
            )
            && $self->__value('DelegatedBy') == 0
        )
        || ( $self->__value('DelegatedBy') == $self->current_user->id )
        )
    {
        return ( 0, _('Permission Denied') );
    }
    $self->_delete(@_);
}

# Helper for Delete with no ACL check
sub _delete {
    my $self = shift;
    my %args = (
        inside_transaction => undef,
        @_
    );

    my $inside_transaction = $args{'inside_transaction'};

    Jifty->handle->begin_transaction() unless $inside_transaction;

    my $delegated_from_this
        = RT::Model::ACECollection->new( current_user => RT->system_user );
    $delegated_from_this->limit(
        column   => 'DelegatedFrom',
        operator => '=',
        value    => $self->id
    );

    my $delete_succeeded = 1;
    my $submsg;
    while ( my $delegated_ace = $delegated_from_this->next ) {
        ( $delete_succeeded, $submsg )
            = $delegated_ace->_delete( inside_transaction => 1 );
        last unless ($delete_succeeded);
    }

    unless ($delete_succeeded) {
        Jifty->handle->rollback() unless $inside_transaction;
        return ( 0, _('Right could not be revoked') );
    }

    my ( $val, $msg ) = $self->SUPER::delete(@_);

    # If we're revoking delegation rights (see above), we may need to
    # revoke all rights delegated by the recipient.
    if ($val
        and (  $self->right_name() eq 'DelegateRights'
            or $self->right_name() eq 'SuperUser' )
        )
    {
        $val = $self->principal_object->_cleanup_invalid_delegations(
            inside_transaction => 1 );
    }

    if ($val) {

#Clear the key cache. TODO someday we may want to just clear a little bit of the keycache space.
# TODO what about the groups key cache?
        RT::Model::Principal->invalidate_acl_cache();
        Jifty->handle->commit() unless $inside_transaction;
        return ( $val, _('Right revoked') );
    }

    Jifty->handle->rollback() unless $inside_transaction;
    return ( 0, _('Right could not be revoked') );
}

# }}}

# {{{ sub _bootstrap_create

=head2 _bootstrap_create

Grant a right with no error checking and no ACL. this is _only_ for 
installation. If you use this routine without the author's explicit 
written approval, he will hunt you down and make you spend eternity
translating mozilla's code into FORTRAN or intercal.

If you think you need this routine, you've mistaken. 

=cut

sub _bootstrap_create {
    my $self = shift;
    my %args = (@_);

    # When bootstrapping, make sure we get the _right_ users
    if ( $args{'UserId'} ) {
        my $user = RT::Model::User->new;
        $user->load( $args{'UserId'} );
        delete $args{'UserId'};
        $args{'principal_id'}   = $user->principal_id;
        $args{'principal_type'} = 'User';
    }

    my $id = $self->SUPER::create(%args);

    if ( $id > 0 ) {
        return ($id);
    } else {
        Jifty->log->err('System error. right not granted.');
        return (undef);
    }

}

# }}}

# {{{ sub canonicalize_right_name

=head2 canonicalize_right_name <RIGHT>

Takes a queue or system right name in any case and returns it in
the correct case. If it's not found, will return undef.

=cut

sub canonicalize_right_name {
    my $self  = shift;
    my $right = shift;
    return $LOWERCASERIGHTNAMES{ lc $right } || $right;
}

# }}}

# {{{ sub Object

=head2 Object

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
        Jifty->log->warn( "$self -> Object called for an object "
                . "of an unknown type:"
                . $self->__value('object_type') );
        return (undef);
    }
}

# }}}

# {{{ sub principal_object

=head2 principal_object

Returns the RT::Model::Principal object for this ACE. 

=cut

sub principal_object {
    my $self = shift;

    my $princ_obj = RT::Model::Principal->new;
    $princ_obj->load( $self->__value('principal_id') );

    unless ( $princ_obj->id ) {
        Jifty->log->err( "ACE "
                . $self->id
                . " couldn't load its principal object - "
                . $self->__value('principal_id') );
    }
    return ($princ_obj);

}

# }}}

# {{{ ACL related methods

# {{{ sub _set

sub _set {
    my $self = shift;
    return ( 0, _("ACEs can only be Created and deleted.") );
}

# }}}

# {{{ sub _value

sub _value {
    my $self = shift;

    if ( $self->__value('DelegatedBy') eq $self->current_user->id ) {
        return ( $self->__value(@_) );
    } elsif (
        $self->principal_object->is_group
        && $self->principal_object->object->has_member_recursively(
            $self->current_user->principal_object
        )
        )
    {
        return ( $self->__value(@_) );
    } elsif (
        $self->current_user->has_right(
            Right  => 'ShowACL',
            Object => $self->object
        )
        )
    {
        return ( $self->__value(@_) );
    } else {
        return undef;
    }
}

# }}}

# }}}

# {{{ _canonicalize_Principal

=head2 _canonicalize_Principal (principal_id, principal_type)

Takes a principal id and an optional principal type.

If the principal is a user, resolves it to the proper acl equivalence group.
Returns a tuple of  (RT::Model::Principal, principal_type)  for the principal we really want to work with

=cut

sub canonicalize_principal {
    my $self       = shift;
    my $princ_id   = shift;
    my $princ_type = shift || 'Group';

    my $princ_obj
        = RT::Model::Principal->new( current_user => RT->system_user );
    $princ_obj->load($princ_id);

    unless ( $princ_obj->id ) {
        use Carp;
        Jifty->log->fatal(Carp::cluck);
        Jifty->log->fatal("Can't load a principal for id $princ_id");
        return ( $princ_obj, undef );
    }

    # Rights never get granted to users. they get granted to their
    # ACL equivalence groups
    if ( $princ_type eq 'User' ) {
        my $equiv_group = RT::Model::Group->new;
        $equiv_group->load_acl_equivalence_group($princ_obj);
        unless ( $equiv_group->id ) {
            Jifty->log->fatal(
                "No ACL equiv group for princ " . $princ_obj->id );
            return (
                RT::Model::Principal->new( current_user => RT->system_user ),
                undef
            );
        }
        $princ_obj  = $equiv_group->principal_object();
        $princ_type = 'Group';

    }
    return ( $princ_obj, $princ_type );
}

sub _parse_object_arg {
    my $self = shift;
    my %args = (
        Object      => undef,
        object_id   => undef,
        object_type => undef,
        @_
    );

    if ( $args{'Object'} && ( $args{'object_id'} || $args{'object_type'} ) ) {
        Jifty->log->fatal(
            "Method called with an object_type or an object_id and Object args"
        );
        return ();
    } elsif ( $args{'Object'} && !UNIVERSAL::can( $args{'Object'}, 'id' ) ) {
        Jifty->log->fatal(
            "Method called called Object that has no id method");
        return ();
    } elsif ( $args{'Object'} ) {
        my $obj = $args{'Object'};
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

# }}}
1;
