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

=head1 NAME

RT::ObjectTopic

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

package RT::ObjectTopic;
use strict;
use warnings;
no warnings 'redefine';

use base qw( RT::Record );

use RT::Topic;

sub _Init {
  my $self = shift; 

  $self->Table('ObjectTopics');
  $self->SUPER::_Init(@_);
}





=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  int(11) 'Topic'.
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

=cut




sub Create {
    my $self = shift;
    my %args = (
                Topic => '0',
                ObjectType => '',
                ObjectId => '0',
                @_);
    $self->SUPER::Create(
                         Topic => $args{'Topic'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
                     );
}



=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Topic

Returns the current value of Topic. 
(In the database, Topic is stored as int(11).)



=head2 SetTopic VALUE


Set Topic to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Topic will be stored as a int(11).)


=cut


=head2 TopicObj

Returns the Topic Object which has the id returned by Topic


=cut

sub TopicObj {
    my $self = shift;
    my $Topic =  RT::Topic->new($self->CurrentUser);
    $Topic->Load($self->Topic());
    return($Topic);
}

=head2 ObjectType

Returns the current value of ObjectType. 
(In the database, ObjectType is stored as varchar(64).)



=head2 SetObjectType VALUE


Set ObjectType to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectType will be stored as a varchar(64).)


=cut


=head2 ObjectId

Returns the current value of ObjectId. 
(In the database, ObjectId is stored as int(11).)



=head2 SetObjectId VALUE


Set ObjectId to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ObjectId will be stored as a int(11).)


=cut



sub _CoreAccessible {
    {
        id =>
                {read => 1, type => 'int(11)', default => ''},
        Topic => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},
        ObjectType => 
                {read => 1, write => 1, type => 'varchar(64)', default => ''},
        ObjectId => 
                {read => 1, write => 1, type => 'int(11)', default => '0'},

 }
};

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->TopicObj );

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
