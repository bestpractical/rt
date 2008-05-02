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

  RT::Dashboard - an API for saving and retrieving dashboards

=head1 SYNOPSIS

  use RT::Dashboard

=head1 DESCRIPTION

  Dashboard is an object that can belong to either an RT::User or an
  RT::Group.  It consists of an ID, a name, and a number of
  saved searches.

=head1 METHODS


=cut

package RT::Dashboard;

use RT::Base;
use RT::Attribute;
use RT::SavedSearch;

use strict;
use warnings;
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

my %new_rights = (
    ModifyDashboard    => 'Create and modify dashboards',
    SubscribeDashboard => 'Subscribe to email dashboards',
);

use RT::System;
$RT::System::RIGHTS = { %$RT::System::RIGHTS, %new_rights };
%RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                  map { lc($_) => $_ } keys %new_rights);

=head2 Load

Takes a privacy specification, an object ID, and a dashboard ID.  Loads
the given dashboard ID if it belongs to the stated user or group.
Returns a tuple of status and message, where status is true on
success.

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
	    return (1, $self->loc("Loaded dashboard [_1]", $self->Name));
	} else {
	    $RT::Logger->error("Could not load attribute " . $id
			       . " for object " . $privacy);
	    return (0, $self->loc("Dashboard attribute load failure"));
	}
    } else {
	$RT::Logger->warning("Could not load object $privacy when loading dashboard");
	return (0, $self->loc("Could not load object for [_1]", $privacy));
    }

}

=head2 Save

Takes a privacy, a name, and an arrayref containing an arrayref of saved
searches and their names. Saves the given parameters to the appropriate user/
group object, and loads the resulting dashboard. Returns a tuple of status and
message, where status is true on success. Defaults are:
  Privacy:  undef
  Name:     "new dashboard"
  Searches: (empty array)

=cut

sub Save {
    my $self = shift;
    my %args = ('Privacy' => 'RT::User-' . $self->CurrentUser->Id,
		'Name' => 'new dashboard',
		'Searches' => [],
		@_);
    my $privacy = $args{'Privacy'};
    my $name = $args{'Name'};
    my @params = @{$args{'Searches'} || []};

    my $object = $self->_GetObject($privacy);

    return (0, $self->loc("Failed to load object for [_1]", $privacy))
        unless $object;

    if ( $object->isa('RT::System') ) {
        return (0, $self->loc("No permission to save system-wide dashboards"))
            unless $self->CurrentUser->HasRight(
            Object => $RT::System,
            Right  => 'SuperUser'
        );
    }

    my ( $att_id, $att_msg ) = $object->AddAttribute(
        'Name'        => 'Dashboard',
        'Description' => $name,
        'Content'     => {Searches => \@params},
    );
    if ($att_id) {
        $self->{'Attribute'} = $object->Attributes->WithId($att_id);
        $self->{'Id'}        = $att_id;
        $self->{'Privacy'}   = $privacy;
        return ( 1, $self->loc( "Saved dashboard [_1]", $name ) );
    }
    else {
        $RT::Logger->error("Dashboard save failure: $att_msg");
        return ( 0, $self->loc("Failed to create dashboard attribute") );
    }
}

=head2 Update

Updates the parameters of an existing dashboard. Takes the arguments "Name" and
"Searches"; Searches should be an arrayref of arrayrefs of saved searches. If
Searches or Name is not specified, then they will not be changed.

=cut

sub Update {
    my $self = shift;
    my %args = ('Name' => '',
		@_);
 
    return(0, $self->loc("No dashboard loaded")) unless $self->Id;
    return(0, $self->loc("Could not load dashboard attribute"))
        unless $self->{'Attribute'}->Id;

    my ($status, $msg) = (1, undef);
    if (defined $args{'Searches'}) {
        ($status, $msg) = $self->{'Attribute'}->SetSubValues(
            Searches => $args{'Searches'},
        );
    }

    if ($status && $args{'Name'}) {
        ($status, $msg) = $self->{'Attribute'}->SetDescription($args{'Name'});
    }

    return (1, $self->loc("Dashboard update: Nothing changed"))
        if !defined $msg;

    # prevent useless warnings
    if ($msg =~ /That is already the current value/) {
        return (1, $self->loc("Dashboard updated"));
    }

    return ($status, $self->loc("Dashboard update: [_1]", $msg));
}

=head2 Delete
    
Deletes the existing dashboard.  Returns a tuple of status and message,
where status is true upon success.

=cut

sub Delete {
    my $self = shift;

    my ($status, $msg) = $self->{'Attribute'}->Delete;
    if ($status) {
	return (1, $self->loc("Deleted dashboard"));
    } else {
	return (0, $self->loc("Delete failed: [_1]", $msg));
    }
}
	

