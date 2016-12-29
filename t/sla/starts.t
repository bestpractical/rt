use strict;
use warnings;

use Test::MockTime qw( :all );
use RT::Test tests => undef;

RT::Test->load_or_create_queue( Name => 'General', SLADisabled => 0 );

# we assume the RT's Timezone is UTC now, need a smart way to get over that.
$ENV{'TZ'} = 'GMT';
RT->Config->Set( Timezone => 'GMT' );

my $bhours = RT::SLA->BusinessHours;

diag 'check Starts date' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(ServiceAgreements => (
        Default => 'standard',
        Levels  => {
            'standard' => {
                Response => 2 * 60,
                Resolve  => 7 * 60 * 24,
            },
        },
    ));
    RT->Config->Set(ServiceBusinessHours => (
        Default => {
            1 => {
                Name  => 'Monday',
                Start => '09:00',
                End   => '17:00'
            },
            2 => {
                Name  => 'Tuesday',
                Start => '09:00',
                End   => '17:00'
            },
        }
    ));

    my %time = (
        '2007-01-01T13:15:00Z' => 1167657300,    # 2007-01-01T13:15:00Z
        '2007-01-01T19:15:00Z' => 1167728400,    # 2007-01-02T09:00:00Z
        '2007-01-06T13:15:00Z' => 1168246800,    # 2007-01-08T09:00:00Z
    );

    for my $time ( keys %time ) {
        set_fixed_time($time);
        my $ticket = RT::Ticket->new($RT::SystemUser);
        my ($id) = $ticket->Create( Queue => 'General', Subject => 'xxx' );
        ok $id, "created ticket #$id";
        is $ticket->StartsObj->Unix, $time{$time}, 'Starts date is right';
    }

    restore_time();
}

diag 'check Starts date with StartImmediately enabled' if $ENV{'TEST_VERBOSE'};
{
    RT->Config->Set(ServiceAgreements => (
        Default => 'start immediately',
        Levels  => {
            'start immediately' => {
                StartImmediately => 1,
                Response         => 2 * 60,
                Resolve          => 7 * 60 * 24,
            },
        },
    ));
    my $time = time;

    my $ticket = RT::Ticket->new($RT::SystemUser);
    my ($id) = $ticket->Create( Queue => 'General', Subject => 'xxx' );
    ok $id, "created ticket #$id";

    my $starts = $ticket->StartsObj->Unix;
    ok $starts > 0, 'Starts date is set';
    is $starts, $ticket->CreatedObj->Unix, 'Starts is correct';
}

done_testing;
