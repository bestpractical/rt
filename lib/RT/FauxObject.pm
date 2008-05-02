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
=head1 NAME

  RT::FauxObject - an API for faux-objects

=head1 SYNOPSIS

  use RT::FauxObject

=head1 DESCRIPTION

  A FauxObject is an object that can belong to an RT::User or an RT::Group. It
  consists of an ID, a name, and some arbitrary data.

=head1 METHODS


=cut

package RT::FauxObject;
use strict;
use warnings;
use RT::Attribute;
use base qw/RT::Base/;

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

Takes a privacy specification, an object ID, and a faux-object ID.  Loads the
given object ID if it belongs to the stated user or group.  Calls the PostLoad
method on success for any further initialization. Returns a tuple of status and
message, where status is true on success.

=cut

sub Load {
    my $self = shift;
    my ($privacy, $id) = @_;
    my $object = $self->_GetObject($privacy);

    if ($object) {
        $self->{'Attribute'} = $object->Attributes->WithId($id);
        if ($self->{'Attribute'}->Id) {
            $self->{'Id'} = $self->{'Attribute'}->Id;
            $self->{'Privacy'} = $privacy;
            $self->PostLoad();
            return (1, $self->loc("Loaded [_1] [_2]", $self->ObjectName, $self->Name));
        } else {
            $RT::Logger->error("Could not load attribute " . $id
                    . " for object " . $privacy);
            return (0, $self->loc("[_1] attribute load failure", ucfirst($self->ObjectName)));
        }
    } else {
        $RT::Logger->warning("Could not load object $privacy when loading " . $self->OBjectName);
        return (0, $self->loc("Could not load object for [_1]", $privacy));
    }
}

sub PostLoad { }

=head2 Save

Takes a privacy, a name, and any other arguments. Saves the given parameters to
the appropriate user/group object, and loads the resulting object. Arguments
are passed to the SaveAttribute method, which does the actual update. Returns a
tuple of status and message, where status is true on success. Defaults are:
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

    if ( $object->isa('RT::System') ) {
        return (0, $self->loc("No permission to save system-wide [_1]", $self->ObjectName))
            unless $self->CurrentUser->HasRight(
                Object => $RT::System,
                Right  => 'SuperUser',
            );
    }

    my ($att_id, $att_msg) = $self->SaveAttribute($object, \%args);

    if ($att_id) {
        $self->{'Attribute'} = $object->Attributes->WithId($att_id);
        $self->{'Id'}        = $att_id;
        $self->{'Privacy'}   = $privacy;
        return ( 1, $self->loc( "Saved [_1] [_2]", $self->ObjectName, $name ) );
    }
    else {
        $RT::Logger->error($self->ObjectName . " save failure: $att_msg");
        return ( 0, $self->loc("Failed to create [_1] attribute", $self->ObjectName) );
    }
}

=head2 Update

Updates the parameters of an existing faux-object. Any arguments are passed to
the UpdateAttribute method. Returns a tuple of status and message, where status
is true on success. 

=cut

sub Update {
    my $self = shift;
    my %args = @_;

    return(0, $self->loc("No [_1] loaded", $self->ObjectName)) unless $self->Id;
    return(0, $self->loc("Could not load [_1] attribute", $self->ObjectName))
        unless $self->{'Attribute'}->Id;

    my ($status, $msg) = $self->UpdateAttribute(\%args);

    return (1, $self->loc("[_1] update: Nothing changed", ucfirst($self->ObjectName)))
        if !defined $msg;

    # prevent useless warnings
    return (1, $self->loc("[_1] updated"), ucfirst($self->ObjectName));
        if $msg =~ /That is already the current value/;

    return ($status, $self->loc("[_1] update: [_2]", ucfirst($self->ObjectName), $msg));
}

=head2 Delete
    
Deletes the existing faux-object. Returns a tuple of status and message, where
status is true upon success.

=cut

sub Delete {
    my $self = shift;

    my ($status, $msg) = $self->{'Attribute'}->Delete;
    if ($status) {
        return (1, $self->loc("Deleted [_1]", $self->ObjectName));
    } else {
        return (0, $self->loc("Delete failed: [_1]", $msg));
    }
}

### Accessor methods

=head2 Name

Returns the name of this faux-object.

=cut

sub Name {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->Description();
}

=head2 Id

Returns the numerical ID of this faux-object.

=cut

sub Id {
     my $self = shift;
     return $self->{'Id'};
}

=head2 Privacy

Returns the principal object to whom this faux-object belongs, in a string
"<class>-<id>", e.g. "RT::Group-16".

=cut

sub Privacy {
    my $self = shift;
    return $self->{'Privacy'};
}

eval "require RT::FauxObject_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/FauxObject_Vendor.pm});
eval "require RT::FauxObject_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/FauxObject_Local.pm});

1;

