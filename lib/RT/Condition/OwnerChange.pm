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
 


package RT::Condition::OwnerChange;
require RT::Condition::Generic;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Condition::Generic);


=head2 IsApplicable

If we're changing the owner return true, otherwise return false

=begin testing

my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name =>'ownerChangeTest');

ok($q->Id, "Created a scriptest queue");

my $s1 = RT::Scrip->new($RT::SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripAction => 'User Defined',
             ScripCondition => 'On Owner Change',
             CustomIsApplicableCode => '',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '
                   $RT::Logger->crit("Before, prio is ".$self->TicketObj->Priority);
                    $self->TicketObj->SetPriority($self->TicketObj->Priority+1);
                   $RT::Logger->crit("After, prio is ".$self->TicketObj->Priority);
                return(1);
            ',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    InitialPriority => '20'
                                    );
ok($tv, $tm);
ok($ticket->SetOwner('root'));
is ($ticket->Priority , '21', "Ticket priority is set right");
ok($ticket->Steal);
is ($ticket->Priority , '22', "Ticket priority is set right");
ok($ticket->Untake);
is ($ticket->Priority , '23', "Ticket priority is set right");
ok($ticket->Take);
is ($ticket->Priority , '24', "Ticket priority is set right");





=end testing


=cut

sub IsApplicable {
    my $self = shift;
    if ($self->TransactionObj->Field eq 'Owner') {
	return(1);
    } 
    else {
	return(undef);
    }
}

eval "require RT::Condition::OwnerChange_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/OwnerChange_Vendor.pm});
eval "require RT::Condition::OwnerChange_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Condition/OwnerChange_Local.pm});

1;

