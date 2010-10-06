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
package RT::FM::Topic;

use strict;
no warnings qw(redefine);

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

    my $obj = $RT::FM::System;
    if ($args{ObjectId}) {
        $obj = $args{ObjectType}->new($self->CurrentUser);
        $obj->Load($args{ObjectId});
        $obj = $RT::FM::System unless $obj->id;
    }

    return ( 0, $self->loc("Permission denied"))
      unless ( $self->CurrentUser->HasRight(
                                            Right        => "AdminTopics",
                                            Object       => $obj,
                                            EquivObjects => [ $RT::FM::System, $obj ],
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

    my $kids = new RT::FM::TopicCollection($self->CurrentUser);
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
    my $kids = new RT::FM::TopicCollection($self->CurrentUser);
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
  my $obj = new RT::FM::Topic($self->CurrentUser);
  $obj->Load($id);
  return $obj;
}

# }}}

# {{{ Children

=head2 Children

Returns a TopicCollection object containing this topic's children,
sorted by Topic.Name.

=cut

sub Children {
    my $self = shift;
    unless ($self->{'Children'}) {
        $self->{'Children'} = RT::FM::TopicCollection->new($self->CurrentUser);
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


# {{{ CurrentUserHasRight

=head2 CurrentUserHasRight

Returns true if the current user has the right for this topic, for the
whole system or for whatever object this topic is associated with

=cut

sub CurrentUserHasRight {
    my $self  = shift;
    my $right = shift;

    my $equiv = [ $RT::FM::System ];
    if ($self->ObjectId) {
        my $obj = $self->ObjectType->new($self->CurrentUser);
        $obj->Load($self->ObjectId);
        push @{$equiv}, $obj;
    }
    if ($self->Id) {
        return ( $self->CurrentUser->HasRight(
                                              Right        => $right,
                                              Object       => $self,
                                              EquivObjects => $equiv,
                                             ) );
    } else {
        # If we don't have an ID, we don't even know what object we're
        # attached to -- so the only thing we can fall back on is the
        # system object.
        return ( $self->CurrentUser->HasRight(
                                              Right        => $right,
                                              Object       => $RT::FM::System,
                                             ) );
    }
    

}

# }}}

1;