### Accessor methods

=head2 Name

Returns the name of the dashboard.

=cut

sub Name {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->Description();
}

=head2 Id

Returns the numerical id of this dashboard.

=cut

sub Id {
     my $self = shift;
     return $self->{'Id'};
}

=head2 Privacy

Returns the principal object to whom this dashboard belongs, in a string
"<class>-<id>", e.g. "RT::Group-16".

=cut

sub Privacy {
    my $self = shift;
    return $self->{'Privacy'};
}

=head2 Searches

Returns a list of loaded saved searches

=cut

sub Searches {
    my $self = shift;
    return map {
               my $search = RT::SavedSearch->new($self->CurrentUser);
               $search->Load($_->[0], $_->[1]);
               $search
           } $self->SearchIDs;
}

=head2 SearchIDs

Returns a list of array references, each being a saved-search privacy, ID, and
description

=cut

sub SearchIDs {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return @{ $self->{'Attribute'}->SubValue('Searches') || [] };
}

=head2 SearchPrivacies

Returns a list of array references, each one being suitable to pass to
/Elements/ShowSearch.

=cut

sub SearchPrivacies {
    my $self = shift;
    return map { [$self->SearchPrivacy(@$_)] } $self->SearchIDs;
}

=head2 SearchPrivacy TYPE, ID, DESC

Returns an array for one saved search, suitable for passing to
/Elements/ShowSearch.

=cut

sub SearchPrivacy {
    my $self = shift;
    my ($type, $id, $desc) = @_;
    if ($type eq 'RT::System') {
        return Name => $desc;
    }

    return SavedSearch => join('-', $type, 'SavedSearch', $id);
}

### Internal methods

sub _load_privacy_object {
    my ($self, $obj_type, $obj_id) = @_;
    if ( $obj_type eq 'RT::User' && $obj_id == $self->CurrentUser->Id)  {
        return $self->CurrentUser->UserObj;
    }
    elsif ($obj_type eq 'RT::Group') {
        my $group = RT::Group->new($self->CurrentUser);
        $group->Load($obj_id);
        return $group;
    }
    elsif ($obj_type eq 'RT::System') {
        return RT::System->new($self->CurrentUser);
    }

    $RT::Logger->error("Tried to load a dashboard belonging to an $obj_type, which is neither a user nor a group");
    return undef;
}

# _GetObject: helper routine to load the correct object whose parameters
#  have been passed.

sub _GetObject {
    my $self = shift;
    my $privacy = shift;

    my ($obj_type, $obj_id) = split(/\-/, $privacy);

    my $object = $self->_load_privacy_object($obj_type, $obj_id);

    unless (ref($object) eq $obj_type) {
	$RT::Logger->error("Could not load object of type $obj_type with ID $obj_id, got object of type " . (ref($object) || 'undef'));
	return undef;
    }

    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if ($obj_type eq 'RT::User' 
	&& $object->Id != $self->CurrentUser->UserObj->Id()) {
	$RT::Logger->debug("Permission denied for user other than self");
	return undef;
    }
    if ($obj_type eq 'RT::Group' &&
	!$object->HasMemberRecursively($self->CurrentUser->PrincipalObj)) {
	$RT::Logger->debug("Permission denied, ".$self->CurrentUser->Name.
			   " is not a member of group");
	return undef;
    }

    return $object;
}

# _PrivacyObjects: returns a list of objects that can be used to load
# dashboards from. Unlike SavedSearch, this will return the System object if
# applicable. You may pass in a paramhash of ShowSystem to force
# showing/hiding of the System object

sub _PrivacyObjects {
    my $self = shift;
    my %args = @_;

    my $CurrentUser = $self->CurrentUser;
    my @objects = $CurrentUser->UserObj;

    my $groups = RT::Groups->new($CurrentUser);
    $groups->LimitToUserDefinedGroups;
    $groups->WithMember( PrincipalId => $CurrentUser->Id,
                         Recursively => 1 );

    push @objects, @{ $groups->ItemsArrayRef };

    # if ShowSystem, always show it
    # if not ShowSystem, then show only if the user didn't specify AND the
    #    current user is superuser
    push @objects, RT::System->new($CurrentUser)
        if $args{ShowSystem}
        || (!defined($args{ShowSystem})
            && $CurrentUser->HasRight(Object => $RT::System,
                                      Right => 'SuperUser'));

    return @objects;
}

eval "require RT::Dashboard_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Dashboard_Vendor.pm});
eval "require RT::Dashboard_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Dashboard_Local.pm});

1;
