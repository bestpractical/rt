# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
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

1;
