# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Condition::ViaInterface;
use base 'RT::Condition';

use strict;
use warnings;


=head2 IsApplicable

If the transaction is created via a specified interface.

=cut

sub IsApplicable {
    my $self = shift;

    return 0 unless $self->Argument;
    my @interfaces = split /,/, $self->Argument;

    my $current_interface = lc RT->CurrentInterface;
    return 1 if grep { $current_interface eq lc $_ } @interfaces;
    return 0;
}

sub SupportsLookupType {
    my $self = shift;
    my $type = shift;
    my %all_types = map { $_->CustomFieldLookupType => 1 } qw/RT::Article RT::Asset RT::Ticket/;
    if ( defined $type ) {
        return $all_types{$type} ? 1 : 0;
    }
    return sort keys %all_types;
}

RT::Base->_ImportOverlays();

1;
