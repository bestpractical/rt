# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

#$Header: /raid/cvsroot/fm/lib/RT/FM/Record.pm,v 1.3 2001/09/09 07:19:58 jesse Exp $

=head1 NAME

  RT::FM::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut


package RT::FM::Record;
use RT::Record;

@ISA= qw(RT::Record);


=head2 Load <id | Name >

Loads an object, either by name or by id. If the value is an integer, it
presumes it's an id.

=cut 

sub Load {
    my $self = shift;
    my $id = shift;

    if ($id =~ /^(\d+)$/) {
        $self->SUPER::Load($id);
    } else {
        $self->LoadByCols( Name => $id);
    }
}


=head2 _ClassAccessible

Return this object's _ClassAccessible.

If we're running on RT 3.1 or newer, we need defer to the superclass

If we're running 3.0, dispatch to the CoreAccessible.



=cut

sub _ClassAccessible {
    my $self = shift;

    if ($RT::VERSION =~ /^3.0/)  {
        $self->_CoreAccessible(); 
    } else  {
        $self->SUPER::_ClassAccessible(); 
    }
}

1;
