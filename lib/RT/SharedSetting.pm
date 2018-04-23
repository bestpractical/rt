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

=head1 NAME

RT::SharedSetting - an API for settings that belong to an RT::User or RT::Group

=head1 SYNOPSIS

  use RT::SharedSetting;

=head1 DESCRIPTION

A RT::SharedSetting is an object that can belong to an L<RT::User> or an <RT::Group>.
It consists of an ID, a name, and some arbitrary data.

=cut

package RT::SharedSetting;
use strict;
use warnings;
use base qw/RT::Base/;

use RT::Attribute;
use Scalar::Util 'blessed';

=head1 METHODS

=head2 new

Returns a new L<RT::SharedSetting> object.
Takes the current user, see also L<RT::Base>.

=cut

sub new  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{'Id'} = 0;
    bless ($self, $class);
    $self->CurrentUser(@_);
    return $self;
}

=head2 Load

Takes a privacy specification and a shared-setting ID.  Loads the given object
ID if it belongs to the stated user or group. Calls the L</PostLoad> method on
success for any further initialization. Returns a tuple of status and message,
where status is true on success.

=cut

sub Load {
    my $self = shift;
    my ($privacy, $id) = @_;
    my $object = $self->_GetObject($privacy);

    if ($object) {
        $self->{'Attribute'} = RT::Attribute->new($self->CurrentUser);
        $self->{'Attribute'}->Load( $id );
        if ($self->{'Attribute'}->Id) {
            $self->{'Id'} = $self->{'Attribute'}->Id;
            $self->{'Privacy'} = $privacy;
            $self->PostLoad();

            return wantarray ? (0, $self->loc("Permission Denied")) : 0
                unless $self->CurrentUserCanSee;

            my ($ok, $msg) = $self->PostLoadValidate;
            return wantarray ? ($ok, $msg) : $ok if !$ok;

            return wantarray ? (1, $self->loc("Loaded [_1] [_2]", $self->ObjectName, $self->Name)) : 1;
        } else {
            $RT::Logger->error("Could not load attribute " . $id
                    . " for object " . $privacy);
            return wantarray ? (0, $self->loc("Failed to load [_1] [_2]", $self->ObjectName, $id)) : 0;
        }
    } else {
        $RT::Logger->warning("Could not load object $privacy when loading " . $self->ObjectName);
        return wantarray ? (0, $self->loc("Could not load object for [_1]", $privacy)) : 0;
    }
}

=head2 LoadById

First loads up the L<RT::Attribute> for this shared setting by ID, then calls
L</Load> with the correct parameters. Returns a tuple of status and message,
where status is true on success.

=cut

sub LoadById {
    my $self = shift;
    my $id   = shift;

    my $attr = RT::Attribute->new($self->CurrentUser);
    my ($ok, $msg) = $attr->LoadById($id);

    if (!$ok) {
        return wantarray ? (0, $self->loc("Failed to load [_1] [_2]: [_3]", $self->ObjectName, $id, $msg)) : 0;
    }

    my $privacy = $self->_build_privacy($attr->ObjectType, $attr->ObjectId);
    return wantarray ? (0, $self->loc("Bad privacy for attribute [_1]", $id)) : 0
        if !$privacy;

    return $self->Load($privacy, $id);
}

=head2 PostLoad

Called after a successful L</Load>.

=cut

sub PostLoad { }

=head2 PostLoadValidate

Called just before returning success from L</Load>; may be used to validate
that the record is correct. This method is expected to return a (ok, msg)
pair.

=cut

sub PostLoadValidate {
    return 1;
}

=head2 Save

Creates a new shared setting. Takes a privacy, a name, and any other arguments.
Saves the given parameters to the appropriate user/group object, and loads the
resulting object. Arguments are passed to the L</SaveAttribute> method, which
does the actual update. Returns a tuple of status and message, where status is
true on success. Defaults are:

  Privacy:  CurrentUser only
  Name:     "new (ObjectName)"

=cut

