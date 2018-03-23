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

use warnings;
use strict;

package RT::Topic;
use base 'RT::Record';

sub Table {'Topics'}

# {{{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  int(11) 'Parent'.
  varchar(255) 'Name'.
  varchar(255) 'Description'.
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

=cut

sub Create {
    my $self = shift;
    my %args = (
                Parent => '',
                Name => '',
                Description => '',
                ObjectType => '',
                ObjectId => '0',
                @_);

    my $obj = $RT::System;
    if ($args{ObjectId}) {
        $obj = $args{ObjectType}->new($self->CurrentUser);
        $obj->Load($args{ObjectId});
        $obj = $RT::System unless $obj->id;
    }

    return ( 0, $self->loc("Permission Denied"))
      unless ( $self->CurrentUser->HasRight(
                                            Right        => "AdminTopics",
                                            Object       => $obj,
                                            EquivObjects => [ $RT::System, $obj ],
                                           ) );

    $self->SUPER::Create(@_);
}

# }}}


# {{{ Delete

=head2 Delete

Deletes this topic, reparenting all sub-topics to this one's parent.

=cut

sub Delete {
    my $self = shift;
    
    unless ( $self->CurrentUserHasRight('AdminTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    my $kids = RT::Topics->new($self->CurrentUser);
    $kids->LimitToKids($self->Id);
    while (my $topic = $kids->Next) {
        $topic->setParent($self->Parent);
    }

    $self->SUPER::Delete(@_);
    return (0, "Topic deleted");
}

# }}}


# {{{ DeleteAll

=head2 DeleteAll

Deletes this topic, and all of its descendants.

=cut

sub DeleteAll {
    my $self = shift;
    
    unless ( $self->CurrentUserHasRight('AdminTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

    $self->SUPER::Delete(@_);
    my $kids = RT::Topics->new($self->CurrentUser);
    $kids->LimitToKids($self->Id);
    while (my $topic = $kids->Next) {
        $topic->DeleteAll;
    }

    return (0, "Topic tree deleted");
}

# }}}


# {{{ ParentObj

=head2 ParentObj

Returns the parent Topic of this one.

=cut

sub ParentObj {
  my $self = shift;
  my $id = $self->Parent;
  my $obj = RT::Topic->new($self->CurrentUser);
  $obj->Load($id);
  return $obj;
}

# }}}

# {{{ Children

=head2 Children

Returns a Topics object containing this topic's children,
sorted by Topic.Name.

=cut

sub Children {
    my $self = shift;
    unless ($self->{'Children'}) {
        $self->{'Children'} = RT::Topics->new($self->CurrentUser);
        $self->{'Children'}->Limit('FIELD' => 'Parent',
                                   'VALUE' => $self->Id);
        $self->{'Children'}->OrderBy('FIELD' => 'Name');
    }
    return $self->{'Children'};
}

# {{{ _Set

=head2 _Set

Intercept attempts to modify the Topic so we can apply ACLs

=cut

sub _Set {
    my $self = shift;
    
    unless ( $self->CurrentUserHasRight('AdminTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }
    $self->SUPER::_Set(@_);
}

# }}}


=head2 ACLEquivalenceObjects

Rights on the topic are inherited from the object it is a topic on.

=cut

sub ACLEquivalenceObjects {
    my $self  = shift;
    return unless $self->id and $self->ObjectId;

    return $self->Object;
}


sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new( $self->CurrentUser );
    $Object->Load( $self->__Value('ObjectId') );
    return $Object;
}

=head2 id

Returns the current value of id. 
(In the database, id is stored as int(11).)


=cut


=head2 Parent

Returns the current value of Parent. 
(In the database, Parent is stored as int(11).)



=head2 SetParent VALUE


Set Parent to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Parent will be stored as a int(11).)


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
        Parent => 
                {read => 1, write => 1, type => 'int(11)', default => ''},
        Name => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
        Description => 
                {read => 1, write => 1, type => 'varchar(255)', default => ''},
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
    $deps->Add( out => $self->ParentObj ) if $self->ParentObj->Id;
    $deps->Add( in  => $self->Children );
    $deps->Add( out => $self->Object );
}

RT::Base->_ImportOverlays();
1;
