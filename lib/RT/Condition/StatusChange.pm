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

package RT::Condition::StatusChange;
use base 'RT::Condition';
use strict;
use warnings;

=head2 DESCRIPTION

This condition check passes if the current transaction is a status change.

The argument can be used to apply additional conditions on old and new values.

If argument is empty then the check passes for any change of the status field.

If argument is equal to new value then check is passed. This is behavior
is close to RT 3.8 and older. For example, setting the argument to 'resolved' means
'fire scrip when status changed from any to resolved'.

The following extended format is supported:

    old: comma separated list; new: comma separated list

For example:

    old: open; new: resolved

You can omit old or new part, for example:

    old: open

    new: resolved

You can specify multiple values, for example:

    old: new, open; new: resolved, rejected

Status sets ('initial', 'active' or 'inactive') can be used, for example:

    old: active; new: inactive

    old: initial, active; new: resolved

=cut

sub IsApplicable {
    my $self = shift;
    my $txn = $self->TransactionObj;
    my ($type, $field) = ($txn->Type, $txn->Field);
    return 0 unless $type eq 'Status' || ($type eq 'Set' && $field eq 'Status');

    my $argument = $self->Argument;
    return 1 unless $argument;

    my $new = $txn->NewValue || '';
    return 1 if $argument eq $new;

    # let's parse argument
    my ($old_must_be, $new_must_be) = ('', '');
    if ( $argument =~ /^\s*old:\s*(.*);\s*new:\s*(.*)\s*$/i ) {
        ($old_must_be, $new_must_be) = ($1, $2);
    }
    elsif ( $argument =~ /^\s*new:\s*(.*)\s*$/i ) {
        $new_must_be = $1;
    }
    elsif ( $argument =~ /^\s*old:\s*(.*)\s*$/i ) {
        $old_must_be = $1;
    }
    else {
        $RT::Logger->error("Argument '$argument' is incorrect.")
            unless RT::Lifecycle->Load(Type => 'ticket')->IsValid( $argument );
        return 0;
    }

    my $lifecycle = $self->TicketObj->LifecycleObj;
    if ( $new_must_be ) {
        return 0 unless grep lc($new) eq lc($_),
            map {m/^(initial|active|inactive)$/i? $lifecycle->Valid(lc $_): $_ }
            grep defined && length,
            map { s/^\s+//; s/\s+$//; $_ }
            split /,/, $new_must_be;
    }
    if ( $old_must_be ) {
        my $old = lc($txn->OldValue || '');
        return 0 unless grep $old eq lc($_),
            map {m/^(initial|active|inactive)$/i? $lifecycle->Valid(lc $_): $_ }
            grep defined && length,
            map { s/^\s+//; s/\s+$//; $_ }
            split /,/, $old_must_be;
    }
    return 1;
}

RT::Base->_ImportOverlays();

1;