sub Save {
    my $self = shift;
    my %args = (
        'Privacy' => 'RT::User-' . $self->CurrentUser->Id,
        'Name'    => "new " . $self->ObjectName,
        @_,
    );

    my $privacy = $args{'Privacy'};
    my $name    = $args{'Name'},
    my $object  = $self->_GetObject($privacy);

    return (0, $self->loc("Failed to load object for [_1]", $privacy))
        unless $object;

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserCanCreate($privacy);

    my ($att_id, $att_msg) = $self->SaveAttribute($object, \%args);

    if ($att_id) {
        $self->{'Attribute'} = RT::Attribute->new($self->CurrentUser);
        $self->{'Attribute'}->Load( $att_id );
        $self->{'Id'}        = $att_id;
        $self->{'Privacy'}   = $privacy;
        return ( 1, $self->loc( "Saved [_1] [_2]", $self->loc( $self->ObjectName ), $name ) );
    }
    else {
        $RT::Logger->error($self->ObjectName . " save failure: $att_msg");
        return ( 0, $self->loc("Failed to create [_1] attribute", $self->loc( $self->ObjectName ) ) );
    }
}

=head2 SaveAttribute

An empty method for subclassing. Called from L</Save> method.

=cut

sub SaveAttribute { }

=head2 Update

Updates the parameters of an existing shared setting. Any arguments are passed
to the L</UpdateAttribute> method. Returns a tuple of status and message, where
status is true on success.

=cut

sub Update {
    my $self = shift;
    my %args = @_;

    return(0, $self->loc("No [_1] loaded", $self->ObjectName)) unless $self->Id;
    return(0, $self->loc("Could not load [_1] attribute", $self->ObjectName))
        unless $self->{'Attribute'}->Id;

    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserCanModify;

    my ($status, $msg) = $self->UpdateAttribute(\%args);

    return (1, $self->loc("[_1] update: Nothing changed", ucfirst($self->ObjectName)))
        if !defined $msg;

    # prevent useless warnings
    return (1, $self->loc("[_1] updated"), ucfirst($self->ObjectName))
        if $msg =~ /That is already the current value/;

    return ($status, $self->loc("[_1] update: [_2]", ucfirst($self->ObjectName), $msg));
}

=head2 UpdateAttribute

An empty method for subclassing. Called from L</Update> method.

=cut

sub UpdateAttribute { }

=head2 Delete
    
Deletes the existing shared setting. Returns a tuple of status and message,
where status is true upon success.

=cut

sub Delete {
    my $self = shift;
    return (0, $self->loc("Permission Denied"))
        unless $self->CurrentUserCanDelete;

    my ($status, $msg) = $self->{'Attribute'}->Delete;
    $self->CurrentUser->ClearAttributes; # force the current user's attribute cache to be cleaned up
    if ($status) {
        return (1, $self->loc("Deleted [_1]", $self->ObjectName));
    } else {
        return (0, $self->loc("Delete failed: [_1]", $msg));
    }
}

### Accessor methods

=head2 Name

Returns the name of this shared setting.

=cut

sub Name {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->Description();
}

=head2 Id

Returns the numerical ID of this shared setting.

=cut

sub Id {
    my $self = shift;
    return $self->{'Id'};
}

*id = \&Id;


=head2 Privacy

Returns the principal object to whom this shared setting belongs, in a string
"<class>-<id>", e.g. "RT::Group-16".

=cut

sub Privacy {
    my $self = shift;
    return $self->{'Privacy'};
}

=head2 GetParameter

Returns the given named parameter of the setting.

=cut

sub GetParameter {
    my $self = shift;
    my $param = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->SubValue($param);
}

=head2 IsVisibleTo Privacy

Returns true if the setting is visible to all principals of the given privacy.
This does not deal with ACLs, this only looks at membership.

=cut

sub IsVisibleTo {
    my $self    = shift;
    my $to      = shift;
    my $privacy = $self->Privacy || '';

    # if the privacies are the same, then they can be seen. this handles
    # a personal setting being visible to that user.
    return 1 if $privacy eq $to;

    # If the setting is systemwide, then any user can see it.
    return 1 if $privacy =~ /^RT::System/;

    # Only privacies that are RT::System can be seen by everyone.
    return 0 if $to =~ /^RT::System/;

    # If the setting is group-wide...
    if ($privacy =~ /^RT::Group-(\d+)$/) {
        my $setting_group = RT::Group->new($self->CurrentUser);
        $setting_group->Load($1);

        if ($to =~ /-(\d+)$/) {
            my $to_id = $1;

            # then any principal that is a member of the setting's group can see
            # the setting
            return $setting_group->HasMemberRecursively($to_id);
        }
    }

    return 0;
}

