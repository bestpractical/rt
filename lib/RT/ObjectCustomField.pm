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

use strict;
use warnings;

package RT::ObjectCustomField;
use base 'RT::Record::AddAndSort';

use RT::CustomField;
use RT::ObjectCustomFields;

sub Table {'ObjectCustomFields'}

sub ObjectCollectionClass {
    my $self = shift;
    my %args = (@_);
    return $args{'CustomField'}->CollectionClassFromLookupType;
}

# XXX: Where is ACL check when we create a record?

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

sub Neighbors {
    my $self = shift;
    my %args = @_;

    my $res = $self->CollectionClass->new( $self->CurrentUser );
    $res->LimitToLookupType(
        ($args{'CustomField'} || $self->CustomFieldObj)->LookupType
    );
    return $res;
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

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->CustomFieldObj );

    if ($self->ObjectId) {
        my $class = $self->CustomFieldObj->RecordClassFromLookupType;
        my $obj = $class->new( $self->CurrentUser );
        $obj->Load( $self->ObjectId );
        $deps->Add( out => $obj );
    }
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    if ($store{ObjectId}) {
        my $class = $self->CustomFieldObj->RecordClassFromLookupType;
        my $obj = $class->new( RT->SystemUser );
        $obj->Load( $store{ObjectId} );
        $store{ObjectId} = \($obj->UID);
    }
    return %store;
}


RT::Base->_ImportOverlays();

1;
