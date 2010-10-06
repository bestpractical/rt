# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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
package RT::FM::Class;

use strict;
use warnings;
no warnings qw/redefine/;

use RT::FM::System;
use RT::CustomFields;
use RT::ACL;
use RT::FM::ArticleCollection;


=head2 Load IDENTIFIER

Loads a class, either by name or by id

=cut

sub Load {
    my $self = shift;
    my $id   = shift ;

    return unless $id;
    if ( $id =~ /^\d+$/ ) {
        $self->SUPER::Load($id);
    }
    else {
        $self->LoadByCols( Name => $id );
    }
}

# {{{ This object provides ACLs

use vars qw/$RIGHTS/;
$RIGHTS = {

    SeeClass            => 'See that this class exists',               #loc_pair
    CreateArticle       => 'Create articles in this class',            #loc_pair
    ShowArticle         => 'See articles in this class',               #loc_pair
    ShowArticleHistory  => 'See articles in this class',               #loc_pair
    ModifyArticle       => 'Modify or delete articles in this class',  #loc_pair
    ModifyArticleTopics => 'Modify topics for articles in this class', #loc_pair
    AdminClass  =>
      'Modify metadata and custom fields for this class',              #loc_pair
    AdminTopics =>
      'Modify topic hierarchy associated with this class',             #loc_pair
    ShowACL             => 'Display Access Control List',              #loc_pair
    ModifyACL           => 'Modify Access Control List',               #loc_pair
    DeleteArticle       => 'Delete articles in this class',            #loc_pair
};

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::FM::Class'} = 1;

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what t
he rights do

=cut

sub AvailableRights {
    my $self = shift;
    return ($RIGHTS);
}

# }}}


# {{{ Create

=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(255) 'Name'.
  varchar(255) 'Description'.
  int(11) 'SortOrder'.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Name        => '',
        Description => '',
        SortOrder   => '0',
        HotList     => 0,
        @_
    );

    unless (
        $self->CurrentUser->HasRight(
            Right  => 'AdminClass',
            Object => $RT::FM::System
        )
      )
    {
        return ( 0, $self->loc('Permission Denied') );
    }

    $self->SUPER::Create(
        Name        => $args{'Name'},
        Description => $args{'Description'},
        SortOrder   => $args{'SortOrder'},
        HotList     => $args{'HotList'},
    );

}

sub ValidateName {
    my $self   = shift;
    my $newval = shift;

    return undef unless ($newval);
    my $obj = RT::FM::Class->new($RT::SystemUser);
    $obj->Load($newval);
    return undef if ( $obj->Id );
    return 1;

}

# }}}

# }}}

# {{{ ACCESS CONTROL

# {{{ sub _Set
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }
    return ( $self->SUPER::_Set(@_) );
}

# }}}

# {{{ sub _Value

sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('SeeClass') ) {
        return (undef);
    }

    return ( $self->__Value(@_) );
}

# }}}

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    return (
        $self->CurrentUser->HasRight(
            Right        => $right,
            Object       => ( $self->Id ? $self : $RT::FM::System ),
            EquivObjects => [ $RT::System, $RT::FM::System ]
        )
    );

}

sub ArticleCustomFields {
    my $self = shift;


    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeClass') ) {
        $cfs->LimitToGlobalOrObjectId( $self->Id );
        $cfs->LimitToLookupType( RT::FM::Article->CustomFieldLookupType );
    }
    return ($cfs);
}

1;

