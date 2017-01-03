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

package RT::ObjectCustomField;

use strict;
use warnings;


use RT::CustomField;
use base 'RT::Record';

sub Table {'ObjectCustomFields'}






sub Create {
    my $self = shift;
    my %args = (
        CustomField => 0,
        ObjectId    => 0,
        SortOrder   => undef,
        @_
    );

    my $cf = $self->CustomFieldObj( $args{'CustomField'} );
    unless ( $cf->id ) {
        $RT::Logger->error("Couldn't load '$args{'CustomField'}' custom field");
        return 0;
    }

    #XXX: Where is ACL check for 'AssignCustomFields'?

    my $ObjectCFs = RT::ObjectCustomFields->new($self->CurrentUser);
    $ObjectCFs->LimitToObjectId( $args{'ObjectId'} );
    $ObjectCFs->LimitToCustomField( $cf->id );
    $ObjectCFs->LimitToLookupType( $cf->LookupType );
    if ( my $first = $ObjectCFs->First ) {
        $self->Load( $first->id );
        return $first->id;
    }

    unless ( defined $args{'SortOrder'} ) {
        my $ObjectCFs = RT::ObjectCustomFields->new( RT->SystemUser );
        $ObjectCFs->LimitToObjectId( $args{'ObjectId'} );
        $ObjectCFs->LimitToObjectId( 0 ) if $args{'ObjectId'};
        $ObjectCFs->LimitToLookupType( $cf->LookupType );
        $ObjectCFs->OrderBy( FIELD => 'SortOrder', ORDER => 'DESC' );
        if ( my $first = $ObjectCFs->First ) {
            $args{'SortOrder'} = $first->SortOrder + 1;
        } else {
            $args{'SortOrder'} = 0;
        }
    }

    return $self->SUPER::Create(
        CustomField => $args{'CustomField'},
        ObjectId    => $args{'ObjectId'},
        SortOrder   => $args{'SortOrder'},
    );
}

sub Delete {
    my $self = shift;

    my $ObjectCFs = RT::ObjectCustomFields->new($self->CurrentUser);
    $ObjectCFs->LimitToObjectId($self->ObjectId);
    $ObjectCFs->LimitToLookupType($self->CustomFieldObj->LookupType);

    # Move everything below us up
    my $sort_order = $self->SortOrder;
    while (my $OCF = $ObjectCFs->Next) {
        my $this_order = $OCF->SortOrder;
        next if $this_order <= $sort_order; 
        $OCF->SetSortOrder($this_order - 1);
    }

    $self->SUPER::Delete;
}


=head2 CustomFieldObj

Returns the CustomField Object which has the id returned by CustomField


=cut

sub CustomFieldObj {
    my $self = shift;
    my $id = shift || $self->CustomField;

    # To find out the proper context object to load the CF with, we need
    # data from the CF -- namely, the record class.  Go find that as the
    # system user first.
    my $system_CF = RT::CustomField->new( RT->SystemUser );
    $system_CF->Load( $id );
    my $class = $system_CF->RecordClassFromLookupType;

    my $obj = $class->new( $self->CurrentUser );
    $obj->Load( $self->ObjectId );

    my $CF = RT::CustomField->new( $self->CurrentUser );
    $CF->SetContextObject( $obj );
    $CF->Load( $id );
    return $CF;
}

=head2 Sorting custom fields applications

Custom fields sorted on multiple layers. First of all custom
fields with different lookup type are sorted independently. All
global custom fields have fixed order for all objects, but you
can insert object specific custom fields between them. Object
specific custom fields can be applied to several objects and
be on different place. For example you have GCF1, GCF2, LCF1,
LCF2 and LCF3 that applies to tickets. You can place GCF2
above GCF1, but they will be in the same order in all queues.
However, LCF1 and other local can be placed at any place
for particular queue: above global, between them or below.

=head3 MoveUp

Moves custom field up. See </Sorting custom fields applications>.

=cut

