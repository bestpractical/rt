use strict;
use warnings;
use RT::Test tests => undef;
use Test::Deep;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "loaded the General queue" );

my %valid = (
    '0'     => 0,
    '-8'    => -8,
    '2'     => 2,
    '5.'    => 5,
    '5.5'   => 6,
    ' 15 '  => 15,
    '1,000' => 1000,
    '.5h'   => 30,
    '1.5h'  => 90,
    '2h'    => 120,
);
my @invalid = ( 'a', '3;4', '3+4' );

$m->goto_create_ticket( $queue );
for my $time ( @invalid ) {
    my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    $m->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { TimeEstimated => $number, $hour ? ( 'TimeEstimated-TimeUnits' => 'hours' ) : (), },
            button    => 'SubmitTicket',
        },
        "Submit time $time",
    );
    $m->text_contains( 'Invalid TimeEstimated: it should be a number' );
    $m->text_unlike( qr/Ticket \d+ created in queue/ );
}

for my $time ( sort keys %valid ) {
    my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    $m->goto_create_ticket( $queue );
    $m->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { TimeEstimated => $number, $hour ? ( 'TimeEstimated-TimeUnits' => 'hours' ) : (), },
            button    => 'SubmitTicket',
        },
        "Submit time $time",
    );
    $m->text_lacks( 'Invalid TimeEstimated: it should be a number' );
    $m->text_like( qr/Ticket \d+ created in queue/ );
    my $ticket = RT::Test->last_ticket;
    is( $ticket->TimeEstimated, $valid{$time}, 'TimeEstimated is set' );
}

my $ticket = RT::Test->last_ticket;

for my $page ( qw/ModifyAll/ ) {
    $m->goto_ticket( $ticket->id, $page );

    for my $time ( @invalid ) {
        my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

        $m->submit_form_ok(
            {
                form_name => "Ticket$page",
                fields => { map { $_ => $number, $hour ? ( "$_-TimeUnits" => 'hours' ) : () } qw/TimeLeft TimeWorked/ },
            },
            "Submit time $time",
        );

        $ticket->Load( $ticket->id );
        for my $field ( qw/TimeLeft TimeWorked/ ) {
            $m->text_contains( "Invalid $field: it should be a number" );
            ok( !$ticket->$field, "$field is not updated" );
        }
    }

    for my $time ( sort keys %valid ) {
        my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

        $m->submit_form_ok(
            {
                form_name => "Ticket$page",
                fields => { map { $_ => $number, $hour ? ( "$_-TimeUnits" => 'hours' ) : () } qw/TimeLeft TimeWorked/ },
            },
            "Submit time $time",
        );
        $ticket->Load( $ticket->id );

        for my $field ( qw/TimeLeft TimeWorked/ ) {
            $m->text_lacks( "Invalid $field: it should be a number" );
            if ( $field eq 'TimeLeft' ) {
                $m->text_like( qr/$field changed/ );
            }
            else {
                $m->text_like( qr/worked -?[\d.]+ (?:minute|hour)|adjusted time worked/i );
            }
            is( $ticket->$field, $valid{$time}, "$field is updated" );
        }
    }

    for my $field ( qw/TimeLeft TimeWorked/ ) {
        my $set_method = "Set$field";
        my ( $ret, $msg ) = $ticket->$set_method( 0 );
        ok( $ret, 'Reset $field to 0' );
    }
}

my $url = $m->rt_base_url;
$ticket = RT::Test->last_ticket;

diag 'Test sending time values to Helpers/TicketUpdate';

for my $time ( @invalid ) {
    my $hour = 0;
    my $number;
    ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    my $args = { map { $_ => $number, $hour ? ( "$_-TimeUnits" => 'hours' ) : ( "$_-TimeUnits" => 'minutes' ) } qw/TimeLeft TimeWorked TimeEstimated/ };
    $args->{id} = $ticket->Id;

    my $req = $m->post(
        $url . "Helpers/TicketUpdate",
        $args,
    );

    is( $req->code, 200, 'Submitted invalid time values' );
    my $results = JSON::from_json($req->content);

#    for my $field ( qw/TimeWorked TimeEstimated TimeLeft/ ) {
#        is( shift @{$results->{actions}}, "Invalid $field: it should be a number", "Caught invalid $field");
#    }

    cmp_deeply( [
        "Invalid TimeWorked: it should be a number",
        "Invalid TimeEstimated: it should be a number",
        "Invalid TimeLeft: it should be a number" ],
        set(@{$results->{actions}}), "Caught invalid values" );

}

=pod

for my $time ( sort keys %valid ) {
    my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    $m->submit_form_ok(
        {
            form_name => "Ticket$page",
            fields => { map { $_ => $number, $hour ? ( "$_-TimeUnits" => 'hours' ) : () } qw/TimeLeft TimeWorked/ },
        },
        "Submit time $time",
    );
    $ticket->Load( $ticket->id );

    for my $field ( qw/TimeLeft TimeWorked/ ) {
        $m->text_lacks( "Invalid $field: it should be a number" );
        if ( $field eq 'TimeLeft' ) {
            $m->text_like( qr/$field changed/ );
        }
        else {
            $m->text_like( qr/worked -?[\d.]+ (?:minute|hour)|adjusted time worked/i );
        }
        is( $ticket->$field, $valid{$time}, "$field is updated" );
    }
}

for my $field ( qw/TimeLeft TimeWorked/ ) {
    my $set_method = "Set$field";
    my ( $ret, $msg ) = $ticket->$set_method( 0 );
    ok( $ret, 'Reset $field to 0' );
}


=cut

$m->goto_ticket( $ticket->id, 'Update' );

for my $time ( @invalid ) {
    my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    $m->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => { UpdateTimeWorked => $number, $hour ? ( 'UpdateTimeWorked-TimeUnits' => 'hours' ) : (), },
            button    => 'SubmitTicket',
        },
        "Submit time $time",
    );
    $m->text_contains( 'Invalid UpdateTimeWorked: it should be a number' );
    $ticket->Load( $ticket->id );
    ok( !$ticket->TimeWorked, 'TimeWorked is not updated' );
}

my $time_worked = $ticket->TimeWorked;
for my $time ( sort keys %valid ) {
    my ( $number, $hour ) = $time =~ /^(.+?)(h?)$/;

    $m->goto_ticket( $ticket->id, 'Update' );
    $m->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => { UpdateTimeWorked => $number, $hour ? ( 'UpdateTimeWorked-TimeUnits' => 'hours' ) : (), },
            button    => 'SubmitTicket',
        },
        "Submit time $time",
    );
    $m->text_lacks( 'Invalid UpdateTimeWorked: it should be a number' );
    $ticket->Load( $ticket->id );
    is( $ticket->TimeWorked, $time_worked + $valid{$time}, 'TimeWorked is updated' );
    $time_worked = $ticket->TimeWorked;
}

done_testing;
