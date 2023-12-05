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

package RT::Report::Tickets;

use base qw/RT::Report RT::Tickets/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;
use 5.010;

=head1 NAME

RT::Report::Tickets - Ticket search charts

=head1 DESCRIPTION

This is the backend class for ticket search charts.

=head1 METHOD

=cut

__PACKAGE__->RegisterCustomFieldJoin(@$_) for
    [ "RT::Transaction" => sub { $_[0]->JoinTransactions } ],
    [ "RT::Queue"       => sub {
            # XXX: Could avoid join and use main.Queue with some refactoring?
            return $_[0]->{_sql_aliases}{queues} ||= $_[0]->Join(
                ALIAS1 => 'main',
                FIELD1 => 'Queue',
                TABLE2 => 'Queues',
                FIELD2 => 'id',
            );
        }
    ];

our @GROUPINGS = (
    Status => 'Enum',                   #loc_left_pair

    Queue  => 'Queue',                  #loc_left_pair

    InitialPriority => 'Priority',          #loc_left_pair
    FinalPriority   => 'Priority',          #loc_left_pair
    Priority        => 'Priority',          #loc_left_pair

    Owner         => 'User',            #loc_left_pair
    Creator       => 'User',            #loc_left_pair
    LastUpdatedBy => 'User',            #loc_left_pair

    Requestor     => 'Watcher',         #loc_left_pair
    Cc            => 'Watcher',         #loc_left_pair
    AdminCc       => 'Watcher',         #loc_left_pair
    Watcher       => 'Watcher',         #loc_left_pair
    CustomRole    => 'Watcher',

    Created       => 'Date',            #loc_left_pair
    Starts        => 'Date',            #loc_left_pair
    Started       => 'Date',            #loc_left_pair
    Resolved      => 'Date',            #loc_left_pair
    Due           => 'Date',            #loc_left_pair
    Told          => 'Date',            #loc_left_pair
    LastUpdated   => 'Date',            #loc_left_pair

    CF            => 'CustomField',     #loc_left_pair

    SLA           => 'Enum',            #loc_left_pair
);

# loc'able strings below generated with (s/loq/loc/):
#   perl -MRT=-init -MRT::Report::Tickets -E 'say qq{\# loq("$_->[0]")} while $_ = splice @RT::Report::Tickets::STATISTICS, 0, 2'
#
# loc("Ticket count")
# loc("Summary of time worked")
# loc("Total time worked")
# loc("Average time worked")
# loc("Minimum time worked")
# loc("Maximum time worked")
# loc("Summary of time estimated")
# loc("Total time estimated")
# loc("Average time estimated")
# loc("Minimum time estimated")
# loc("Maximum time estimated")
# loc("Summary of time left")
# loc("Total time left")
# loc("Average time left")
# loc("Minimum time left")
# loc("Maximum time left")
# loc("Summary of Created to Started")
# loc("Total Created to Started")
# loc("Average Created to Started")
# loc("Minimum Created to Started")
# loc("Maximum Created to Started")
# loc("Summary of Created to Resolved")
# loc("Total Created to Resolved")
# loc("Average Created to Resolved")
# loc("Minimum Created to Resolved")
# loc("Maximum Created to Resolved")
# loc("Summary of Created to LastUpdated")
# loc("Total Created to LastUpdated")
# loc("Average Created to LastUpdated")
# loc("Minimum Created to LastUpdated")
# loc("Maximum Created to LastUpdated")
# loc("Summary of Starts to Started")
# loc("Total Starts to Started")
# loc("Average Starts to Started")
# loc("Minimum Starts to Started")
# loc("Maximum Starts to Started")
# loc("Summary of Due to Resolved")
# loc("Total Due to Resolved")
# loc("Average Due to Resolved")
# loc("Minimum Due to Resolved")
# loc("Maximum Due to Resolved")
# loc("Summary of Started to Resolved")
# loc("Total Started to Resolved")
# loc("Average Started to Resolved")
# loc("Minimum Started to Resolved")
# loc("Maximum Started to Resolved")

our @STATISTICS = (
    COUNT => ['Ticket count', 'Count', 'id'],
);

foreach my $field (qw(TimeWorked TimeEstimated TimeLeft)) {
    my $friendly = lc join ' ', split /(?<=[a-z])(?=[A-Z])/, $field;
    push @STATISTICS, (
        "ALL($field)" => ["Summary of $friendly",   'TimeAll',     $field ],
        "SUM($field)" => ["Total $friendly",   'Time', 'SUM', $field ],
        "AVG($field)" => ["Average $friendly", 'Time', 'AVG', $field ],
        "MIN($field)" => ["Minimum $friendly", 'Time', 'MIN', $field ],
        "MAX($field)" => ["Maximum $friendly", 'Time', 'MAX', $field ],
    );
}


foreach my $pair (
    'Created to Started',
    'Created to Resolved',
    'Created to LastUpdated',
    'Starts to Started',
    'Due to Resolved',
    'Started to Resolved',
) {
    my ($from, $to) = split / to /, $pair;
    push @STATISTICS, (
        "ALL($pair)" => ["Summary of $pair", 'DateTimeIntervalAll', $from, $to ],
        "SUM($pair)" => ["Total $pair", 'DateTimeInterval', 'SUM', $from, $to ],
        "AVG($pair)" => ["Average $pair", 'DateTimeInterval', 'AVG', $from, $to ],
        "MIN($pair)" => ["Minimum $pair", 'DateTimeInterval', 'MIN', $from, $to ],
        "MAX($pair)" => ["Maximum $pair", 'DateTimeInterval', 'MAX', $from, $to ],
    );
    push @GROUPINGS, $pair => 'Duration';

    my %extra_info = ( business_time => 1 );
    if ( keys %{RT->Config->Get('ServiceBusinessHours')} ) {
        my $business_pair = "$pair(Business Hours)";
        push @STATISTICS, (
            "ALL($business_pair)" => ["Summary of $business_pair", 'DateTimeIntervalAll', $from, $to, \%extra_info ],
            "SUM($business_pair)" => ["Total $business_pair", 'DateTimeInterval', 'SUM', $from, $to, \%extra_info ],
            "AVG($business_pair)" => ["Average $business_pair", 'DateTimeInterval', 'AVG', $from, $to, \%extra_info ],
            "MIN($business_pair)" => ["Minimum $business_pair", 'DateTimeInterval', 'MIN', $from, $to, \%extra_info ],
            "MAX($business_pair)" => ["Maximum $business_pair", 'DateTimeInterval', 'MAX', $from, $to, \%extra_info ],
        );
        push @GROUPINGS, $business_pair => 'DurationInBusinessHours';
    }
}

=head2 _DoSearch

Subclass _DoSearch from our parent so we can go through and add in empty
columns if it makes sense.

Besides it, for cases where GroupBy/Calculation couldn't be implemented via
SQL, we have to implement it in Perl, like business hours, time duration,
custom date ranges, etc.

=cut

sub _DoSearch {
    my $self = shift;

    # When groupby/calculation can't be done at SQL level, do it at Perl level
    return $self->_DoSearchInPerl(@_) if $self->{_query};

    $self->SUPER::_DoSearch( @_ );
    $self->_PostSearch();
}

sub new {
    my $self = shift;
    $self->_SetupCustomDateRanges;
    return $self->SUPER::new(@_);
}

RT::Base->_ImportOverlays();

1;
