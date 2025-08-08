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

sub DatesClauses {
    my ( $Dates, $begin, $end ) = @_;

    my $clauses = "";

    my @DateClauses = map {
        "($_ >= '" . $begin . " 00:00:00' AND $_ <= '" . $end . " 23:59:59')"
    } @$Dates;

    # All multiple days events are already covered on the query above
    # The following code works for covering events that start before and ends
    # after the selected period.
    # Start and end fields of the multiple days must also be present on the
    # format.
    my $multiple_days_events = RT->Config->Get('CalendarMultipleDaysEvents');
    for my $event ( keys %$multiple_days_events ) {
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
        push @DateClauses,
            "("
            . $multiple_days_events->{$event}{Starts}
            . " <= '"
            . $end
            . " 00:00:00' AND "
            . $multiple_days_events->{$event}{Ends}
            . " >= '"
            . $begin
            . " 23:59:59')";
    }

    $clauses .= " AND " . " ( " . join( " OR ", @DateClauses ) . " ) "
        if @DateClauses;

    return $clauses;
}

sub GetCalendarTickets {
    my ( $CurrentUser, $Query, $Dates, $begin, $end ) = @_;

    my $multiple_days_events = RT->Config->Get('CalendarMultipleDaysEvents');
    my @multiple_days_fields;
    for my $event ( keys %$multiple_days_events ) {
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
        next unless
            grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
        for my $type ( keys %{ $multiple_days_events->{$event} } ) {
            push @multiple_days_fields,
                $multiple_days_events->{$event}{$type};
        }
    }

    $Query .= DatesClauses( $Dates, $begin, $end )
        if $begin and $end;

    my $Tickets = RT::Tickets->new($CurrentUser);
    $Tickets->FromSQL($Query);
    $Tickets->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    my %Tickets;
    my %AlreadySeen;
    my %TicketsSpanningDays;
    my %TicketsSpanningDaysAlreadySeen;

    while ( my $Ticket = $Tickets->Next() ) {
        # How to find the LastContacted date ?
        # Find single day events fields
        for my $Date (@$Dates) {
            # $dateindex is the date to use as key in the Tickets Hash
            # in the YYYY-MM-DD format
            # Tickets are then groupd by date in the %Tickets hash
            my $dateindex_obj = GetCalendarDateObj( $Date, $Ticket, $CurrentUser );
            next unless $dateindex_obj;
            my $dateindex = $dateindex_obj->ISO( Time => 0, Timezone => 'user' );
            push @{ $Tickets{$dateindex } },
                $Ticket

                # if reminder, check it's refering to a ticket
                unless ( $Ticket->Type eq 'reminder'
                and not $Ticket->RefersTo->First )
                or $AlreadySeen{ $dateindex }
                {$Ticket}++;
        }

        # Find spanning days of multiple days events
        for my $event (sort keys %$multiple_days_events) {
            next unless
                grep { $_ eq $multiple_days_events->{$event}{'Starts'} } @$Dates;
            next unless
                grep { $_ eq $multiple_days_events->{$event}{'Ends'} } @$Dates;
            my $starts_field = $multiple_days_events->{$event}{'Starts'};
            my $ends_field   = $multiple_days_events->{$event}{'Ends'};
            my $starts_date  = GetCalendarDateObj( $starts_field, $Ticket, $CurrentUser );
            my $ends_date    = GetCalendarDateObj( $ends_field,   $Ticket, $CurrentUser );
            next unless $starts_date and $ends_date;
            # Loop through all days between start and end and add the ticket
            # to it
            my $current_date = RT::Date->new($CurrentUser);
            $current_date->Set(
                Format => 'unix',
                Value => $starts_date->Unix,
            );

            my $end_date = $ends_date->ISO( Time => 0, Timezone => 'user' );
            my $first_day = 1;
            # We want to prevent infinite loops if user for some reason
            # set a future date for year 3000 or something like that
            my $prevent_infinite_loop = 0;
            while ( ( $current_date->ISO( Time => 0, Timezone => 'user' ) le $end_date )
                && ( $prevent_infinite_loop++ < 10000 ) )
            {
                my $dateindex = $current_date->ISO( Time => 0, Timezone => 'user' );

                push @{ $TicketsSpanningDays{$dateindex} }, $Ticket->id
                    unless $first_day
                    || $TicketsSpanningDaysAlreadySeen{$dateindex}
                    {$Ticket}++;
                push @{ $Tickets{$dateindex } },
                    $Ticket
                    # if reminder, check it's refering to a ticket
                    unless ( $Ticket->Type eq 'reminder'
                    and not $Ticket->RefersTo->First )
                    or $AlreadySeen{ $dateindex }
                    {$Ticket}++;

                $current_date->AddDay();
                $first_day = 0;
            }
        }
    }
    if ( wantarray ) {
        return ( \%Tickets, \%TicketsSpanningDays );
    } else {
        return \%Tickets;
    }
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
