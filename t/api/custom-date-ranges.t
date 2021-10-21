use warnings;
use strict;
use Test::MockTime qw( :all );
use RT::Test;

set_fixed_time('2016-01-01T00:00:00Z');

my $cf = RT::Test->load_or_create_custom_field(
    Name => 'Beta Date',
    Type => 'DateTime',
    MaxValues => 1,
    LookupType => RT::Ticket->CustomFieldLookupType,
    Queue => 'General',
);
ok($cf && $cf->Id, 'created Beta Date CF');

my $t = RT::Test->create_ticket(
    Queue       => 'General',
    Status      => 'resolved',
    Created     => '2015-12-10 00:00:00',
    Starts      => '2015-12-13 00:00:00',
    Started     => '2015-12-12 12:00:00',
    Due         => '2015-12-20 00:00:00',
    Resolved    => '2015-12-15 18:00:00',
);

# see t/customfields/datetime.t for timezone issues
$t->AddCustomFieldValue(Field => 'Beta Date', Value => '2015-12-13 19:00:00');
is($t->FirstCustomFieldValue('Beta Date'), '2015-12-14 00:00:00');

my @tests = (
    'Starts - Created' => '3 days',
    'Created   -     Starts' => '3 days prior',
    'Started - Created' => '3 days', # uses only the most significant unit
    'Resolved - Due' => '4 days prior',
    'Due - Resolved' => '4 days',
    'Due - Told' => undef, # told is unset
    'now - LastContact' => undef, # told is unset
    'now - LastUpdated' => '0 seconds',
    'Due - CF.{Beta Date}' => '6 days',
    'now - CF.{Beta Date}' => '3 weeks',
    'CF.{Beta Date} - now' => '3 weeks prior',
);

while (my ($spec, $expected) = splice @tests, 0, 2) {
    is($t->CustomDateRange(test => $spec), $expected, $spec);
}

is($t->CustomDateRange(test => {
    value => 'Resolved - Created',
    format => sub {
        my ($seconds, $end, $start, $ticket) = @_;
        join '/', $seconds, $end->Unix, $start->Unix, $ticket->Id;
    },
}), '496800/1450202400/1449705600/1', 'format');

diag 'test business time' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(
        ServiceAgreements => (
            Default => '2h',
            Levels  => { '2h' => { Response => 2 * 60, Timezone => 'UTC' }, },
        )
    );
    RT->Config->Set(
        ServiceBusinessHours => (
            'Default' => {
                1 => { Name => 'Monday',    Start => '9:00', End => '18:00' },
                2 => { Name => 'Tuesday',   Start => '9:00', End => '18:00' },
                3 => { Name => 'Wednesday', Start => '9:00', End => '18:00' },
                4 => { Name => 'Thursday',  Start => '9:00', End => '18:00' },
                5 => { Name => 'Friday',    Start => '9:00', End => '18:00' },
            },
        )
    );

    ok( $t->QueueObj->SetSLADisabled(0), 'Enabled SLA' );
    ok( $t->SetSLA('2h'), 'Set sla to 2h' );

    # from 2015-12-10 00:00:00 to 2015-12-15 18:00:00, there are 4 work days
    is( $t->CustomDateRange(
            test => {
                value         => 'Resolved - Created',
                business_time => 1,
            }
        ),
        '36 hours',
        'Business time of Resolved - Created'
      );
}
