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

=head1 NAME

RT::Search::Calendar - Utility functions for calendars

=head1 DESCRIPTION

This class is a collection of utility functions for working with calendars.

=cut

package RT::Search::Calendar;

use warnings;
use strict;
use DateTime;
use DateTime::Set;

sub CalendarFirstDay {
    my ( $year, $month, $matchday ) = @_;
    my $set
        = DateTime::Set->from_recurrence(
        next => sub { $_[0]->truncate( to => 'day' )->subtract( days => 1 ) }
        );

    my $day = DateTime->new( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != $matchday;
    $day;

}

sub CalendarLastDay {
    my ( $year, $month, $matchday ) = @_;
    my $set = DateTime::Set->from_recurrence(
        next => sub { $_[0]->truncate( to => 'day' )->add( days => 1 ) } );

    my $day = DateTime->last_day_of_month( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != $matchday;
    $day;
}

sub GetMultipleDayFields {
    my ( $Dates ) = @_;

    # Check if we have both Starts and Due
    my $has_starts = grep { $_ eq 'Starts' } @$Dates;
    my $has_due = grep { $_ eq 'Due' } @$Dates;
    my $has_started = grep { $_ eq 'Started' } @$Dates;
    my $has_resolved = grep { $_ eq 'Resolved' } @$Dates;

    # Priority: If all four are present, use Starts and Due
    # Otherwise, use the pair that's available
    if ($has_starts && $has_due) {
        return ('Starts', 'Due');
    }
    elsif ($has_started && $has_resolved) {
        return ('Started', 'Resolved');
    }
    return undef;
}

sub DatesClauses {
    my ( $Dates, $begin, $end, $starts_field, $ends_field ) = @_;

    my $clauses = "";

    my @DateClauses = map {
        "($_ >= '" . $begin . " 00:00:00' AND $_ <= '" . $end . " 23:59:59')"
    } @$Dates;

    # All multiple days events are already covered on the query above
    # The following code works for covering events that start before and ends
    # after the selected period.
    # Start and end fields of the multiple days must also be present on the
    # format.
    if ($starts_field && $ends_field) {
        push @DateClauses,
            "("
            . $starts_field
            . " <= '"
            . $end
            . " 00:00:00' AND "
            . $ends_field
            . " >= '"
            . $begin
            . " 23:59:59')";
    }

    $clauses .= " AND " . " ( " . join( " OR ", @DateClauses ) . " ) "
        if @DateClauses;

    return $clauses;
}

sub GetCalendarTickets {
    my ( $CurrentUser, $Query, $Dates, $begin, $end, $starts_field, $ends_field ) = @_;
    return {} unless @$Dates;

    # Use provided fields, or auto-detect from standard field pairs
    if ( !$starts_field || !$ends_field ) {
        ($starts_field, $ends_field) = GetMultipleDayFields($Dates);
    }

    $Query .= DatesClauses( $Dates, $begin, $end, $starts_field, $ends_field )
        if $begin and $end;

    my $Tickets = RT::Tickets->new($CurrentUser);
    $Tickets->FromSQL($Query);
    $Tickets->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    my %Calendar;  # Unified calendar structure
    my %AlreadySeen;

    while ( my $Ticket = $Tickets->Next() ) {
        # Skip reminders that don't refer to a ticket
        next if $Ticket->Type eq 'reminder' and not $Ticket->RefersTo->First;

        # First, check if this ticket has multi-day spanning capability
        my $has_multi_day = 0;
        my $span_start_date;
        my $span_end_date;
        my $span_id;

        if ($starts_field && $ends_field) {
            $span_start_date = GetCalendarDateObj( $starts_field, $Ticket, $CurrentUser );
            $span_end_date = GetCalendarDateObj( $ends_field, $Ticket, $CurrentUser );
            # Only consider it multi-day if both dates exist and are actually set (not Unix epoch)
            if ($span_start_date && $span_end_date &&
                $span_start_date->Unix > 0 && $span_end_date->Unix > 0) {
                $has_multi_day = 1;
                $span_id = sprintf("ticket%d_%s_%s", $Ticket->id, lc($starts_field), lc($ends_field));
            }
        }

        # Process single day events for each date field
        for my $Date (@$Dates) {
            # Skip spanning fields if we're processing them as multi-day events
            next if $has_multi_day && ($Date eq $starts_field || $Date eq $ends_field);

            my $dateindex_obj = GetCalendarDateObj( $Date, $Ticket, $CurrentUser );
            next unless $dateindex_obj;
            my $dateindex = $dateindex_obj->ISO( Time => 0, Timezone => 'user' );

            # Skip if this ticket/date combination was already processed
            next if $AlreadySeen{$dateindex}{$Ticket->id}{$Date};

            push @{ $Calendar{$dateindex} }, {
                ticket => $Ticket,
                event_type => 'single',
                span_id => undef,
                date_field => $Date,
                span_start => undef,
                span_end => undef,
            };

            $AlreadySeen{$dateindex}{$Ticket->id}{$Date} = 1;
        }

        # Process multi-day spanning events
        if ($has_multi_day) {
            # Use the dates we already calculated
            my $span_start = $span_start_date->ISO( Time => 0, Timezone => 'user' );
            my $span_end = $span_end_date->ISO( Time => 0, Timezone => 'user' );

            # Clip the loop range to the visible calendar range to avoid unnecessary iterations
            # Work with Unix timestamps for reliable comparison and date setting
            my $loop_start_obj = RT::Date->new($CurrentUser);
            my $loop_end_obj = RT::Date->new($CurrentUser);

            if ($begin && $end) {
                # Create date objects for begin and end
                my $begin_obj = RT::Date->new($CurrentUser);
                my $end_obj = RT::Date->new($CurrentUser);
                $begin_obj->Set(Format => 'unknown', Value => "$begin 00:00:00");
                $end_obj->Set(Format => 'unknown', Value => "$end 23:59:59");

                # Clip to visible range using Unix timestamps
                my $loop_start_unix = $span_start_date->Unix > $begin_obj->Unix ? $span_start_date->Unix : $begin_obj->Unix;
                my $loop_end_unix = $span_end_date->Unix < $end_obj->Unix ? $span_end_date->Unix : $end_obj->Unix;

                $loop_start_obj->Set(Format => 'unix', Value => $loop_start_unix);
                $loop_end_obj->Set(Format => 'unix', Value => $loop_end_unix);
            } else {
                # No clipping - use full span
                $loop_start_obj->Set(Format => 'unix', Value => $span_start_date->Unix);
                $loop_end_obj->Set(Format => 'unix', Value => $span_end_date->Unix);
            }

            my $loop_start = $loop_start_obj->ISO( Time => 0, Timezone => 'user' );
            my $loop_end = $loop_end_obj->ISO( Time => 0, Timezone => 'user' );

            # Loop through all days in the span (clipped to visible range)
            my $current_date = RT::Date->new($CurrentUser);
            $current_date->Set(
                Format => 'unix',
                Value => $loop_start_obj->Unix,
            );

            my $prevent_infinite_loop = 0;

            my ($year, $month, $day) = split /-/, $loop_start;
            my $loop_date = DateTime->new( year => $year, month => $month, day => $day );

            # With clipping, we should never iterate more than ~42 days for a monthly calendar view
            # Use 100 as a safe limit that allows for edge cases while still preventing runaway loops
            my $dateindex = $loop_date->ymd;
            while ( $dateindex le $loop_end && $prevent_infinite_loop++ < 100 ) {
                # Skip if this spanning event was already processed for this date
                next if $AlreadySeen{$dateindex}{$Ticket->id}{$span_id};

                # Determine event type based on position in span
                my $event_type;
                if ($dateindex eq $span_start && $dateindex eq $span_end) {
                    $event_type = 'single';  # Single day event (start == end)
                } elsif ($dateindex eq $span_start) {
                    $event_type = 'start';
                } elsif ($dateindex eq $span_end) {
                    $event_type = 'end';
                } else {
                    $event_type = 'middle';
                }

                push @{ $Calendar{$dateindex} }, {
                    ticket => $Ticket,
                    event_type => $event_type,
                    span_id => $span_id,
                    date_field => $starts_field,
                    span_start => $span_start,
                    span_end => $span_end,
                };

                $AlreadySeen{$dateindex}{$Ticket->id}{$span_id} = 1;
                $loop_date->add( days => 1 );
                $dateindex = $loop_date->ymd;
            }
        }
    }

    return \%Calendar;
}

sub GetCalendarDateObj {
    my $date_field = shift;
    my $Ticket = shift;
    my $CurrentUser = shift;

    unless ($date_field) {
        $RT::Logger->debug("No date field provided. Using created date.");
        $date_field = 'Created';
    }

    if ($date_field =~ /^CF\./){
        my $cf = $date_field;
        $cf =~ s/^CF\.\{(.*)\}/$1/;
        my $CustomFieldObj = $Ticket->LoadCustomFieldByIdentifier($cf);
        unless ($CustomFieldObj->id) {
            RT->Logger->debug("$cf Custom Field is not available for this object.");
            return;
        }
        my $CFDateValue = $Ticket->FirstCustomFieldValue($cf);
        return unless $CFDateValue;
        my $CustomFieldObjType = $CustomFieldObj->Type;
        my $DateObj            = RT::Date->new($CurrentUser);
        if ( $CustomFieldObjType eq 'Date' ) {
            $DateObj->Set(
                Format   => 'unknown',
                Value    => $CFDateValue,
            );
        } else {
            $DateObj->Set( Format => 'ISO', Value => $CFDateValue );
        }
        return $DateObj;
    } else {
        my $DateObj = $date_field . "Obj";
        return $Ticket->$DateObj;
    }
}


RT::Base->_ImportOverlays();

1;
