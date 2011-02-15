# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

# This Action will open the BASE if a dependent is resolved.
package RT::Action::AutoOpen;

use strict;
use warnings;

use base qw(RT::Action);

=head1 DESCRIPTION

Opens a ticket unless it's allready open, but only unless transaction
L<RT::Transaction/IsInbound is inbound>.

Doesn't open a ticket if message's head has field C<RT-Control> with
C<no-autoopen> substring.

=cut

sub Prepare {
    my $self = shift;

    # if the ticket is already open or the ticket is new and the message is more mail from the
    # requestor, don't reopen it.

    my $status = $self->TicketObj->Status;
    return undef if $status eq 'open';
    return undef if $status eq 'new' && $self->TransactionObj->IsInbound;

    if ( my $msg = $self->TransactionObj->Message->First ) {
        return undef if ($msg->GetHeader('RT-Control') || '') =~ /\bno-autoopen\b/i;
    }

    return 1;
}

sub Commit {
    my $self = shift;

    my $oldstatus = $self->TicketObj->Status;
    $self->TicketObj->__Set( Field => 'Status', Value => 'open' );
    $self->TicketObj->_NewTransaction(
        Type     => 'Status',
        Field    => 'Status',
        OldValue => $oldstatus,
        NewValue => 'open',
        Data     => 'Ticket auto-opened on incoming correspondence'
    );

    return 1;
}

eval "require RT::Action::AutoOpen_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/AutoOpen_Vendor.pm});
eval "require RT::Action::AutoOpen_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Action/AutoOpen_Local.pm});

1;
