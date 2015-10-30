use strict;
use warnings;

use Test::MockTime qw( :all );
use RT::Test tests => undef;

# we assume the RT's Timezone is UTC now, need a smart way to get over that.
$ENV{'TZ'} = 'GMT';
RT->Config->Set( Timezone => 'GMT' );

diag 'check business hours' if $ENV{'TEST_VERBOSE'};
{

    no warnings 'once';
    %RT::ServiceAgreements = (
        Default => 'Sunday',
        Levels  => {
            Sunday => {
                Resolve       => { BusinessMinutes => 60 },
                BusinessHours => 'Sunday',
            },
            Monday => {
                Resolve       => { BusinessMinutes => 60 },
            },
        },
    );

    %RT::ServiceBusinessHours = (
        Sunday => {
            0 => {
                Name  => 'Sunday',
                Start => '9:00',
                End   => '17:00'
            }
        },
        Default => {
            1 => {
                Name  => 'Monday',
                Start => '9:00',
                End   => '17:00'
            },
        },
    );

    set_fixed_time('2007-01-01T00:00:00Z');

    my $ticket = RT::Ticket->new($RT::SystemUser);
    my ($id) = $ticket->Create( Queue => 'General', Subject => 'xxx' );
    ok( $id, "created ticket #$id" );

    is( $ticket->SLA, 'Sunday', 'default sla' );

    my $start = $ticket->StartsObj->Unix;
    my $due = $ticket->DueObj->Unix;
    is( $start, 1168160400, 'Start date is 2007-01-07T09:00:00Z' );
    is( $due, 1168164000, 'Due date is 2007-01-07T10:00:00Z' );

    $ticket->SetSLA( 'Monday' );
    is( $ticket->SLA, 'Monday', 'new sla' );
    $due = $ticket->DueObj->Unix;
    is( $due, 1167645600, 'Due date is 2007-01-01T10:00:00Z' );
}

done_testing();
