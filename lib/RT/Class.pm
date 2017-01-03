# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

package RT::Class;

use strict;
use warnings;
use base 'RT::Record';


use RT::System;
use RT::CustomFields;
use RT::ACL;
use RT::Articles;
use RT::ObjectClass;
use RT::ObjectClasses;

sub Table {'Classes'}

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
    ShowArticleHistory  => 'See changes to articles in this class',    #loc_pair
    ModifyArticle       => 'Modify or delete articles in this class',  #loc_pair
    ModifyArticleTopics => 'Modify topics for articles in this class', #loc_pair
    AdminClass          => 'Modify metadata and custom fields for this class',              #loc_pair
    AdminTopics         => 'Modify topic hierarchy associated with this class',             #loc_pair
    ShowACL             => 'Display Access Control List',              #loc_pair
    ModifyACL           => 'Create, modify and delete Access Control List entries',         #loc_pair
    DeleteArticle       => 'Delete articles in this class',            #loc_pair
};

our $RIGHT_CATEGORIES = {
    SeeClass            => 'Staff',
    CreateArticle       => 'Staff',
    ShowArticle         => 'General',
    ShowArticleHistory  => 'Staff',
    ModifyArticle       => 'Staff',
    ModifyArticleTopics => 'Staff',
    AdminClass          => 'Admin',
    AdminTopics         => 'Admin',
    ShowACL             => 'Admin',
    ModifyACL           => 'Admin',
    DeleteArticle       => 'Staff',
};

# TODO: This should be refactored out into an RT::ACLedObject or something
# stuff the rights into a hash of rights that can exist.

# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::Class'} = 1;

# TODO this is ripe for a refacor, since this is stolen from Queue
__PACKAGE__->AddRights(%$RIGHTS);
__PACKAGE__->AddRightCategories(%$RIGHT_CATEGORIES);

=head2 AddRights C<RIGHT>, C<DESCRIPTION> [, ...]

Adds the given rights to the list of possible rights.  This method
should be called during server startup, not at runtime.

=cut

sub AddRights {
    my $self = shift;
    my %new = @_;
    $RIGHTS = { %$RIGHTS, %new };
    %RT::ACE::LOWERCASERIGHTNAMES = ( %RT::ACE::LOWERCASERIGHTNAMES,
                                      map { lc($_) => $_ } keys %new);
}

=head2 AddRightCategories C<RIGHT>, C<CATEGORY> [, ...]

Adds the given right and category pairs to the list of right categories.  This
method should be called during server startup, not at runtime.

=cut

sub AddRightCategories {
    my $self = shift if ref $_[0] or $_[0] eq __PACKAGE__;
    my %new = @_;
    $RIGHT_CATEGORIES = { %$RIGHT_CATEGORIES, %new };
}

=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what t
he rights do

=cut

sub AvailableRights {
    my $self = shift;
    return ($RIGHTS);
}

sub RightCategories {
    return $RIGHT_CATEGORIES;
}


# }}}


# {{{ Create

=head2 Create PARAMHASH

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
            Object => $RT::System
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
    my $obj = RT::Class->new($RT::SystemUser);
    $obj->Load($newval);
    return undef if $obj->id && ( !$self->id || $self->id != $obj->id );
    return $self->SUPER::ValidateName($newval);

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
            Object       => ( $self->Id ? $self : $RT::System ),
            EquivObjects => [ $RT::System, $RT::System ]
        )
    );

}

sub ArticleCustomFields {
    my $self = shift;


    my $cfs = RT::CustomFields->new( $self->CurrentUser );
    if ( $self->CurrentUserHasRight('SeeClass') ) {
        $cfs->SetContextObject( $self );
        $cfs->LimitToGlobalOrObjectId( $self->Id );
        $cfs->LimitToLookupType( RT::Article->CustomFieldLookupType );
        $cfs->ApplySortOrder;
    }
    return ($cfs);
}


=head1 AppliedTo

Returns collection of Queues this Class is applied to.
Doesn't takes into account if object is applied globally.

=cut

sub AppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS NOT',
        VALUE     => 'NULL',
    );

    return $res;
}

=head1 NotAppliedTo

Returns collection of Queues this Class is not applied to.

Doesn't takes into account if object is applied globally.

=cut

sub NotAppliedTo {
    my $self = shift;

    my ($res, $ocfs_alias) = $self->_AppliedTo;
    return $res unless $res;

    $res->Limit(
        ALIAS     => $ocfs_alias,
        FIELD     => 'id',
        OPERATOR  => 'IS',
        VALUE     => 'NULL',
    );

    return $res;
}

