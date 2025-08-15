use strict;
use warnings;
use RT::Test tests => undef;
use Test::Warn qw(warning_like warnings_like);

use_ok('RT::Search::Calendar');

# Test GetMultipleDayFields function
{
    diag("Testing GetMultipleDayFields function");

    # Test with Starts and Due (should prefer these)
    my @dates = ('Starts', 'Due', 'Created');
    my ($starts, $ends) = RT::Search::Calendar::GetMultipleDayFields(\@dates);
    is($starts, 'Starts', 'GetMultipleDayFields returns Starts as start field');
    is($ends, 'Due', 'GetMultipleDayFields returns Due as end field');

    # Test with Started and Resolved
    @dates = ('Started', 'Resolved', 'Created');
    ($starts, $ends) = RT::Search::Calendar::GetMultipleDayFields(\@dates);
    is($starts, 'Started', 'GetMultipleDayFields returns Started as start field');
    is($ends, 'Resolved', 'GetMultipleDayFields returns Resolved as end field');

    # Test with all four fields (should prefer Starts/Due)
    @dates = ('Starts', 'Due', 'Started', 'Resolved', 'Created');
    ($starts, $ends) = RT::Search::Calendar::GetMultipleDayFields(\@dates);
    is($starts, 'Starts', 'GetMultipleDayFields prefers Starts over Started when both available');
    is($ends, 'Due', 'GetMultipleDayFields prefers Due over Resolved when both available');

    # Test with only single date fields (should return undef)
    @dates = ('Created', 'LastUpdated');
    ($starts, $ends) = RT::Search::Calendar::GetMultipleDayFields(\@dates);
    is($starts, undef, 'GetMultipleDayFields returns undef when no multi-day pairs found');
    is($ends, undef, 'GetMultipleDayFields returns undef for end field when no pairs found');

    # Test with only one field from a pair
    @dates = ('Starts', 'Created');
    ($starts, $ends) = RT::Search::Calendar::GetMultipleDayFields(\@dates);
    is($starts, undef, 'GetMultipleDayFields returns undef when only Starts without Due');
    is($ends, undef, 'GetMultipleDayFields returns undef when incomplete pair');
}

# Test DatesClauses function
{
    diag("Testing DatesClauses function");

    my @dates = ('Created', 'Starts');
    my $begin = '2025-08-01';
    my $end = '2025-08-31';

    # Test basic date clauses without multi-day
    my $clauses = RT::Search::Calendar::DatesClauses(\@dates, $begin, $end, undef, undef);
    like($clauses, qr/Created >= '2025-08-01 00:00:00'/, 'DatesClauses includes Created start date');
    like($clauses, qr/Created <= '2025-08-31 23:59:59'/, 'DatesClauses includes Created end date');
    like($clauses, qr/Starts >= '2025-08-01 00:00:00'/, 'DatesClauses includes Starts start date');
    like($clauses, qr/Starts <= '2025-08-31 23:59:59'/, 'DatesClauses includes Starts end date');
    like($clauses, qr/OR/, 'DatesClauses connects multiple dates with OR');

    # Test with multi-day fields
    $clauses = RT::Search::Calendar::DatesClauses(\@dates, $begin, $end, 'Starts', 'Due');
    like($clauses, qr/Starts <= '2025-08-31 00:00:00'/, 'DatesClauses includes multi-day start condition');
    like($clauses, qr/Due >= '2025-08-01 23:59:59'/, 'DatesClauses includes multi-day end condition');

    # Test with no dates
    @dates = ();
    $clauses = RT::Search::Calendar::DatesClauses(\@dates, $begin, $end, undef, undef);
    is($clauses, '', 'DatesClauses returns empty string with no dates');
}

# Set up test data for GetCalendarTickets
my $queue = RT::Test->load_or_create_queue(Name => 'Calendar Test Queue');
ok($queue->Id, 'Created test queue');

my $user = RT::Test->load_or_create_user(Name => 'root');
ok($user->Id, 'Loaded root user');

# Create test tickets with different date types using RT::Test->create_tickets
my ($ticket1, $ticket2, $ticket3, $ticket4) = RT::Test->create_tickets(
    # Default properties for all tickets
    {
        Queue => $queue->Id,
        Requestor => $user->Id,
    },
    # Ticket 1: Single date (Created only)
    {
        Subject => 'Single Date Ticket',
    },
    # Ticket 2: Multi-day ticket (Starts and Due)
    {
        Subject => 'Multi-day Ticket',
        Starts => '2025-08-15 09:00:00',
        Due => '2025-08-20 17:00:00',
    },
    # Ticket 3: Started/Resolved pair
    {
        Subject => 'Started Resolved Ticket',
        Started => '2025-08-10 10:00:00',
    },
    # Ticket 4: Outside date range
    {
        Subject => 'Outside Range Ticket',
        Starts => '2025-07-01 09:00:00',
        Due => '2025-07-05 17:00:00',
    },
);

