use warnings;
use strict;
use RT::Test;

RT->Config->Set(
    ServiceAgreements => (
        Default => '2h',
        Levels  => {
            '2h' => { Response => 2 * 60, BusinessHours => 'Default',     Timezone => 'UTC' },
            '4h' => { Response => 4 * 60, BusinessHours => 'Just Monday', Timezone => 'UTC' },
        },
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
        'Just Monday' => {
            1 => { Name => 'Monday', Start => '9:00', End => '18:00' },
        },
    )
);

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->SetSLADisabled(0), 'Enabled SLA' );

RT::Test->create_ticket(
    Queue    => 'General',
    Status   => 'resolved',
    Created  => '2021-12-10 00:00:00',
    Resolved => '2021-12-15 18:00:00',
    SLA      => '2h',
) for 1 .. 3;


RT::Test->create_ticket(
    Queue    => 'General',
    Status   => 'resolved',
    Created  => '2021-12-10 00:00:00',
    Resolved => '2021-12-30 18:00:00',
    SLA      => '4h',
) for 1 .. 2;

RT::Test->create_ticket(
    Queue    => 'General',
    Status   => 'resolved',
    Created  => '2021-12-05 00:00:00',
    Resolved => '2021-12-30 18:00:00',
    SLA      => '4h',
);


my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

diag "Test Date Ranges GroupBy with business hours in SLA";

$m->get_ok("/Search/Chart.html?Query=id>0");
$m->form_with_fields("GroupBy");
$m->select( 'GroupBy', 'Created to Resolved(Business Hours).Default' );
$m->submit_form_ok;

my @monday_rows = $m->dom->find('span.business_hours_just_monday')->each;
is( @monday_rows, 2, '2 rows with Just Monday BH' );

is( $monday_rows[0]->text, '27 hours', 'GroupBy Just Monday 1st row label' );
$m->text_like( qr/27 hours\s*2/, 'GroupBy Just Monday 1st row ticket count' );

is( $monday_rows[1]->text, '36 hours', 'GroupBy Just Monday 2nd row label' );
$m->text_like( qr/36 hours\s*1/, 'GroupBy Just Monday 2nd row ticket count' );

my @default_rows = $m->dom->find('span.business_hours_default')->each;
is( @default_rows, 1, '1 row with Default BH' );
is( $default_rows[0]->text, '36 hours', 'GroupBy Default row label' );
$m->text_like( qr/36 hours\s*3/, 'GroupBy Default ticket count' );


diag "Test custom date ranges GroupBy with business hours in SLA";

$m->get_ok('/Prefs/CustomDateRanges.html');
$m->form_name('CustomDateRanges');

$m->select( 'from',          'Created' );
$m->select( 'to',            'Resolved' );
$m->select( 'business_time', 1 );

$m->submit_form_ok( { fields => { name => 'Resolution Time' }, button => 'Save' } );
$m->text_contains('Created Resolution Time');

$m->get_ok("/Search/Chart.html?Query=id>0");
$m->form_with_fields("GroupBy");
$m->select( 'GroupBy', 'Resolution Time.Hour' );
$m->submit_form_ok;

@monday_rows = $m->dom->find('span.business_hours_just_monday')->each;
is( @monday_rows,          2,          '2 rows with Just Monday BH' );
is( $monday_rows[0]->text, '27 hours', 'GroupBy Just Monday 1st row label' );
$m->text_like( qr/27 hours\s*2/, 'GroupBy Just Monday 1st row ticket count' );

is( $monday_rows[1]->text, '36 hours', 'GroupBy Just Monday 2nd row label' );
$m->text_like( qr/36 hours\s*1/, 'GroupBy Just Monday 2nd row ticket count' );

@default_rows = $m->dom->find('span.business_hours_default')->each;
is( @default_rows, 1, '1 row with Default BH' );
is( $default_rows[0]->text, '36 hours', 'GroupBy Default row label' );


diag "Test custom date ranges with specified business hours";
$m->get_ok('/Prefs/CustomDateRanges.html');
$m->form_name('CustomDateRanges');
$m->select( '0-business_time', 'Just Monday' );

$m->submit_form_ok( { button => 'Save' } );
$m->text_contains('Updated Resolution Time');

$m->get_ok("/Search/Chart.html?Query=id>0");
$m->form_with_fields("GroupBy");
$m->select( 'GroupBy', 'Resolution Time.Hour' );
$m->submit_form_ok;
@monday_rows = $m->dom->find('span.business_hours_just_monday')->each;
is( @monday_rows,          3,         '3 rows with Just Monday BH' );
is( $monday_rows[0]->text, '9 hours', 'GroupBy Just Monday 1st row label' );
$m->text_like( qr/9 hours\s*3/, 'GroupBy Just Monday 1st row ticket count' );

is( $monday_rows[1]->text, '27 hours', 'GroupBy Just Monday 2nd row label' );
$m->text_like( qr/27 hours\s*2/, 'GroupBy Just Monday 2nd row ticket count' );

is( $monday_rows[2]->text, '36 hours', 'GroupBy Just Monday 3rd row label' );
$m->text_like( qr/36 hours\s*1/, 'GroupBy Just Monday 3rd row ticket count' );


diag "Test custom date ranges Calculation";
# Can't use form_with_fields('GroupBy') as SaveSearch form that also has the field, which will warn.
$m->form_number(3);
$m->select( 'ChartFunction', 'SUM(Resolution Time)' );

$m->submit_form_ok;

@monday_rows = $m->dom->find('span.business_hours_just_monday')->each;
is( @monday_rows,          6,         '6 cells with Just Monday BH' );
is( $monday_rows[0]->text, '9 hours', 'GroupBy Just Monday 1st row label' );
is( $monday_rows[1]->text, '27h',     'GroupBy Just Monday 1st row value' );

is( $monday_rows[2]->text, '27 hours', 'GroupBy Just Monday 2nd row label' );
is( $monday_rows[3]->text, '54h',      'GroupBy Just Monday 2nd row value' );

is( $monday_rows[4]->text, '36 hours', 'GroupBy Just Monday 3rd row label' );
is( $monday_rows[5]->text, '36h',      'GroupBy Just Monday 3rd row value' );


diag "Test custom date ranges Calculation with normal group by";
$m->form_number(3);
$m->select( 'GroupBy', 'Status' );

$m->submit_form_ok;

@monday_rows = $m->dom->find('span.business_hours_just_monday')->each;
is( @monday_rows,          1,      '1 cell with Just Monday BH' );
is( $monday_rows[0]->text, '117h', 'GroupBy Just Monday row value' );

done_testing;
