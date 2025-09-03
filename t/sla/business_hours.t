use strict;
use warnings;

use Test::MockTime qw( :all );
use RT::Test tests => undef;

# we assume the RT's Timezone is UTC now, need a smart way to get over that.
$ENV{'TZ'} = 'GMT';
RT->Config->Set( Timezone => 'GMT' );

RT::Test->load_or_create_queue( Name => 'General', SLADisabled => 0 );
my $user_alice = RT::Test->load_or_create_user( Name => 'alice' );
my $user_root = RT::Test->load_or_create_user( Name => 'root' );
RT::Test->add_rights( { Principal => $user_alice, Right => [qw/ShowTicket CreateTicket SeeQueue ModifyTicket/] } );

diag 'check business hours' if $ENV{'TEST_VERBOSE'};
{

    RT->Config->Set(ServiceAgreements => (
        Default => 'Sunday',
        Levels  => {
            Sunday => {
                Resolve       => { BusinessMinutes => 60 },
                BusinessHours => 'Sunday',
            },
            Monday => {
                Response => {
                    BusinessMinutes  => 60,
                    IgnoreOnStatuses => ['resolved'],
                    ExcludeTimeOnIgnoredStatuses => 1,
                },
            },
        },
    ));

    RT->Config->Set(ServiceBusinessHours => (
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
    ));

    set_fixed_time('2007-01-01T00:00:00Z');

    my $ticket = RT::Ticket->new($user_alice);
    my ($id) = $ticket->Create( Queue => 'General', Subject => 'xxx', Requestor => 'alice' );
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

    my $ticket_root = RT::Ticket->new($user_root);
    $ticket_root->Load( $ticket->Id );
    $ticket_root->Correspond( Content => 'Staff replies' );
    is( $ticket_root->DueObj->Unix, 0, 'Due date is unset after staff replied' );

    set_fixed_time('2007-03-01T00:00:00Z');
    $ticket->Correspond( Content => 'Customer replies in 2 months' );
    is( $ticket->Due, '2007-03-05 10:00:00', 'Due date is 2007-03-05 10:00:00, got updated when customer replied' );

    set_fixed_time('2007-03-06T00:00:00Z');
    $ticket->Correspond( Content => 'Customer replies again' );
    is( $ticket->Due, '2007-03-05 10:00:00', 'Due date is the same after customer replied again' );

    my ( $ret, $msg ) = $ticket_root->SetStatus('resolved');
    ok( $ret, $msg );

    set_fixed_time('2007-05-01T00:00:00Z');
    $ticket->Correspond( Content => 'Customer replies in 2 months' );
    is( $ticket->Due, '2007-05-07 10:00:00', 'Due date is 2007-05-07 10:00:00, got reset after long time silence' );

    $ticket_root->Correspond( Content => 'Staff replies' );
    is( $ticket_root->DueObj->Unix, 0, 'Due date is unset after staff replied' );
}

diag 'check that RT warns about specifying Sunday as 7 rather than 0' if $ENV{'TEST_VERBOSE'};
{
    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, $_[0];
    };

    RT->Config->Set(ServiceBusinessHours => (
        Invalid => {
            7 => {
                Name  => 'Domingo',
                Start => '9:00',
                End   => '17:00'
            }
        },
    ));

    RT->Config->PostLoadCheck;

    is(@warnings, 1);
    like($warnings[0], qr/Config option %ServiceBusinessHours 'Invalid' erroneously specifies 'Domingo' as day 7; Sunday should be specified as day 0\./);
}

done_testing();
