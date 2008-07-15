# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
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

=head1 NAME

RT::SharedSetting - an API for settings that belong to an RT::Model::User or RT::Model::Group

=head1 SYNOPSIS

  use RT::SharedSetting;

=head1 DESCRIPTION

A RT::SharedSetting is an object that can belong to an L<RT::Model::User> or an <RT::Model::Group>.
It consists of an ID, a name, and some arbitrary data.

=cut

package RT::SharedSetting;
use strict;
use warnings;
use RT::Model::Attribute;
use base qw/RT::Base/;

=head1 METHODS

=head2 new

Returns a new L<RT::SharedSetting> object.
Takes the current user, see also L<RT::Base>.

=cut

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

Takes a privacy specification and a shared-setting ID.  Loads the given object
ID if it belongs to the stated user or group. Calls the L</post_load> method on
success for any further initialization. Returns a tuple of status and message,
where status is true on success.

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
            $self->post_load();

            return ( 0, $self->loc("Permission denied") )
              unless $self->current_user_can_see;

            return (
                1,
                $self->loc(
                    "Loaded %1 %2", $self->object_name, $self->name
                )
            );
        }
        else {
            Jifty->log->error(
                "Could not load attribute " . $id . " for object " . $privacy );
            return (
                0,
                $self->loc(
                    "Failed to load [_1] [_2]", $self->object_name, $id
                )
            );
        }
    }
    else {
        Jifty->log->warn( "Could not load object $privacy when loading "
              . $self->object_name );
        return ( 0, $self->loc( "Could not load object for [_1]", $privacy ) );
    }
}

=head2 load_by_id

First loads up the L<RT::Model::Attribute> for this shared setting by ID, then calls
L</Load> with the correct parameters. Returns a tuple of status and message,
where status is true on success.

=cut

sub load_by_id {
    my $self = shift;
    my $id   = shift;

    my $attr = RT::Model::Attribute->new( $self->current_user );
    my ( $ok, $msg ) = $attr->load_by_id($id);

    if ( !$ok ) {
        return (
            0,
            $self->loc(
                "Failed to load [_1] [_2]: [_3]", $self->object_name,
                $id,                              $msg
            )
        );
    }

    my $privacy = $self->_build_privacy( $attr->object_type, $attr->object_id );
    return ( 0, $self->loc( "Bad privacy for attribute [_1]", $id ) )
      if !$privacy;

    return $self->load( $privacy, $id );
}

=head2 post_load

Called after after successful L</Load>.

=cut

sub post_load { }

=head2 Save

Creates a new shared setting. Takes a privacy, a name, and any other arguments.
Saves the given parameters to the appropriate user/group object, and loads the
resulting object. Arguments are passed to the L</SaveAttribute> method, which
does the actual update. Returns a tuple of status and message, where status is
true on success. Defaults are:

  Privacy:  current_user only
  Name:     "new (object_name)"

=cut

sub save {
    my $self = shift;

    my %args = (
        'privacy' => 'RT::Model::User-' . $self->current_user->user_object->id,
        'name'    => "new " . $self->object_name,
        @_,
    );

    my $privacy = $args{'privacy'};
    my $name = $args{'name'}, my $object = $self->_get_object($privacy);

    return ( 0, $self->loc( "Failed to load object for [_1]", $privacy ) )
      unless $object;

    return ( 0, $self->loc("Permission denied") )
      unless $self->current_user_can_create($privacy);

    my ( $att_id, $att_msg ) = $self->save_attribute( $object, \%args );

    if ($att_id) {
        $self->{'attribute'} = $object->attributes->with_id($att_id);
        $self->{'id'}        = $att_id;
        $self->{'privacy'}   = $privacy;
        return ( 1, $self->loc( "Saved %1 %2", $self->object_name, $name ) );
    }
    else {
        Jifty->log->error( $self->object_name . " save failure: $att_msg" );
        return ( 0,
            $self->loc( "Failed to create [_1] attribute", $self->object_name )
        );
    }
}

=head2 SaveAttribute

An empty method for subclassing. Called from L</Save> method.

=cut

sub save_attribute { }

=head2 Update

Updates the parameters of an existing shared setting. Any arguments are passed
to the L</UpdateAttribute> method. Returns a tuple of status and message, where
status is true on success.

=cut

sub update {
    my $self = shift;
    my %args = @_;

    return ( 0, $self->loc( "No [_1] loaded", $self->object_name ) )
      unless $self->id;
    return ( 0,
        $self->loc( "Could not load [_1] attribute", $self->object_name ) )
      unless $self->{'attribute'}->id;

    return ( 0, $self->loc("Permission denied") )
      unless $self->current_user_can_modify;

    my ( $status, $msg ) = $self->update_attribute( \%args );

    return (
        1,
        $self->loc(
            "[_1] update: Nothing changed",
            ucfirst( $self->object_name )
        )
    ) if !defined $msg;

    # prevent useless warnings
    return ( 1, $self->loc("[_1] updated"), ucfirst( $self->object_name ) )
      if $msg =~ /That is already the current value/;

    return ( $status,
        $self->loc( "[_1] update: [_2]", ucfirst( $self->object_name ), $msg ) );
}

=head2 update_attribute

An empty method for subclassing. Called from L</Update> method.

=cut

sub update_attribute { }

=head2 delete
    
Deletes the existing shared setting. Returns a tuple of status and message,
where status is true upon success.

=cut