sub MoveUp {
    my $self = shift;

    my $ocfs = RT::ObjectCustomFields->new( $self->CurrentUser );

    my $oid = $self->ObjectId;
    $ocfs->LimitToObjectId( $oid );
    if ( $oid ) {
        $ocfs->LimitToObjectId( 0 );
    }

    my $cf = $self->CustomFieldObj;
    $ocfs->LimitToLookupType( $cf->LookupType );

    $ocfs->Limit( FIELD => 'SortOrder', OPERATOR => '<', VALUE => $self->SortOrder );
    $ocfs->OrderByCols( { FIELD => 'SortOrder', ORDER => 'DESC' } );

    my @above = ($ocfs->Next, $ocfs->Next);
    unless ($above[0]) {
        return (0, "Can not move up. It's already at the top");
    }

    my $new_sort_order;
    if ( $above[0]->ObjectId == $self->ObjectId ) {
        $new_sort_order = $above[0]->SortOrder;
        my ($status, $msg) = $above[0]->SetSortOrder( $self->SortOrder );
        unless ( $status ) {
            return (0, "Couldn't move custom field");
        }
    }
    elsif ( $above[1] && $above[0]->SortOrder == $above[1]->SortOrder + 1 ) {
        my $move_ocfs = RT::ObjectCustomFields->new( RT->SystemUser );
        $move_ocfs->LimitToLookupType( $cf->LookupType );
        $move_ocfs->Limit(
            FIELD => 'SortOrder',
            OPERATOR => '>=',
            VALUE => $above[0]->SortOrder,
        );
        $move_ocfs->OrderByCols( { FIELD => 'SortOrder', ORDER => 'DESC' } );
        while ( my $record = $move_ocfs->Next ) {
            my ($status, $msg) = $record->SetSortOrder( $record->SortOrder + 1 );
            unless ( $status ) {
                return (0, "Couldn't move custom field");
            }
        }
        $new_sort_order = $above[0]->SortOrder;
    } else {
        $new_sort_order = $above[0]->SortOrder - 1;
    }

    my ($status, $msg) = $self->SetSortOrder( $new_sort_order );
    unless ( $status ) {
        return (0, "Couldn't move custom field");
    }

    return (1,"Moved custom field up");
}

=head3 MoveDown

Moves custom field down. See </Sorting custom fields applications>.

=cut

sub MoveDown {
    my $self = shift;

    my $ocfs = RT::ObjectCustomFields->new( $self->CurrentUser );

    my $oid = $self->ObjectId;
    $ocfs->LimitToObjectId( $oid );
    if ( $oid ) {
        $ocfs->LimitToObjectId( 0 );
    }

    my $cf = $self->CustomFieldObj;
    $ocfs->LimitToLookupType( $cf->LookupType );

    $ocfs->Limit( FIELD => 'SortOrder', OPERATOR => '>', VALUE => $self->SortOrder );
    $ocfs->OrderByCols( { FIELD => 'SortOrder', ORDER => 'ASC' } );

    my @below = ($ocfs->Next, $ocfs->Next);
    unless ($below[0]) {
        return (0, "Can not move down. It's already at the bottom");
    }

    my $new_sort_order;
    if ( $below[0]->ObjectId == $self->ObjectId ) {
        $new_sort_order = $below[0]->SortOrder;
        my ($status, $msg) = $below[0]->SetSortOrder( $self->SortOrder );
        unless ( $status ) {
            return (0, "Couldn't move custom field");
        }
    }
    elsif ( $below[1] && $below[0]->SortOrder + 1 == $below[1]->SortOrder ) {
        my $move_ocfs = RT::ObjectCustomFields->new( RT->SystemUser );
        $move_ocfs->LimitToLookupType( $cf->LookupType );
        $move_ocfs->Limit(
            FIELD => 'SortOrder',
            OPERATOR => '<=',
            VALUE => $below[0]->SortOrder,
        );
        $move_ocfs->OrderByCols( { FIELD => 'SortOrder', ORDER => 'ASC' } );
        while ( my $record = $move_ocfs->Next ) {
            my ($status, $msg) = $record->SetSortOrder( $record->SortOrder - 1 );
            unless ( $status ) {
                return (0, "Couldn't move custom field");
            }
        }
        $new_sort_order = $below[0]->SortOrder;
    } else {
        $new_sort_order = $below[0]->SortOrder + 1;
    }

    my ($status, $msg) = $self->SetSortOrder( $new_sort_order );
    unless ( $status ) {
        return (0, "Couldn't move custom field");
    }

    return (1,"Moved custom field down");
}


=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 CustomField

Returns the current value of CustomField.
(In the database, CustomField is stored as int(11).)



=head2 SetCustomField VALUE


Set CustomField to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, CustomField will be stored as a int(11).)


=cut


=head2 ObjectId

Returns the current value of ObjectId.
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut


=head2 SortOrder

Returns the current value of SortOrder.
(In the database, SortOrder is stored as int(11).)



=head2 SetSortOrder VALUE


Set SortOrder to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, SortOrder will be stored as a int(11).)


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
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        CustomField =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ObjectId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        SortOrder =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Creator =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Created =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},
        LastUpdatedBy =>
		{read => 1, auto => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        LastUpdated =>
		{read => 1, auto => 1, sql_type => 11, length => 0,  is_blob => 0,  is_numeric => 0,  type => 'datetime', default => ''},

 }
};

RT::Base->_ImportOverlays();

1;
