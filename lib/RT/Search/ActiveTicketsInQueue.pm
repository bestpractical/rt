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
=head1 NAME

  RT::Search::ActiveTicketsInQueue

=head1 SYNOPSIS

=head1 DESCRIPTION

Find all active tickets in the queue named in the argument passed in

=head1 METHODS


=begin testing

ok (require RT::Search::Generic);

=end testing


=cut

package RT::Search::ActiveTicketsInQueue;

use strict;
use base qw(RT::Search::Generic);


# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return ($self->loc("No description for [_1]", ref $self));
}
# }}}

# {{{ sub Prepare
sub Prepare  {
  my $self = shift;

  $self->TicketsObj->LimitQueue(VALUE => $self->Argument);

  foreach my $status (RT::Queue->ActiveStatusArray()) {
        $self->TicketsObj->LimitStatus(VALUE => $status);
  }

  return(1);
}
# }}}

eval "require RT::Search::ActiveTicketsInQueue_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/ActiveTicketsInQueue_Vendor.pm});
eval "require RT::Search::ActiveTicketsInQueue_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Search/ActiveTicketsInQueue_Local.pm});

1;
