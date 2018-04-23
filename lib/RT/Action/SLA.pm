# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

package RT::Action::SLA;

use base qw(RT::SLA RT::Action);

=head1 NAME

RT::Action::SLA - base class for all actions in the extension

=head1 DESCRIPTION

It's not a real action, but container for subclassing which provide
help methods for other actions.

=head1 METHODS

=head2 SetDateField NAME VALUE

Sets specified ticket's date field to the value, doesn't update
if field is set already. VALUE is unix time.

=cut

sub SetDateField {
    my $self = shift;
    my ($type, $value) = (@_);

    my $ticket = $self->TicketObj;

    my $method = $type .'Obj';
    if ( defined $value ) {
        return 1 if $ticket->$method->Unix == $value;
    } else {
        return 1 if $ticket->$method->Unix <= 0;
    }

    my $date = RT::Date->new( $RT::SystemUser );
    $date->Set( Format => 'unix', Value => $value );

    $method = 'Set'. $type;
    return 1 if $ticket->$type eq $date->ISO;
    my ($status, $msg) = $ticket->$method( $date->ISO );
    unless ( $status ) {
        $RT::Logger->error("Couldn't set $type date: $msg");
        return 0;
    }

    return 1;
}

1;
