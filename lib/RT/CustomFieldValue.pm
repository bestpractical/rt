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

package RT::CustomFieldValue;

no warnings qw/redefine/;


use base 'RT::Record';
use RT::CustomField;

sub Table {'CustomFieldValues'}


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
        map { $_ => $args{$_} } qw(Name Description SortOrder Category)
    );
    return ($id, $msg);
}

sub ValidateName {
    return defined $_[1] && length $_[1];
};

sub Delete {
    my $self = shift;
    my ( $ret, $msg ) = $self->SUPER::Delete;
    $self->CustomFieldObj->CleanupDefaultValues;
    return ( $ret, $msg );
}

sub _Set { 
    my $self = shift; 
    my %args = @_;
    my $cf_id = $self->CustomField; 

    my $cf = RT::CustomField->new( $self->CurrentUser ); 
    $cf->Load( $cf_id ); 

    unless ( $cf->id ) { 
        return (0, $self->loc("Couldn't load Custom Field #[_1]", $cf_id)); 
    } 

    unless ($cf->CurrentUserHasRight('AdminCustomField') || $cf->CurrentUserHasRight('AdminCustomFieldValues')) { 
        return (0, $self->loc('Permission Denied')); 
    } 

    my ($ret, $msg) = $self->SUPER::_Set( @_ ); 
    if ( $args{Field} eq 'Name' ) {
        $cf->CleanupDefaultValues;
    }
    return ($ret, $msg);
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


=head2 SetCustomFieldObj

Store the CustomField object which loaded this CustomFieldValue.
Passed down from the CustomFieldValues collection in AddRecord.

This object will be transparently returned from CustomFieldObj rather
than loading from the database.

=cut

sub SetCustomFieldObj {
    my $self = shift;
    return $self->{'custom_field'} = shift;
}

=head2 CustomFieldObj

If a CustomField object was stored using SetCustomFieldObj and it is
the same CustomField stored in the CustomField column, then the stored
CustomField object (likely passed down from CustomField->Values) will be returned.

Otherwise returns the CustomField Object which has the id returned by CustomField

=cut

sub CustomFieldObj {
    my $self = shift;

    return $self->{custom_field} if $self->{custom_field}
        and $self->{custom_field}->id == $self->__Value('CustomField');

    my $CustomField =  RT::CustomField->new($self->CurrentUser);
    $CustomField->Load($self->__Value('CustomField'));
    return($CustomField);
}

=head2 Name

Returns the current value of Name. 
(In the database, Name is stored as varchar(200).)



=head2 SetName VALUE


Set Name to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Name will be stored as a varchar(200).)


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


=head2 Category

Returns the current value of Category.
(In the database, Category is stored as varchar(255).)



=head2 SetCategory VALUE


Set Category to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Category will be stored as a varchar(255).)


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
        Name => 
        {read => 1, write => 1, sql_type => 12, length => 200,  is_blob => 0,  is_numeric => 0,  type => 'varchar(200)', default => ''},
        Description => 
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
        SortOrder => 
        {read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '0'},
        Category =>
        {read => 1, write => 1, sql_type => 12, length => 255,  is_blob => 0,  is_numeric => 0,  type => 'varchar(255)', default => ''},
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
}

RT::Base->_ImportOverlays();

1;
