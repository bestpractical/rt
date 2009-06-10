# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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

  RT::SavedSearch - an API for saving and retrieving search form values.

=head1 SYNOPSIS

  use RT::SavedSearch

=head1 DESCRIPTION

  SavedSearch is an object that can belong to either an RT::User or an
  RT::Group.  It consists of an ID, a description, and a number of
  search parameters.

=head1 METHODS

=begin testing

use_ok(RT::SavedSearch);

# Real tests are in lib/t/20savedsearch.t

=end testing

=cut

package RT::SavedSearch;

use RT::Base;
use RT::Attribute;

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

=head2 Load

Takes a privacy specification, an object ID, and a search ID.  Loads
the given search ID if it belongs to the stated user or group.
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
	    $self->{'Type'} = $self->{'Attribute'}->SubValue('SearchType');
	    return (1, $self->loc("Loaded search [_1]", $self->Name));
	} else {
	    $RT::Logger->error("Could not load attribute " . $id
			       . " for object " . $privacy);
	    return (0, $self->loc("Search attribute load failure"));
	}
    } else {
	$RT::Logger->warning("Could not load object $privacy when loading search");
	return (0, $self->loc("Could not load object for [_1]", $privacy));
    }

}

=head2 Save

Takes a privacy, an optional type, a name, and a hashref containing the
search parameters.  Saves the given parameters to the appropriate user/
group object, and loads the resulting search.  Returns a tuple of status
and message, where status is true on success.  Defaults are:
  Privacy:      undef
  Type:         Ticket
  Name:         "new search"
  SearchParams: (empty hash)

=cut

sub Save {
    my $self = shift;
    my %args = ('Privacy' => 'RT::User-' . $self->CurrentUser->Id,
		'Type' => 'Ticket',
		'Name' => 'new search',
		'SearchParams' => {},
		@_);
    my $privacy = $args{'Privacy'};
    my $type = $args{'Type'};
    my $name = $args{'Name'};
    my %params = %{$args{'SearchParams'}};

    $params{'SearchType'} = $type;
    my $object = $self->_GetObject($privacy);

    return (0, $self->loc("Failed to load object for [_1]", $privacy))
        unless $object;

    if ( $object->isa('RT::System') ) {
        return ( 0, $self->loc("No permission to save system-wide searches") )
            unless $self->CurrentUser->HasRight(
            Object => $RT::System,
            Right  => 'SuperUser'
        );
    }

    my ( $att_id, $att_msg ) = $object->AddAttribute(
        'Name'        => 'SavedSearch',
        'Description' => $name,
        'Content'     => \%params
    );
    if ($att_id) {
        $self->{'Attribute'} = $object->Attributes->WithId($att_id);
        $self->{'Id'}        = $att_id;
        $self->{'Privacy'}   = $privacy;
        $self->{'Type'}      = $type;
        return ( 1, $self->loc( "Saved search [_1]", $name ) );
    }
    else {
        $RT::Logger->error("SavedSearch save failure: $att_msg");
        return ( 0, $self->loc("Failed to create search attribute") );
    }
}

=head2 Update

Updates the parameters of an existing search.  Takes the arguments
"Name" and "SearchParams"; SearchParams should be a hashref containing
the new parameters of the search.  If Name is not specified, the name
will not be changed.

=cut

sub Update {
    my $self = shift;
    my %args = ('Name' => '',
		'SearchParams' => {},
		@_);
    
    return(0, $self->loc("No search loaded")) unless $self->Id;
    return(0, $self->loc("Could not load search attribute"))
	unless $self->{'Attribute'}->Id;
    my ($status, $msg) = $self->{'Attribute'}->SetSubValues(%{$args{'SearchParams'}});
    if ($status && $args{'Name'}) {
	($status, $msg) = $self->{'Attribute'}->SetDescription($args{'Name'});
    }
    return ($status, $self->loc("Search update: [_1]", $msg));
}

=head2 Delete
    
Deletes the existing search.  Returns a tuple of status and message,
where status is true upon success.

=cut

sub Delete {
    my $self = shift;

    my ($status, $msg) = $self->{'Attribute'}->Delete;
    if ($status) {
	return (1, $self->loc("Deleted search"));
    } else {
	return (0, $self->loc("Delete failed: [_1]", $msg));
    }
}
	

### Accessor methods

=head2 Name

Returns the name of the search.

=cut

sub Name {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->Description();
}

=head2 GetParameter

Returns the given named parameter of the search, e.g. 'Query', 'Format'.

=cut

sub GetParameter {
    my $self = shift;
    my $param = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->SubValue($param);
}

=head2 Id

Returns the numerical id of this search.

=cut

sub Id {
     my $self = shift;
     return $self->{'Id'};
}

=head2 Privacy

Returns the principal object to whom this search belongs, in a string
"<class>-<id>", e.g. "RT::Group-16".

=cut

sub Privacy {
    my $self = shift;
    return $self->{'Privacy'};
}

=head2 Type

Returns the type of this search, e.g. 'Ticket'.  Useful for denoting the
saved searches that are relevant to a particular search page.

=cut

sub Type {
    my $self = shift;
    return $self->{'Type'};
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

    $RT::Logger->error("Tried to load a search belonging to an $obj_type, which is neither a user nor a group");
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
	$RT::Logger->error("Could not load object of type $obj_type with ID $obj_id");
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

eval "require RT::SavedSearch_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Vendor.pm});
eval "require RT::SavedSearch_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Local.pm});

1;
