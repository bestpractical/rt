# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

  use RT::Date

=head1 DESCRIPTION

  SavedSearch is an object that can belong to either an RT::User or an
  RT::Group.  It consists of an ID, a description, and a number of
  search parameters.

=head1 METHODS

=cut


package RT::SavedSearch;

use RT::Base;
use RT::Attribute;

use strict;
use vars qw/@ISA/;
@ISA = qw/RT::Base/;

sub new  {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless ($self, $class);
    $self->CurrentUser(@_);
    $self->{'Id'} = 0;
    return $self;
}

=head2 Load

Takes an object type, which must be either 'RT::User' or 'RT::Group',
an object ID, and a search ID.  Loads the given search ID if it belongs
to the stated user or group.

=begin testing

use_ok(RT::SavedSearch);

=end testing

=cut

sub Load {
    my $self = shift;
    my ($obj_type, $obj_id, $id) = @_;
    my $object = $self->_GetObject($obj_type, $obj_id);

    if ($object) {
	$self->{'Attribute'} = $object->Attributes->WithId($id);
	$self->{'Id'} = $self->{'Attribute'}->Id();
    }

}

sub Save {
    my $self = shift;
    my ($obj_type, $obj_id, $description, %params) = @_;
    my $object = $self->_GetObject($obj_type, $obj_id);

    # Save the info.
    if ($object->Id == $obj_id) {
	my ($att_id, $att_msg) = $object->AddAttribute(
			            'Name' => 'SavedSearch',
				    'Description' => $description,
				    'Content' => \%params);
	if ($att_id) {
	    $self->{'Attribute'} = $object->Attributes->WithId($att_id);
	    $self->{'Id'} = $att_id;
	} else {
	    $RT::Logger->warning("SavedSearch save failure: $att_msg");
    }
}

### Accessor methods

sub Description {
    my $self = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->Description();
}

sub GetParameter {
    my $self = shift;
    my $param = shift;
    return unless ref($self->{'Attribute'}) eq 'RT::Attribute';
    return $self->{'Attribute'}->SubValue($param);
}

sub Id {
    my $self = shift;
    return $self->{'Id'};
}

### _GetObject: helper routine to load the correct object whose parameters
###   have been passed.

sub _GetObject {
    my $self = shift;
    my ($obj_type, $obj_id) = @_;
    unless ($obj_type eq 'RT::User' || $obj_type eq 'RT::Group') {
	$RT::Logger->warning("Tried to load a search belonging to $obj_type $obj_id, which is neither a user nor a group");
	return undef;
    }

    my $object;
    eval "
         require $obj_type;
         \$object = $obj_type->new(\$self->CurrentUser);
    ";
    unless (ref($object) eq $obj_type) {
	$RT::Logger->warning("Could not load object of type $obj_type with ID $obj_id");
	return undef;
    }
    
    # Do not allow the loading of a user object other than the current
    # user, or of a group object of which the current user is not a member.

    if ($obj_type eq 'RT::User') {
	return undef 
	    unless $object->Id == $self->{'CurrentUser'}->UserObj->Id();
    }
    if ($obj_type eq 'RT::Group') {
	return undef 
	    unless $object->HasMember($self->{'CurrentUser'}->PrincipalObj);
    }

    return $object;
}

eval "require RT::SavedSearch_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Vendor.pm});
eval "require RT::SavedSearch_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SavedSearch_Local.pm});

1;
