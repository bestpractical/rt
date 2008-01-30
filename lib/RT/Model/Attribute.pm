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

use warnings;
use strict;

package RT::Model::Attribute;

use Storable qw/nfreeze thaw/;
use MIME::Base64;

sub table {'Attributes'}

use base 'RT::Record';
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column object_id => max_length is 11, type is 'int(11)', default is '0';
    column name => max_length is 200, type is 'varchar(200)', default is '';
    column
        object_type => max_length is 200,
        type is 'varchar(200)', default is '';
    column
        description => max_length is 255,
        type is 'varchar(255)', default is '';
    column
        content_type => max_length is 255,
        type is 'varchar(255)', default is '';
    column content => type is 'blob', default is '';

};

=head1 name

  RT::Model::Attribute 

=head1 content

=cut

# the acl map is a map of "name of attribute" and "what right the user must have on the associated object to see/edit it

our $ACL_MAP = {
    SavedSearch => {
        create  => 'EditSavedSearches',
        update  => 'EditSavedSearches',
        delete  => 'EditSavedSearches',
        display => 'ShowSavedSearches'
    },

};

# There are a number of attributes that users should be able to modify for themselves, such as saved searches
#  we could do this with a different set of "modify" rights, but that gets very hacky very fast. this is even faster and even
# hackier. we're hardcoding that a different set of rights are needed for attributes on oneself
our $PERSONAL_ACL_MAP = {
    SavedSearch => {
        create  => 'ModifySelf',
        update  => 'ModifySelf',
        delete  => 'ModifySelf',
        display => 'allow'
    },

};

=head2 Lookupobjectright { object_type => undef, object_id => undef, name => undef, right => { create, update, delete, display } }

Returns the right that the user needs to have on this attribute's object to perform the related attribute operation. Returns "allow" if the right is otherwise unspecified.

=cut

sub lookup_object_right {
    my $self = shift;
    my %args = (
        object_type => undef,
        object_id   => undef,
        right       => undef,
        name        => undef,
        @_
    );

    # if it's an attribute on oneself, check the personal acl map
    if (   ( $args{'object_type'} eq 'RT::Model::User' )
        && ( $args{'object_id'} eq $self->current_user->id ) )
    {
        return ('allow') unless ( $PERSONAL_ACL_MAP->{ $args{'name'} } );
        return ('allow')
            unless (
            $PERSONAL_ACL_MAP->{ $args{'name'} }->{ $args{'right'} } );
        return ( $PERSONAL_ACL_MAP->{ $args{'name'} }->{ $args{'right'} } );

    }

    # otherwise check the main ACL map
    else {
        return ('allow') unless ( $ACL_MAP->{ $args{'name'} } );
        return ('allow')
            unless ( $ACL_MAP->{ $args{'name'} }->{ $args{'right'} } );
        return ( $ACL_MAP->{ $args{'name'} }->{ $args{'right'} } );
    }
}

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'name'.
  varchar(255) 'content'.
  varchar(16) 'content_type',
  varchar(64) 'object_type'.
  int(11) 'object_id'.

You may pass a C<object> instead of C<object_type> and C<object_id>.

=cut

sub create {
    my $self = shift;
    my %args = (
        name        => '',
        description => '',
        content     => '',
        content_type => '',
        object      => undef,
        @_
    );

    if ( $args{object} and UNIVERSAL::can( $args{object}, 'id' ) ) {
        $args{object_type} = ref( $args{object} );
        $args{object_id}   = $args{object}->id;
    } else {
        return ( 0, _( "Required parameter '%1' not specified", 'object' ) );

    }

    Carp::confess unless $self->current_user;

# object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->lookup_object_right(
        right       => 'create',
        object_id   => $args{'object_id'},
        object_type => $args{'object_type'},
        name        => $args{'name'}
    );
    if ( $object_right eq 'deny' ) {
        return ( 0, _('Permission Denied') );
    } elsif ( $object_right eq 'allow' ) {

        # do nothing, we're ok
    }

    elsif (
        !$self->current_user->has_right(
            object => $args{object},
            right  => $object_right
        )
        )
    {
        return ( 0, _('Permission Denied') );
    }

    if ( ref( $args{'content'} ) ) {
        eval {
            $args{'content'} = $self->_serialize_content( $args{'content'} );
        };
        if ($@) {
            return ( 0, $@ );
        }
        $args{'content_type'} = 'storable';
    }

    $self->SUPER::create(
        name        => $args{'name'},
        content     => $args{'content'},
        content_type => $args{'content_type'},
        description => $args{'description'},
        object_type => $args{'object_type'},
        object_id   => $args{'object_id'},
    );

}

# {{{ sub load_by_nameAndobject

=head2  load_by_nameAndobject (object => OBJECT, name => name)

Loads the Attribute named name for object OBJECT.

=cut