sub delete {
    my $self = shift;

    return ( 0, $self->loc("Permission denied") )
      unless $self->current_user_can_delete;

    my ( $status, $msg ) = $self->{'attribute'}->delete;
    if ($status) {
        return ( 1, $self->loc( "Deleted %1", $self->object_name ) );
    }
    else {
        return ( 0, $self->loc( "Delete failed: %1", $msg ) );
    }
}

### Accessor methods

=head2 name

Returns the name of this shared setting.

=cut

sub name {
    my $self = shift;
    return unless ref( $self->{'attribute'} ) eq 'RT::Model::Attribute';
    return $self->{'attribute'}->description();
}

=head2 id

Returns the numerical ID of this shared setting.

=cut

sub id {
    my $self = shift;
    return $self->{'id'};
}

=head2 privacy

Returns the principal object to whom this shared setting belongs, in a string
"<class>-<id>", e.g. "RT::Model::Group-16".

=cut

sub privacy {
    my $self = shift;
    return $self->{'privacy'};
}

=head2 get_parameter

Returns the given named parameter of the setting.

=cut

sub get_parameter {
    my $self  = shift;
    my $param = shift;
    return unless ref( $self->{'attribute'} ) eq 'RT::Model::Attribute';
    return $self->{'attribute'}->sub_value($param);
}

=head2 is_visible_to Privacy

Returns true if the setting is visible to all principals of the given privacy.
This does not deal with ACLs, this only looks at membership.

=cut

sub is_visible_to {
    my $self    = shift;
    my $to      = shift;
    my $privacy = $self->privacy;

    # if the privacies are the same, then they can be seen. this handles
    # a personal setting being visible to that user.
    return 1 if $privacy eq $to;

    # If the setting is systemwide, then any user can see it.
    return 1 if $privacy =~ /^RT::System/;

    # Only privacies that are RT::System can be seen by everyone.
    return 0 if $to =~ /^RT::System/;

    # If the setting is group-wide...
    if ( $privacy =~ /^RT::Model::Group-(\d+)$/ ) {
        my $setting_group = RT::Model::Group->new( $self->current_user );
        $setting_group->load($1);

        if ( $to =~ /-(\d+)$/ ) {
            my $to_id = $1;

            # then any principal that is a member of the setting's group can see
            # the setting
            return $setting_group->has_member_recursively($to_id);
        }
    }

    return 0;
}

sub current_user_can_see    { 1 }
sub current_user_can_create { 1 }
sub current_user_can_modify { 1 }
sub current_user_can_delete { 1 }

### Internal methods

# _GetObject: helper routine to load the correct object whose parameters
#  have been passed.

sub _get_object {
    my $self    = shift;
    my $privacy = shift;

    my ( $obj_type, $obj_id ) = split( /\-/, ( $privacy || '' ) );

    unless ( $obj_type && $obj_id ) {
        $privacy = '(undef)' if !defined($privacy);
        Jifty->log->debug("Invalid privacy string '$privacy'");
        return undef;
    }

    my $object = $self->_load_privacy_object( $obj_type, $obj_id );

    unless ( ref($object) eq $obj_type ) {
        Jifty->log->error(
"Could not load object of type $obj_type with ID $obj_id, got object of type "
              . ( ref($object) || 'undef' ) );
        return undef;
    }

    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if (   $obj_type eq 'RT::Model::User'
        && $object->id != $self->current_user->user_object->id )
    {
        Jifty->log->debug("Permission denied for user other than self");
        return undef;
    }

    if ( $obj_type eq 'RT::Model::Group'
        && !$object->has_member_recursively(
            $self->current_user->principal_object ) )
    {
        Jifty->log->debug( "Permission denied, "
              . $self->current_user->name
              . " is not a member of group" );
        return undef;
    }

    return $object;
}

sub _load_privacy_object {
    my ( $self, $obj_type, $obj_id ) = @_;
    if ( $obj_type eq 'RT::Model::User' ) {
        if ( $obj_id == $self->current_user->id ) {
            return $self->current_user->user_object;
        }
        else {
            Jifty->log->warn( "User #"
                  . $self->current_user->id
                  . " tried to load container user #"
                  . $obj_id );
            return undef;
        }
    }
    elsif ( $obj_type eq 'RT::Model::Group' ) {
        my $group = RT::Model::Group->new( current_user => $self->current_user );
        $group->load($obj_id);
        return $group;
    }
    elsif ( $obj_type eq 'RT::System' ) {
        return RT::System->new( $self->current_user );
    }

    Jifty->log->error( "Tried to load a "
          . $self->object_name
          . " belonging to an $obj_type, which is neither a user nor a group" );

    return undef;
}

sub _build_privacy {
    my ( $self, $obj_type, $obj_id ) = @_;

    # allow passing in just an object to find its privacy string
    if ( ref($obj_type) ) {
        my $Object = $obj_type;
        return
            $Object->isa('RT::Model::User')   ? 'RT::Model::User-' . $Object->id
          : $Object->isa('RT::Model::Group')  ? 'RT::Model::Group-' . $Object->id
          : $Object->isa('RT::System') ? 'RT::System-' . $Object->id
          :                              undef;
    }

    return undef unless ($obj_type);    # undef workaround
    return
        $obj_type eq 'RT::Model::User'   ? "$obj_type-$obj_id"
      : $obj_type eq 'RT::Model::Group'  ? "$obj_type-$obj_id"
      : $obj_type eq 'RT::System' ? "$obj_type-$obj_id"
      :                             undef;
}

1;