sub CurrentUserCanSee    { 1 }
sub CurrentUserCanCreate { 1 }
sub CurrentUserCanModify { 1 }
sub CurrentUserCanDelete { 1 }

### Internal methods

# _GetObject: helper routine to load the correct object whose parameters
#  have been passed.

sub _GetObject {
    my $self = shift;
    my $privacy = shift;

    # short circuit: if they pass the object we want anyway, just return it
    if (blessed($privacy) && $privacy->isa('RT::Record')) {
        return $privacy;
    }

    my ($obj_type, $obj_id) = split(/\-/, ($privacy || ''));

    unless ($obj_type && $obj_id) {
        $privacy = '(undef)' if !defined($privacy);
        $RT::Logger->debug("Invalid privacy string '$privacy'");
        return undef;
    }

    my $object = $self->_load_privacy_object($obj_type, $obj_id);

    unless (ref($object) eq $obj_type) {
        $RT::Logger->error("Could not load object of type $obj_type with ID $obj_id, got object of type " . (ref($object) || 'undef'));
        return undef;
    }

    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if ($obj_type eq 'RT::User' && $object->Id != $self->CurrentUser->UserObj->Id) {
        $RT::Logger->debug("Permission denied for user other than self");
        return undef;
    }

    if (   $obj_type eq 'RT::Group'
        && !$object->HasMemberRecursively($self->CurrentUser->PrincipalObj)
        && !$self->CurrentUser->HasRight( Object => $RT::System, Right => 'SuperUser' ) ) {
        $RT::Logger->debug("Permission denied, ".$self->CurrentUser->Name.
                           " is not a member of group");
        return undef;
    }

    return $object;
}

sub _load_privacy_object {
    my ($self, $obj_type, $obj_id) = @_;
    if ( $obj_type eq 'RT::User' ) {
        if ( $obj_id == $self->CurrentUser->Id ) {
            return $self->CurrentUser->UserObj;
        } else {
            $RT::Logger->warning("User #". $self->CurrentUser->Id ." tried to load container user #". $obj_id);
            return undef;
        }
    }
    elsif ($obj_type eq 'RT::Group') {
        my $group = RT::Group->new($self->CurrentUser);
        $group->Load($obj_id);
        return $group;
    }
    elsif ($obj_type eq 'RT::System') {
        return RT::System->new($self->CurrentUser);
    }

    $RT::Logger->error(
        "Tried to load a ". $self->ObjectName 
        ." belonging to an $obj_type, which is neither a user nor a group"
    );

    return undef;
}

sub _build_privacy {
    my ($self, $obj_type, $obj_id) = @_;

    # allow passing in just an object to find its privacy string
    if (ref($obj_type)) {
        my $Object = $obj_type;
        return $Object->isa('RT::User')   ? 'RT::User-'   . $Object->Id
             : $Object->isa('RT::Group')  ? 'RT::Group-'  . $Object->Id
             : $Object->isa('RT::System') ? 'RT::System-' . $Object->Id
             : undef;
    }

    return undef unless ($obj_type);  # undef workaround
    return $obj_type eq 'RT::User'   ? "$obj_type-$obj_id"
         : $obj_type eq 'RT::Group'  ? "$obj_type-$obj_id"
         : $obj_type eq 'RT::System' ? "$obj_type-$obj_id"
         : undef;
}

=head2 ObjectsForLoading

Returns a list of objects that can be used to load this shared setting. It
is ACL checked.

=cut

sub ObjectsForLoading {
    my $self = shift;
    return grep { $self->CurrentUserCanSee($_) } $self->_PrivacyObjects;
}

=head2 ObjectsForCreating

Returns a list of objects that can be used to create this shared setting. It
is ACL checked.

=cut

sub ObjectsForCreating {
    my $self = shift;
    return grep { $self->CurrentUserCanCreate($_) } $self->_PrivacyObjects;
}

=head2 ObjectsForModifying

Returns a list of objects that can be used to modify this shared setting. It
is ACL checked.

=cut

sub ObjectsForModifying {
    my $self = shift;
    return grep { $self->CurrentUserCanModify($_) } $self->_PrivacyObjects;
}

RT::Base->_ImportOverlays();

1;
