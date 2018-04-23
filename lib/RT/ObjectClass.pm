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

package RT::ObjectClass;
use base 'RT::Record';

sub Table {'ObjectClasses'}



sub Create {
    my $self = shift;
    my %args = ( 
        Class => '0',
        ObjectType => '',
        ObjectId => '0',

        @_);

    unless ( $self->CurrentUser->HasRight( Right  => 'AdminClass', 
            Object => $RT::System ) ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    $self->SUPER::Create(
                         Class => $args{'Class'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
    );

}


=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Class

Returns the current value of Class. 
(In the database, Class is stored as int(11).)



=head2 SetClass VALUE


Set Class to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Class will be stored as a int(11).)


=cut


=head2 ClassObj

Returns the Class Object which has the id returned by Class


=cut

sub ClassObj {
    my $self = shift;
    my $Class =  RT::Class->new($self->CurrentUser);
    $Class->Load($self->Class());
    return($Class);
}

=head2 ObjectType

Returns the current value of ObjectType. 
(In the database, ObjectType is stored as varchar(255).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(255).)


=cut


=head2 ObjectId

Returns the current value of ObjectId. 
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


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
        Class => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        ObjectType => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
        ObjectId => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
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

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->ClassObj );

    my $obj = $self->ObjectType->new( $self->CurrentUser );
    $obj->Load( $self->ObjectId );
    $deps->Add( out => $obj );
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    if ($store{ObjectId}) {
        my $obj = $self->ObjectType->new( RT->SystemUser );
        $obj->Load( $store{ObjectId} );
        $store{ObjectId} = \($obj->UID);
    }
    return %store;
}

RT::Base->_ImportOverlays();

1;
