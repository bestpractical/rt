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
use strict;
no warnings qw(redefine);

# {{{ LimitToObject

=head2 LimitToObject OBJ

Find all Topics hung off of the given Object

=cut

sub LimitToObject {
    my $self = shift;
    my $object = shift;
    
    $self->Limit(FIELD => 'ObjectId',
                 VALUE => $object->Id);
    $self->Limit(FIELD => 'ObjectType',
                 VALUE => ref($object));
}

# }}}


# {{{ LimitToKids

=head2 LimitToKids TOPIC

Find all Topics which are immediate children of Id TOPIC.  Note this
does not do the recursive query of their kids, etc.

=cut

sub LimitToKids {
    my $self = shift;
    my $topic = shift;
    
    $self->Limit(FIELD => 'Parent',
                 VALUE => $topic);
}

# }}}

1;
