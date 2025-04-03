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

package RT::Report::Transactions;

use base qw/RT::Report RT::Transactions/;
use RT::Report::Transactions::Entry;

use strict;
use warnings;
use 5.010;


=head1 NAME

RT::Report::Transactions - Transaction search charts

=head1 DESCRIPTION

This is the backend class for transaction search charts.

=cut

our @GROUPINGS = (
    Creator => 'User',    #loc_left_pair
    Created => 'Date',    #loc_left_pair
);

# loc'able strings below generated with (s/loq/loc/):
#   perl -MRT=-init -MRT::Report::Transactions -E 'say qq{\# loq("$_->[0]")} while $_ = splice @RT::Report::Transactions::STATISTICS, 0, 2'
#
# loc("Transaction count")

our @STATISTICS = (
    COUNT            => [ 'Transaction count',     'Count',   'id' ],
    "ALL(TimeTaken)" => [ "Summary of Time Taken", 'TimeAll', 'TimeTaken' ],
    "SUM(TimeTaken)" => [ "Total Time Taken",      'Time',    'SUM', 'TimeTaken' ],
    "AVG(TimeTaken)" => [ "Average Time Taken",    'Time',    'AVG', 'TimeTaken' ],
    "MIN(TimeTaken)" => [ "Minimum Time Taken",    'Time',    'MIN', 'TimeTaken' ],
    "MAX(TimeTaken)" => [ "Maximum Time Taken",    'Time',    'MAX', 'TimeTaken' ],
);

sub SetupGroupings {
    my $self = shift;
    my %args = (
        Query    => undef,
        GroupBy  => undef,
        Function => undef,
        @_
    );

    # Unlike tickets, UseSQLForACLChecks is not supported in transactions, thus we need to iterate transactions first
    # to filter by rights, which is implemented in RT::Transactions::AddRecord
    if ( $args{'Query'} ) {
        my $txns = RT::Transactions->new( $self->CurrentUser );
        # Currently we only support ticket transaction search.
        $txns->FromSQL( "ObjectType='RT::Ticket' AND TicketType = 'ticket' AND ($args{'Query'})" );
        $txns->Columns('id');

        my @match = (0);
        while ( my $row = $txns->Next ) {
            push @match, $row->id;
        }

        $self->CleanSlate;
        while ( @match > 1000 ) {
            my @batch = splice( @match, 0, 1000 );
            $self->Limit( FIELD => 'Id', OPERATOR => 'IN', VALUE => \@batch );
        }
        $self->Limit( FIELD => 'Id', OPERATOR => 'IN', VALUE => \@match );
    }

    return $self->_SetupGroupings(%args);
}

sub _DoSearch {
    my $self = shift;

    # Reset the unnecessary default order by(created and id, defined in RT::Transactions::_Init), otherwise Pg will
    # error out: column "main.created" must appear in the GROUP BY clause or be used in an aggregate function; while
    # Oracle will error out: ORA-00979: not a GROUP BY expression
    $self->OrderByCols();

    $self->SUPER::_DoSearch(@_);
    $self->_PostSearch();
}

RT::Base->_ImportOverlays();

1;
