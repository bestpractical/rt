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

# {{{ LimitToTopic

=head2 LimitToTopic FIELD

Returns values for the topic with Id FIELD

=cut
  
sub LimitToTopic {
    my $self = shift;
    my $cf = shift;
    return ($self->Limit( FIELD => 'Topic',
			  VALUE => $cf,
			  OPERATOR => '='));

}

# }}}


# {{{ LimitToObject

=head2 LimitToObject OBJ

Returns associations for the given OBJ only

=cut

sub LimitToObject {
    my $self = shift;
    my $object = shift;

    $self->Limit( FIELD => 'ObjectType',
		  VALUE => ref($object));
    $self->Limit( FIELD => 'ObjectId',
                  VALUE => $object->Id);

}

# }}}

1;
