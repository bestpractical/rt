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

=head1 NAME

  RT::Attribute_Overlay 

=head1 Content

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  varchar(200) 'Name'.
  varchar(255) 'Content'.
  varchar(64) 'ObjectType'.
  int(11) 'ObjectId'.

You may pass a C<Object> instead of C<ObjectType> and C<ObjectId>.

=cut




sub Create {
    my $self = shift;
    my %args = ( 
                Name => '',
                Content => '',
                ObjectType => '',
                ObjectId => '0',
		  @_);

    if ($args{Object} and UNIVERSAL::can($args{Object}, 'Id')) {
	$args{ObjectType} = ref($args{Object});
	$args{ObjectId} = $args{Object}->Id;
    }

    $self->SUPER::Create(
                         Name => $args{'Name'},
                         Content => $args{'Content'},
                         ObjectType => $args{'ObjectType'},
                         ObjectId => $args{'ObjectId'},
);

}


# {{{ sub LoadByNameAndObject

=head2  LoadByNameAndObject (Object => OBJECT, Name => NAME)

Loads the Attribute named NAME for Object OBJECT.

=cut

sub LoadByNameAndObject {
    my $self = shift;
    my %args = (
        Object => undef,
        Name  => undef,
        @_,
    );

    return (
	$self->LoadByCols(
	    Name => $args{'Name'},
	    ObjectType => ref($args{'Object'}),
	    ObjectId => $args{'Object'}->Id,
	)
    );

}

# }}}

1;