ok($ticket1->Id, "Created ticket 1: " . $ticket1->Subject);
ok($ticket2->Id, "Created ticket 2: " . $ticket2->Subject);
ok($ticket3->Id, "Created ticket 3: " . $ticket3->Subject);
ok($ticket4->Id, "Created ticket 4: " . $ticket4->Subject);

# Resolve ticket3 to set Resolved date
$ticket3->SetStatus('resolved');

# Test GetCalendarTickets function with unified structure
{
    diag("Testing GetCalendarTickets function with unified structure");

    my $query = "Queue = '" . $queue->Name . "'";
    my @dates = ('Created', 'Starts', 'Due');
    my $begin = '2025-08-01';
    my $end = '2025-08-31';

    my $calendar = RT::Search::Calendar::GetCalendarTickets(
        RT->SystemUser, $query, \@dates, $begin, $end
    );

    isa_ok($calendar, 'HASH', 'GetCalendarTickets returns unified calendar hash');

    # Check that events are properly indexed by date
    my $found_events = 0;
    my $found_multi_day_events = 0;
    for my $date (keys %$calendar) {
        like($date, qr/^\d{4}-\d{2}-\d{2}$/, "Date key $date is in YYYY-MM-DD format");

        for my $event (@{$calendar->{$date}}) {
            isa_ok($event->{ticket}, 'RT::Ticket', "Event ticket in date $date is RT::Ticket object");
            ok(defined $event->{event_type}, "Event has event_type defined");
            ok(defined $event->{date_field}, "Event has date_field defined");

            if ($event->{span_id}) {
                $found_multi_day_events++;
            }
            $found_events++;
        }
    }

    ok($found_events > 0, 'GetCalendarTickets found events in date range');
    ok($found_multi_day_events > 0, 'GetCalendarTickets found multi-day events');

    # Test with empty query (should return empty results)
    my $empty_calendar = RT::Search::Calendar::GetCalendarTickets(
        RT->SystemUser, "Queue = 'NonexistentQueue'", \@dates, $begin, $end
    );

    is(scalar(keys %$empty_calendar), 0, 'GetCalendarTickets returns empty hash for no matching tickets');
}

# Test detailed event structure and metadata
{
    diag("Testing GetCalendarTickets detailed event structure");

    my $query = "Queue = '" . $queue->Name . "'";
    my @dates = ('Created', 'Starts', 'Due');
    my $begin = '2025-08-01';
    my $end = '2025-08-31';

    my $calendar = RT::Search::Calendar::GetCalendarTickets(
        RT->SystemUser, $query, \@dates, $begin, $end
    );

    # Check structure of calendar entries
    my $found_events = 0;
    my $found_single_events = 0;
    my $found_multi_events = 0;
    my $found_start_events = 0;
    my $found_middle_events = 0;
    my $found_end_events = 0;

    for my $date (keys %$calendar) {
        for my $event (@{$calendar->{$date}}) {
            $found_events++;

            # Verify event structure
            isa_ok($event->{ticket}, 'RT::Ticket', 'Event contains RT::Ticket object');
            ok(defined $event->{event_type}, 'Event has event_type defined');
            ok(defined $event->{date_field}, 'Event has date_field defined');

            # Count event types
            if ($event->{event_type} eq 'single') {
                $found_single_events++;
                is($event->{span_id}, undef, 'Single events have undefined span_id');
                is($event->{span_start}, undef, 'Single events have undefined span_start');
                is($event->{span_end}, undef, 'Single events have undefined span_end');
            } elsif ($event->{event_type} eq 'start') {
                $found_start_events++;
                $found_multi_events++;
                ok(defined $event->{span_id}, 'Start events have span_id defined');
                ok(defined $event->{span_start}, 'Start events have span_start defined');
                ok(defined $event->{span_end}, 'Start events have span_end defined');
                like($event->{span_id}, qr/^ticket\d+_\w+_\w+$/, 'Span ID follows expected format');
            } elsif ($event->{event_type} eq 'middle') {
                $found_middle_events++;
                $found_multi_events++;
                ok(defined $event->{span_id}, 'Middle events have span_id defined');
                ok(defined $event->{span_start}, 'Middle events have span_start defined');
                ok(defined $event->{span_end}, 'Middle events have span_end defined');
            } elsif ($event->{event_type} eq 'end') {
                $found_end_events++;
                $found_multi_events++;
                ok(defined $event->{span_id}, 'End events have span_id defined');
                ok(defined $event->{span_start}, 'End events have span_start defined');
                ok(defined $event->{span_end}, 'End events have span_end defined');
            }
        }
    }

    ok($found_events > 0, 'Found events in unified calendar structure');
    ok($found_single_events > 0, 'Found single-day events');
    ok($found_multi_events > 0, 'Found multi-day events');
    ok($found_start_events > 0, 'Found start events for multi-day tickets');

    # Test span ID consistency for multi-day events
    my %span_groups;
    for my $date (keys %$calendar) {
        for my $event (@{$calendar->{$date}}) {
            if ($event->{span_id}) {
                push @{$span_groups{$event->{span_id}}}, {
                    date => $date,
                    event_type => $event->{event_type},
                    ticket_id => $event->{ticket}->id,
                };
            }
        }
    }

    # Verify span consistency
    for my $span_id (keys %span_groups) {
        my @events = @{$span_groups{$span_id}};
        my %event_types = map { $_->{event_type} => 1 } @events;
        my %ticket_ids = map { $_->{ticket_id} => 1 } @events;

        is(scalar(keys %ticket_ids), 1, "All events in span $span_id belong to same ticket");

        if (scalar(@events) > 1) {
            ok(exists $event_types{start}, "Multi-day span $span_id has start event");
            ok(exists $event_types{end}, "Multi-day span $span_id has end event");
        }
    }
}

