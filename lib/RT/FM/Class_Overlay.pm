# BEGIN LICENSE BLOCK
#
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License
#  as published by the Free Software Foundation.
#
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
# END LICENSE BLOCK

package RT::FM::Class;

no warnings qw/redefine/;
use strict;

use RT::FM::System;
use RT::CustomFields;
use RT::ACL;
use RT::FM::ArticleCollection;


=head2 Load IDENTIFIER

Loads a class, either by name or by id

=cut

sub Load {
    my $self = shift;
    my $id   = shift;

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
    AdminClass  => 'Modify metadata and custom fields for this class', #loc_pair
    AdminTopics =>
      'Modify topic hierarchy associated with this class',             #loc_pair
    ShowACL   => 'Display Access Control List',    # loc_pair
    ModifyACL => 'Modify Access Control List',     # loc_pair
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
            Object       => $self,
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

