# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Action::SLA_SetDefault;

use base qw(RT::Action::SLA);

=head1 NAME

RT::Action::SLA_SetDefault - set default SLA value

=head1 DESCRIPTION

Sets a default level of service. Transaction's created field is used
to calculate if things happen in hours or out of. Default value then
figured from L<InHoursDefault|XXX> and L<OutOfHoursDefault|XXX> options.

This action doesn't check if the ticket has a value already, so you
have to use it with condition that checks this fact for you, however
such behaviour allows you to force setting up default using custom
condition. The default condition for this action is
L<RT::Condition::SLA_RequireDefault>.

=cut

sub Prepare { return 1 }
sub Commit {
    my $self = shift;

    my $cf = $self->GetCustomField;
    unless ( $cf->id ) {
        $RT::Logger->warning("SLA scrip applied to a queue that has no SLA CF");
        return 1;
    }

    my $level = $self->GetDefaultServiceLevel;
    unless ( $level ) {
        $RT::Logger->info(
            "No default service level for ticket #". $self->TicketObj->id 
            ." in queue ". $self->TicketObj->QueueObj->Name );
        return 1;
    }

    my ($status, $msg) = $self->TicketObj->AddCustomFieldValue(
        Field => $cf->id,
        Value => $level,
    );
    unless ( $status ) {
        $RT::Logger->error("Couldn't set service level: $msg");
        return 0;
    }

    return 1;
};

1;
