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

use strict;
no warnings qw/redefine/;

sub _Init { 
  my $self = shift;
  $self->{'table'} = "FM_Transactions";
  $self->{'primary_key'} = "id";
  
  $self->OrderBy( ALIAS => 'main',
          FIELD => 'Created',
          ORDER => 'ASC');


  return ( $self->SUPER::_Init(@_));
}


1;
