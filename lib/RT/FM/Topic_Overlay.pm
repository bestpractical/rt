# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
#

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
    
    unless ( $self->CurrentUserHasRight('AdminTopics') ) {
        return ( 0, $self->loc("Permission Denied") );
    }

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

# {{{ HasKids

=head2 HasKids

Returns a true value if this topic has child topics.

=cut

sub HasKids {
    my $self = shift;
    my $kids = RT::FM::TopicCollection->new($self->CurrentUser);
    $kids->Limit('FIELD' => 'Parent',
		 'VALUE' => $self->Id);
    return $kids->Count;
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
