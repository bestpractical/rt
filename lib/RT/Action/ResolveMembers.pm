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
# This Action will resolve all members of a resolved group ticket

package RT::Action::ResolveMembers;
require RT::Action::Generic;
require RT::Links;

use strict;
use vars qw/@ISA/;
@ISA=qw(RT::Action::Generic);

#Do what we need to do and send it out.

#What does this type of Action does

# {{{ sub Describe 
sub Describe  {
  my $self = shift;
  return $self->loc("[_1] will resolve all members of a resolved group ticket.", ref $self);
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

    my $Links=RT::Links->new($RT::SystemUser);
    $Links->Limit(FIELD => 'Type', VALUE => 'MemberOf');
    $Links->Limit(FIELD => 'Target', VALUE => $self->TicketObj->id);

    while (my $Link=$Links->Next()) {
	# Todo: Try to deal with remote URIs as well
	next unless $Link->BaseURI->IsLocal;
	my $base=RT::Ticket->new($self->TicketObj->CurrentUser);
	# Todo: Only work if Base is a plain ticket num:
	$base->Load($Link->Base);
	# I'm afraid this might be a major bottleneck if ResolveGroupTicket is on.
        $base->Resolve;
    }
}


# Applicability checked in Commit.

# {{{ sub IsApplicable 
sub IsApplicable  {
  my $self = shift;
  1;  
  return 1;
}
# }}}

eval "require RT::Action::ResolveMembers_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/ResolveMembers_Vendor.pm});
eval "require RT::Action::ResolveMembers_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/ResolveMembers_Local.pm});

1;

