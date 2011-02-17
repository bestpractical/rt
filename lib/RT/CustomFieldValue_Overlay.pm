# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

use warnings;
use strict;

package RT::CustomFieldValue;

no warnings qw/redefine/;


=head2 ValidateName

Override the default ValidateName method that stops custom field values
from being integers.

=cut

sub Create {
    my $self = shift;
    my %args = (
        CustomField => 0,
        Name        => '',
        Description => '',
        SortOrder   => 0,
        Category    => '',
        @_,
    );

    my $cf_id = ref $args{'CustomField'}? $args{'CustomField'}->id: $args{'CustomField'};

    my $cf = RT::CustomField->new( $self->CurrentUser );
    $cf->Load( $cf_id );
    unless ( $cf->id ) {
        return (0, $self->loc("Couldn't load Custom Field #[_1]", $cf_id));
    }
    unless ( $cf->CurrentUserHasRight('AdminCustomField') || $cf->CurrentUserHasRight('AdminCustomFieldValues') ) {
        return (0, $self->loc('Permission Denied'));
    }

    my ($id, $msg) = $self->SUPER::Create(
        CustomField => $cf_id,
        map { $_ => $args{$_} } qw(Name Description SortOrder)
    );
    return ($id, $msg) unless $id;

    if ( defined $args{'Category'} && length $args{'Category'} ) {
        # $self would be loaded at this stage
        my ($status, $msg) = $self->SetCategory( $args{'Category'} );
        unless ( $status ) {
            $RT::Logger->error("Couldn't set category: $msg");
        }
    }

    return ($id, $msg);
}

=head2 Category

Returns the Category assigned to this Value
Returns udef if there is no Category

=cut

sub Category {
    my $self = shift;
    my $attr = $self->FirstAttribute('Category') or return undef;
    return $attr->Content;
}

=head2 SetCategory Category

Takes a string Category and stores it as an attribute of this CustomFieldValue

=cut

sub SetCategory {
    my $self = shift;
    my $category = shift;
    if ( defined $category && length $category ) {
        return $self->SetAttribute(
            Name    => 'Category',
            Content => $category,
        );
    }
    else {
        my ($status, $msg) = $self->DeleteAttribute( 'Category' );
        unless ( $status ) {
            $RT::Logger->warning("Couldn't delete atribute: $msg");
        }
        # return true even if there was no category
        return (1, $self->loc('Category unset'));
    }
}

sub ValidateName {
    return defined $_[1] && length $_[1];
};

=head2 DeleteCategory

Deletes the category associated with this value
Returns -1 if there is no Category

=cut

sub DeleteCategory {
    my $self = shift;
    my $attr = $self->FirstAttribute('Category') or return (-1,'No Category Set');
    return $attr->Delete;
}

=head2 Delete

Make sure we delete our Category when we're deleted

=cut

sub Delete {
    my $self = shift;

    my ($result, $msg) = $self->DeleteCategory;

    unless ($result) {
        return ($result, $msg);
    }

    return $self->SUPER::Delete(@_);
}

sub _Set { 
    my $self = shift; 

    my $cf_id = $self->CustomField; 

    my $cf = RT::CustomField->new( $self->CurrentUser ); 
    $cf->Load( $cf_id ); 

    unless ( $cf->id ) { 
        return (0, $self->loc("Couldn't load Custom Field #[_1]", $cf_id)); 
    } 

    unless ($cf->CurrentUserHasRight('AdminCustomField') || $cf->CurrentUserHasRight('AdminCustomFieldValues')) { 
        return (0, $self->loc('Permission Denied')); 
    } 

    return $self->SUPER::_Set( @_ ); 
} 

1;
