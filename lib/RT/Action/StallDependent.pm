# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
# This Action will stall the BASE if a dependency or membership link
# (according to argument) is created and if BASE is open.

# TODO: Rename this .pm

package RT::Action::StallDependent;
require RT::Action::Generic;
@ISA=qw|RT::Action::Generic|;

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return $self->loc("[_1] will stall a [local] BASE if it's dependent [or member] of a linked up request.", ref $self);
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
    # Find all Dependent
    my $arg=$self->Argument || "DependsOn";
    unless ($self->TransactionObj->Data =~ /^([^ ]+) $arg /) {
	warn; return 0;
    }
    my $base_id=$1;
    my $base;
    if ($1 eq "THIS") {
	$base=$self->TicketObj;
    } else {
	$base_id=&RT::Link::_IsLocal(undef, $base_id) || return 0;
	$base=RT::Ticket->new($self->TicketObj->CurrentUser);
	$base->Load($base_id);
    }
    $base->Stall if $base->Status eq 'open';
    return 0;
}


# {{{ sub IsApplicable 

# Only applicable if:
# 1. the link action is a dependency
# 2. BASE is a local ticket

sub IsApplicable  {
  my $self = shift;

  my $arg=$self->Argument || "DependsOn";

  # 1:
  $self->TransactionObj->Data =~ /^([^ ]*) $arg / || return 0;

  # 2:
  # (dirty!)
  &RT::Link::_IsLocal(undef,$1) || return 0;

  return 1;
}
# }}}

1;