sub load_by_name_and_object {
    my $self = shift;
    my %args = (
        object => undef,
        name   => undef,
        @_,
    );

    return (
        $self->load_by_cols(
            name        => $args{'name'},
            object_type => ref( $args{'object'} ),
            object_id   => $args{'object'}->id,
        )
    );

}

# }}}

=head2 _DeserializeContent

DeserializeContent returns this Attribute's "content" as a hashref.


=cut

sub _deserialize_content {
    my $self    = shift;
    my $content = shift;

    my $hashref;
    eval { $hashref = thaw( decode_base64($content) ) };
    if ($@) {
        Jifty->log->error(
            "Deserialization of attribute " . $self->id . " failed" );
    }

    return ($hashref);

}

=head2 content

Returns this attribute's content. If it's a scalar, returns a scalar
If it's data structure returns a ref to that data structure.

=cut

sub content {
    my $self = shift;

    # Here we call _value to get the ACL check.
    my $content = $self->_value('content');
    if ( $self->__value('content_type') eq 'storable' ) {
        eval { $content = $self->_deserialize_content($content); };
        if ($@) {
            Jifty->log->error( "Deserialization of content for attribute "
                    . $self->id
                    . " failed. Attribute was: "
                    . $content );
        }
    }

    return ($content);

}

sub _serialize_content {
    my $self    = shift;
    my $content = shift;
    return ( encode_base64( nfreeze($content) ) );
}

sub set_content {
    my $self    = shift;
    my $content = shift;

    # Call __value to avoid ACL check.
    if ( $self->__value('content_type') eq 'storable' ) {

        # We eval the serialization because it will lose on a coderef.
        $content = eval { $self->_serialize_content($content) };
        if ($@) {
            Jifty->log->error("Content couldn't be frozen: $@");
            return ( 0, "Content couldn't be frozen" );
        }
    }
    return $self->_set( column => 'content', value => $content );
}

=head2 SubValue KEY

Returns the subvalue for $key.


=cut

sub sub_value {
    my $self   = shift;
    my $key    = shift;
    my $values = $self->content();
    return undef unless ref($values);
    return ( $values->{$key} );
}

=head2 DeleteSubValue name

Deletes the subvalue with the key name

=cut

sub delete_sub_value {
    my $self   = shift;
    my $key    = shift;
    my %values = $self->content();
    delete $values{$key};
    $self->set_content(%values);

}

=head2 DeleteAllSubValues 

Deletes all subvalues for this attribute

=cut

sub delete_all_sub_values {
    my $self = shift;
    $self->set_content( {} );
}

=head2 SetSubValues  {  }

Takes a hash of keys and values and stores them in the content of this attribute.

Each key B<replaces> the existing key with the same name

Returns a tuple of (status, message)

=cut

sub set_sub_values {
    my $self   = shift;
    my %args   = (@_);
    my $values = ( $self->content() || {} );
    foreach my $key ( keys %args ) {
        $values->{$key} = $args{$key};
    }

    $self->set_content($values);

}

sub object {
    my $self        = shift;
    my $object_type = $self->__value('object_type');
    my $object;
    eval { $object = $object_type->new };
    unless ( UNIVERSAL::isa( $object, $object_type ) ) {
        Jifty->log->error( "Attribute "
                . $self->id
                . " has a bogus object type - $object_type ("
                . $@
                . ")" );
        return (undef);
    }
    $object->load( $self->__value('object_id') );

    return ($object);

}

sub delete {
    my $self = shift;
    unless ( $self->current_user_has_right('delete') ) {
        return ( 0, _('Permission Denied') );
    }
    return ( $self->SUPER::delete(@_) );
}

sub _value {
    my $self = shift;
    unless ( $self->current_user_has_right('display') ) {
        return ( 0, _('Permission Denied') );
    }

    return ( $self->SUPER::_value(@_) );

}

sub _set {
    my $self = shift;
    unless ( $self->current_user_has_right('modify') ) {

        return ( 0, _('Permission Denied') );
    }
    return ( $self->SUPER::_set(@_) );

}

=head2 current_user_has_right

One of "display" "modify" "delete" or "create" and returns 1 if the user has that right for attributes of this name for this object.Returns undef otherwise.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;

# object_right is the right that the user has to have on the object for them to have $right on this attribute
    my $object_right = $self->lookup_object_right(
        right       => $right,
        object_id   => $self->__value('object_id'),
        object_type => $self->__value('object_type'),
        name        => $self->__value('name')
    );

    return (1) if ( $object_right eq 'allow' );
    return (0) if ( $object_right eq 'deny' );
    return (1)
        if (
        $self->current_user->has_right(
            object => $self->object,
            right  => $object_right
        )
        );
    return (0);

}

=head1 TODO

We should be deserializing the content on load and then enver again, rather than at every access

=cut

1;