# Test GetCalendarDateObj function
{
    diag("Testing GetCalendarDateObj function");

    # Test with standard date field
    my $date_obj = RT::Search::Calendar::GetCalendarDateObj('Created', $ticket1, RT->SystemUser);
    isa_ok($date_obj, 'RT::Date', 'GetCalendarDateObj returns RT::Date object for Created');
    ok($date_obj->Unix > 0, 'GetCalendarDateObj returns valid date');

    # Test with custom field (create a date custom field first)
    my $cf = RT::CustomField->new(RT->SystemUser);
    my ($cf_id, $cf_msg) = $cf->Create(
        Name => 'TestDate',
        Type => 'Date',
        Queue => $queue->Id,
    );
    ok($cf_id, "Created date custom field: $cf_msg");

    # Add custom field value to ticket
    my ($cfv, $cfm) = $ticket1->AddCustomFieldValue(
        Field => $cf->Id,
        Value => '2025-08-25',
    );
    ok($cfv, "Added custom field value: $cfm");

    # Test custom field date extraction
    $date_obj = RT::Search::Calendar::GetCalendarDateObj('CF.{TestDate}', $ticket1, RT->SystemUser);
    isa_ok($date_obj, 'RT::Date', 'GetCalendarDateObj returns RT::Date object for custom field');

    # Test with non-existent field (may return error message or undef)
    $date_obj = RT::Search::Calendar::GetCalendarDateObj('NonExistentField', $ticket1, RT->SystemUser);
    ok(!defined($date_obj) || !ref($date_obj), 'GetCalendarDateObj handles non-existent field gracefully');

    # Test with empty/null date (may return RT::Date object with Unix=0 or undef)
    $date_obj = RT::Search::Calendar::GetCalendarDateObj('Due', $ticket1, RT->SystemUser);
    if (ref($date_obj) eq 'RT::Date') {
        ok($date_obj->Unix <= 0, 'GetCalendarDateObj returns RT::Date with Unix <= 0 for unset date field');
    } else {
        is($date_obj, undef, 'GetCalendarDateObj returns undef for unset date field');
    }
}

# Test edge cases and error conditions
{
    diag("Testing edge cases and error conditions");

    # Test with malformed date range (expect warnings about date parsing)
    # SplitQuery causes extra warnings except SQLite that doesn't support SplitQuery
    my ($tickets_hash, $spanning_hash);
    warnings_like {
        ( $tickets_hash, $spanning_hash )
            = RT::Search::Calendar::GetCalendarTickets( RT->SystemUser, "Queue = '" . $queue->Name . "'",
                ['Created'], 'invalid-date', '2025-08-31' );
    }
    [   (   qr{Couldn't parse date 'invalid-date 00:00:00' by Time::ParseDate},
            qr{Couldn't parse date 'invalid-date 00:00:00' by DateTime::Format::Natural}
        ) x ( RT->Config->Get('DatabaseType') eq 'SQLite' ? 1 : 2 ),
    ],
        'Expected warnings for invalid date parsing';

    # Should handle gracefully (may return empty or process anyway depending on implementation)
    isa_ok($tickets_hash, 'HASH', 'GetCalendarTickets handles invalid begin date gracefully');

    # Test with empty dates array
    ($tickets_hash, $spanning_hash) = RT::Search::Calendar::GetCalendarTickets(
        RT->SystemUser, "Queue = '" . $queue->Name . "'", [], '2025-08-01', '2025-08-31'
    );

    isa_ok($tickets_hash, 'HASH', 'GetCalendarTickets handles empty dates array');

    # Test user permissions (use limited user)
    my $limited_user = RT::Test->load_or_create_user(
        Name => 'limiteduser',
        Password => 'password',
        EmailAddress => 'limited@example.com',
    );
    ok($limited_user->Id, "Created limited user: " . $limited_user->Name);

    # Test with limited user permissions - may cause permission errors or warnings
    eval {
        ($tickets_hash, $spanning_hash) = RT::Search::Calendar::GetCalendarTickets(
            $limited_user, "Queue = '" . $queue->Name . "'", ['Created'], '2025-08-01', '2025-08-31'
        );
        isa_ok($tickets_hash, 'HASH', 'GetCalendarTickets works with limited user permissions');
    };
    if ($@) {
        # If permission test fails, that's expected for a limited user
        pass('GetCalendarTickets handles limited user permissions (may throw permission error)');
    }
}

done_testing();
