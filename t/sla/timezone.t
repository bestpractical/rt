use strict;
use warnings;

use Test::MockTime qw( :all );
use RT::Test tests => undef;

my $ru_queue = RT::Test->load_or_create_queue( Name => 'RU', SLADisabled => 0 );
ok $ru_queue && $ru_queue->id, 'created RU queue';

my $us_queue = RT::Test->load_or_create_queue( Name => 'US', SLADisabled => 0 );
ok $us_queue && $ru_queue->id, 'created US queue';

RT->Config->Set(ServiceAgreements => (
    Default => 2,
    QueueDefault => {
        RU => { Timezone => 'Europe/Moscow' },
        US => { Timezone => 'America/New_York' },
    },
    Levels  => {
        '2' => { Resolve => { BusinessMinutes => 60 * 2 } },
    },
));

set_fixed_time('2007-01-01T22:00:00Z');

diag 'check dates in US queue' if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Ticket->new($RT::SystemUser);
    my ($id) = $ticket->Create( Queue => 'US', Subject => 'xxx' );
    ok( $id, "created ticket #$id" );

    my $start = $ticket->StartsObj->ISO( Timezone => 'utc' );
    is( $start, '2007-01-01 22:00:00', 'Start date is right' );
    my $due = $ticket->DueObj->ISO( Timezone => 'utc' );
    is( $due, '2007-01-02 15:00:00', 'Due date is right' );
}

diag 'check dates in RU queue' if $ENV{'TEST_VERBOSE'};
{
    my $ticket = RT::Ticket->new($RT::SystemUser);
    my ($id) = $ticket->Create( Queue => 'RU', Subject => 'xxx' );
    ok( $id, "created ticket #$id" );

    my $start = $ticket->StartsObj->ISO( Timezone => 'utc' );
    is( $start, '2007-01-02 06:00:00', 'Start date is right' );
    my $due = $ticket->DueObj->ISO( Timezone => 'utc' );
    is( $due, '2007-01-02 08:00:00', 'Due date is right' );
}

done_testing;