sub _AppliedTo {
    my $self = shift;

    my $res = RT::Queues->new( $self->CurrentUser );

    $res->OrderBy( FIELD => 'Name' );
    my $ocfs_alias = $res->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'ObjectClasses',
        FIELD2 => 'ObjectId',
    );
    $res->Limit(
        LEFTJOIN => $ocfs_alias,
        ALIAS    => $ocfs_alias,
        FIELD    => 'Class',
        VALUE    => $self->id,
    );
    return ($res, $ocfs_alias);
}

=head2 IsApplied

Takes object id and returns corresponding L<RT::ObjectClass>
record if this Class is applied to the object. Use 0 to check
if Class is applied globally.

=cut

sub IsApplied {
    my $self = shift;
    my $id = shift;
    return unless defined $id;
    my $oc = RT::ObjectClass->new( $self->CurrentUser );
    $oc->LoadByCols( Class=> $self->id, ObjectId => $id,
                     ObjectType => ( $id ? 'RT::Queue' : 'RT::System' ));
    return undef unless $oc->id;
    return $oc;
}

=head2 AddToObject OBJECT

Apply this Class to a single object, to start with we support Queues

Takes an object

=cut


sub AddToObject {
    my $self  = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $queue = RT::Queue->new( $self->CurrentUser );
    if ( $id ) {
        my ($ok, $msg) = $queue->Load( $id );
        unless ($ok) {
            return ( 0, $self->loc('Invalid Queue, unable to apply Class: [_1]',$msg ) );
        }

    }

    if ( $self->IsApplied( $id ) ) {
        return ( 0, $self->loc("Class is already applied to [_1]",$queue->Name) );
    }

    if ( $id ) {
        # applying locally
        return (0, $self->loc("Class is already applied Globally") )
            if $self->IsApplied( 0 );
    }
    else {
        my $applied = RT::ObjectClasses->new( $self->CurrentUser );
        $applied->LimitToClass( $self->id );
        while ( my $record = $applied->Next ) {
            $record->Delete;
        }
    }

    my $oc = RT::ObjectClass->new( $self->CurrentUser );
    my ( $oid, $msg ) = $oc->Create(
        ObjectId => $id, Class => $self->id,
        ObjectType => ( $id ? 'RT::Queue' : 'RT::System' ),
    );
    return ( $oid, $msg );
}


=head2 RemoveFromObject OBJECT

Remove this class from a single queue object

=cut

sub RemoveFromObject {
    my $self = shift;
    my $object = shift;
    my $id = $object->Id || 0;

    unless ( $object->CurrentUserHasRight('AdminClass') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $ocf = $self->IsApplied( $id );
    unless ( $ocf ) {
        return ( 0, $self->loc("This class does not apply to that object") );
    }

    # XXX: Delete doesn't return anything
    my ( $oid, $msg ) = $ocf->Delete;
    return ( $oid, $msg );
}



=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(255).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(255).)


=cut


=head2 Description

Returns the current value of Description. 
(In the database, Description is stored as varchar(255).)



=head2 SetDescription VALUE


Set Description to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Description will be stored as a varchar(255).)


=cut


=head2 SortOrder

Returns the current value of SortOrder. 
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


=cut


=head2 Disabled

Returns the current value of Disabled. 
(In the database, Disabled is stored as int(2).)



=head2 SetDisabled VALUE


Set Disabled to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a int(2).)


=cut


=head2 HotList

Returns the current value of HotList. 
(In the database, HotList is stored as int(2).)



=head2 SetHotList VALUE


Set HotList to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, HotList will be stored as a int(2).)


=cut


=head2 Creator

Returns the current value of Creator. 
(In the database, Creator is stored as int(11).)


=cut


=head2 Created

Returns the current value of Created. 
(In the database, Created is stored as datetime.)


=cut


=head2 LastUpdatedBy

Returns the current value of LastUpdatedBy. 
(In the database, LastUpdatedBy is stored as int(11).)


=cut


=head2 LastUpdated

Returns the current value of LastUpdated. 
(In the database, LastUpdated is stored as datetime.)


=cut



sub _CoreAccessible {
    {
     
        id =>
		{read => 1, type => 'int(11)', default => ''},
        Name => 
		{read => 1, write => 1, type => 'varchar(255)', default => ''},
        Description => 
		{read => 1, write => 1, type => 'varchar(255)', default => ''},
        SortOrder => 
		{read => 1, write => 1, type => 'int(11)', default => '0'},
        Disabled => 
		{read => 1, write => 1, type => 'int(2)', default => '0'},
        HotList => 
		{read => 1, write => 1, type => 'int(2)', default => '0'},
        Creator => 
		{read => 1, auto => 1, type => 'int(11)', default => '0'},
        Created => 
		{read => 1, auto => 1, type => 'datetime', default => ''},
        LastUpdatedBy => 
		{read => 1, auto => 1, type => 'int(11)', default => '0'},
        LastUpdated => 
		{read => 1, auto => 1, type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;

