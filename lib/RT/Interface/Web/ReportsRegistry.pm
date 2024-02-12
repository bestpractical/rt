# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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
use 5.010;

package RT::Interface::Web::ReportsRegistry;

=head1 NAME

    RT::Interface::Web::ReportsRegistry - helper functions for reports

=cut

our $registry = {
    resolvedbyowner => {
        id    => 'resolvedbyowner',
        title => 'Resolved by owner',               # loc
        path  => '/Reports/ResolvedByOwner.html',
    },
    resolvedindaterange => {
        id    => 'resolvedindaterange',
        title => 'Resolved in date range',          # loc
        path  => '/Reports/ResolvedByDates.html',
    },
    createdindaterange => {
        id    => 'createdindaterange',
        title => 'Created in a date range',         # loc
        path  => '/Reports/CreatedByDates.html',
    },
    user_time => {
        id    => 'user_time',
        title => 'User time worked',                # loc
        path  => '/Reports/TimeWorkedReport.html',
    },
};

=head2 Reports

Returns a list (array ref) of all registered reports. Reports are sorted by title.
Every element is a hash ref with the following keys:

=over 4

=item id - unique string identifier

=item title - human-readable title

=item path - path to the report relative to the root

=back

=cut

sub Reports {
    my @res
        = sort { lc( $a->{title} ) cmp lc( $b->{title} ) } values %$registry;
    return \@res;
}

=head2 Register

Registers a report that can be added to the Reports menu.

    use RT::Interface::Web::ReportsRegistry;
    RT::Interface::Web::ReportsRegistry->Register(
        id    => 'my_super_report',
        title => 'Super report',
        path  => 'MySuperReport.html',
    );

All reports are expected to be in the /Reports/ directory.

B<Note> that using existing id will overwrite the record in the registry.

=cut

sub Register {
    my $self = shift;
    my %args = (
        id    => undef,
        title => undef,
        path  => undef,
        @_
    );
    die "id is required" unless $args{id};

    $registry->{ $args{id} } = {
        id    => $args{id},
        title => $args{title},
        path  => '/Reports/' . $args{path},
    };
}

require RT::Base;
RT::Base->_ImportOverlays();

1;
