
use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
use Test::MockTime 'set_fixed_time';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my $cf = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue->id, Type => 'Date' );
my $cfid = $cf->id;


set_fixed_time("2019-04-12T00:00:00Z");

my @tickets = RT::Test->create_tickets(
    { Queue   => $queue->Name },
    { Subject => 'Past date ticket', "CustomField-$cfid" => '2019-04-01' },
    { Subject => 'Future date ticket', "CustomField-$cfid" => '2020-01-01' },
);

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf < 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[0]->id, 'Found the past ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf > 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the future ticket' );

my $alice = RT::Test->load_or_create_user( Name => 'alice' );
$alice->PrincipalObj->GrantRight( Object => $queue, Right => 'ShowTicket' );

my $current_alice = RT::CurrentUser->new( RT->SystemUser );
$current_alice->Load('alice');

$tickets = RT::Tickets->new($current_alice);
$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf < 'today'});
TODO: {
    local $TODO = 'Do not filter by cfs user lacks SeeCustomField';
    is( $tickets->Count,                     2, 'Found 2 tickets' );
    is( scalar @{ $tickets->ItemsArrayRef }, 2, 'Found 2 tickets' );
}

$alice->PrincipalObj->GrantRight( Object => $queue, Right => 'SeeCustomField' );
$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf < 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[0]->id, 'Found the past ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf > 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the future ticket' );

$tickets->FromSQL(qq{Queue = 'General' AND CF.$cfid < 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[0]->id, 'Found the past ticket' );

$tickets->FromSQL(qq{Queue = 'General' AND CF.$cfid > 'today'});
is( $tickets->Count, 1, 'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the future ticket' );

done_testing;
