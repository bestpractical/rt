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

=head1 name

  RT::SavedSearch - an API for saving and retrieving search form values.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 description

  SavedSearch is an object that can belong to either an RT::Model::User or an
  RT::Model::Group.  It consists of an ID, a description, and a number of
  search parameters.

=head1 METHODS


=cut

package RT::SavedSearch;

use RT::Base;
use RT::Model::Attribute;

use strict;
use warnings;
use base qw/RT::Base/;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{'id'} = 0;
    bless( $self, $class );
    $self->_get_current_user(@_);
    return $self;
}

=head2 load

Takes a privacy specification, an object ID, and a search ID.  Loads
the given search ID if it belongs to the stated user or group.
Returns a tuple of status and message, where status is true on
success.

=cut

sub load {
    my $self = shift;
    my ( $privacy, $id ) = @_;
    my $object = $self->_get_object($privacy);

    if ($object) {
        $self->{'attribute'} = $object->attributes->with_id($id);
        if ( $self->{'attribute'}->id ) {
            $self->{'id'}      = $self->{'attribute'}->id;
            $self->{'privacy'} = $privacy;
            $self->{'type'}    = $self->{'attribute'}->sub_value('SearchType');
            return ( 1, _( "Loaded search %1", $self->name ) );
        } else {
            Jifty->log->error( "Could not load attribute " . $id . " for object " . $privacy );
            return ( 0, _("Search attribute load failure") );
        }
    } else {
        Jifty->log->warn("Could not load object $privacy when loading search");
        return ( 0, _( "Could not load object for %1", $privacy ) );
    }

}

=head2 save

Takes a privacy, an optional type, a name, and a hashref containing the
search parameters.  Saves the given parameters to the appropriate user/
group object, and loads the resulting search.  Returns a tuple of status
and message, where status is true on success.  Defaults are:
  privacy:      undef
  Type:         Ticket
  name:         "new search"
  search_params: (empty hash)

=cut

sub save {
    my $self = shift;
    my %args = (
        'privacy'       => 'RT::Model::User-' . $self->current_user->id,
        'type'          => 'Ticket',
        'name'          => 'new search',
        'search_params' => {},
        @_
    );
    my $privacy = $args{'privacy'};
    my $type    = $args{'type'};
    my $name    = $args{'name'};
    my %params  = %{ $args{'search_params'} };

    $params{'SearchType'} = $type;
    my $object = $self->_get_object($privacy);

    return ( 0, _( "Failed to load object for %1", $privacy ) )
        unless $object;

    if ( $object->isa('RT::System') ) {
        return ( 0, _("No permission to save system-wide searches") )
            unless $self->current_user->has_right(
            object => RT->system,
            right  => 'SuperUser'
            );
    }

    my ( $att_id, $att_msg ) = $object->add_attribute(
        'name'        => 'SavedSearch',
        'description' => $name,
        'content'     => \%params
    );
    if ($att_id) {
        $self->{'attribute'} = $object->attributes->with_id($att_id);
        $self->{'id'}        = $att_id;
        $self->{'privacy'}   = $privacy;
        $self->{'type'}      = $type;
        return ( 1, _( "Saved search %1", $name ) );
    } else {
        Jifty->log->error("SavedSearch save failure: $att_msg");
        return ( 0, _("Failed to create search attribute") );
    }
}

=head2 update

Updates the parameters of an existing search.  Takes the arguments
"name" and "search_params"; search_params should be a hashref containing
the new parameters of the search.  If name is not specified, the name
will not be changed.

=cut

sub update {
    my $self = shift;
    my %args = (
        'name'          => '',
        'search_params' => {},
        @_
    );

    return ( 0, _("No search loaded") ) unless $self->id;
    return ( 0, _("Could not load search attribute") )
        unless $self->{'attribute'}->id;
    my ( $status, $msg ) = $self->{'attribute'}->set_sub_values( %{ $args{'search_params'} } );
    if ( $status && $args{'name'} ) {
        ( $status, $msg ) = $self->{'attribute'}->set_description( $args{'name'} );
    }
    return ( $status, _( "Search update: %1", $msg ) );
}

=head2 delete
    
Deletes the existing search.  Returns a tuple of status and message,
where status is true upon success.

=cut

sub delete {
    my $self = shift;

    my ( $status, $msg ) = $self->{'attribute'}->delete;
    if ($status) {

        # we need to do_search to refresh current user's attributes
        $self->current_user->user_object->attributes->_do_search;
        return ( 1, _("Deleted search") );
    } else {
        return ( 0, _( "Delete failed: %1", $msg ) );
    }
}

### Accessor methods

=head2 name

Returns the name of the search.

=cut

sub name {
    my $self = shift;
    return unless ref( $self->{'attribute'} ) eq 'RT::Model::Attribute';
    return $self->{'attribute'}->description();
}

=head2 get_parameter

Returns the given named parameter of the search, e.g. 'query', 'format'.

=cut

sub get_parameter {
    my $self  = shift;
    my $param = shift;
    return unless ref( $self->{'attribute'} ) eq 'RT::Model::Attribute';
    return $self->{'attribute'}->sub_value($param);
}

=head2 id

Returns the numerical id of this search.

=cut

sub id {
    my $self = shift;
    return $self->{'id'};
}

=head2 privacy

Returns the principal object to whom this search belongs, in a string
"<class>-<id>", e.g. "RT::Model::Group-16".

=cut

sub privacy {
    my $self = shift;
    return $self->{'privacy'};
}

=head2 type

Returns the type of this search, e.g. 'Ticket'.  Useful for denoting the
saved searches that are relevant to a particular search page.

=cut

sub type {
    my $self = shift;
    return $self->{'type'};
}

### Internal methods

sub _load_privacy_object {
    my ( $self, $obj_type, $obj_id ) = @_;
    if (   $obj_type eq 'RT::Model::User'
        && $obj_id == $self->current_user->id )
    {
        return $self->current_user->user_object;
    } elsif ( $obj_type eq 'RT::Model::Group' ) {
        my $group = RT::Model::Group->new;
        $group->load($obj_id);
        return $group;
    } elsif ( $obj_type eq 'RT::System' ) {
        return RT::System->new;
    }

    Jifty->log->error( "Tried to load a search belonging to an $obj_type ($obj_id), which is neither a user nor a group" );
    return undef;
}

# _Getobject: helper routine to load the correct object whose parameters
#  have been passed.

sub _get_object {
    my $self    = shift;
    my $privacy = shift;

    my ( $obj_type, $obj_id ) = split( /\-/, $privacy );

    my $object = $self->_load_privacy_object( $obj_type, $obj_id );

    unless ( ref($object) eq $obj_type ) {
        Jifty->log->error( "Could not load object of type $obj_type with ID $obj_id I AM " . $self->current_user->id );
        return undef;
    }

    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if (   $obj_type eq 'RT::Model::User'
        && $object->id != $self->current_user->user_object->id() )
    {
        Jifty->log->debug("Permission denied for user other than self");
        return undef;
    }
    if ( $obj_type eq 'RT::Model::Group'
        && !$object->has_member_recursively( $self->current_user->principal_object ) )
    {
        Jifty->log->debug( "Permission denied, " . $self->current_user->name . " is not a member of group" );
        return undef;
    }

    return $object;
}

1;
