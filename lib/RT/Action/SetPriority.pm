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
package RT::Action::SetPriority;
require RT::Action::Generic;

use strict;
use vars qw/@ISA/;
@ISA=qw(RT::Action::Generic);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return (ref $self . " will set a ticket's priority to the argument provided.");
}
# }}}


# {{{ sub Prepare 
sub Prepare  {
    # nothing to prepare
    return 1;
}
# }}}

sub Commit {
    my $self = shift;
    $self->TicketObj->SetPriority($self->Argument);

}

eval "require RT::Action::SetPriority_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SetPriority_Vendor.pm});
eval "require RT::Action::SetPriority_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/SetPriority_Local.pm});

1;
