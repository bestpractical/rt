use strict;
use warnings;
use RT::Test tests => undef, config => 'Set($DisplayTotalTimeWorked, 1);';

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "loaded the General queue" );

my ( $child1, $child2 ) = RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'child ticket 1', },
    { Subject => 'child ticket 2', },
);

my ( $child1_id, $child2_id ) = ( $child1->id, $child2->id );
my $parent_id; # id of the parent ticket

diag "add ticket links for timeworked tests"; {
    my $ticket = RT::Test->create_ticket(
        Queue   => 'General',
        Subject => "timeworked parent",
    );
    my $id = $parent_id = $ticket->id;

    $m->goto_ticket($id);
    $m->follow_link_ok( { id => 'page-jumbo' }, "Followed link to Modify All" );

    ok( $m->form_with_fields("MemberOf-$id"), "found the form" );
    $m->field( "MemberOf-$id", "$child1_id $child2_id" );

    $m->submit;

    $m->content_like(
        qr{"DeleteLink-.*?ticket/$child1_id-MemberOf-"},
        "base for MemberOf: has child1 ticket",
    );
    $m->content_like(
        qr{"DeleteLink-.*?ticket/$child2_id-MemberOf-"},
        "base for MemberOf: has child2 ticket",
    );

    $m->goto_ticket($id);
    $m->content_like( qr{$child1_id:.*?\[new\]}, "has active ticket", );
}

diag "adding timeworked values for child tickets"; {
    my $user_a = RT::Test->load_or_create_user(
        Name => 'user_a', Password => 'password',
    );
    ok $user_a && $user_a->id, 'loaded or created user';

    my $user_b = RT::Test->load_or_create_user(
        Name => 'user_b', Password => 'password',
    );
    ok $user_b && $user_b->id, 'loaded or created user';

    ok( RT::Test->set_rights(
        { Principal => $user_a, Right => [qw(SeeQueue ShowTicket ModifyTicket CommentOnTicket)] },
        { Principal => $user_b, Right => [qw(SeeQueue ShowTicket ModifyTicket CommentOnTicket)] },
    ), 'set rights');


    my @updates = ({
        id => $child1_id,
        view => 'ModifyAll',
        field => 'TimeWorked',
        form => 'TicketModifyAll',
        title => "Ticket #$child1_id Jumbo update: child ticket 1",
        time => 45,
        user => 'user_a',
    }, {
        id => $child2_id,
        view => 'ModifyAll',
        field => 'TimeWorked',
        form => 'TicketModifyAll',
        title => "Ticket #$child2_id Jumbo update: child ticket 2",
        time => 35,
        user => 'user_a',
    }, {
        id => $child2_id,
        view => 'Update',
        field => 'UpdateTimeWorked',
        form => 'TicketUpdate',
        title => "Update ticket #$child2_id: child ticket 2",
        time => 90,
        user => 'user_b',
    });

    foreach my $update ( @updates ) {
        my $agent = RT::Test::Web->new;
        ok $agent->login($update->{user}, 'password'), 'logged in as user';
        $agent->goto_ticket( $update->{id}, $update->{view} );
        $agent->title_is( $update->{title}, 'have child ticket page' );
        ok( $agent->form_name( $update->{form} ), 'found the form' );
        $agent->field( $update->{field}, $update->{time} );
        $agent->submit_form( button => 'SubmitTicket' );
    }
}

diag "checking parent ticket for expected timeworked data"; {
    $m->goto_ticket( $parent_id );
    $m->title_is( "#$parent_id: timeworked parent");
    $m->content_like(
        qr{(?s)value">2\.83 hours \(170 minutes\)},
        "found expected total TimeWorked in parent ticket"
    );
    $m->content_like(
        qr{(?s)user_a:.+?value">1\.33 hours \(80 minutes\)},
        "found expected user_a TimeWorked in parent ticket"
    );
    $m->content_like(
        qr{(?s)user_b:.+?value">1\.5 hours \(90 minutes\)},
        "found expected user_b TimeWorked in parent ticket"
    );
}

diag "checking child ticket 1 for expected timeworked data"; {
    $m->goto_ticket( $child1_id );
    $m->title_is( "#$child1_id: child ticket 1");
    $m->content_like(
        qr{(?s)value">45 minutes},
        "found expected total TimeWorked in child ticket 1"
    );
    $m->content_like(
        qr{(?s)user_a:.+?value">45 minutes},
        "found expected user_a TimeWorked in child ticket 1"
    );
}

diag "checking child ticket 2 for expected timeworked data"; {
    $m->goto_ticket( $child2_id );
    $m->title_is( "#$child2_id: child ticket 2");
    $m->content_like(
        qr{(?s)value">2\.08 hours \(125 minutes\)},
        "found expected total TimeWorked in child ticket 2"
    );
    $m->content_like(
        qr{(?s)user_a:.+?value">35 minutes},
        "found expected user_a TimeWorked in child ticket 2"
    );
    $m->content_like(
        qr{(?s)user_b:.+?value">1\.5 hours \(90 minutes\)},
        "found expected user_b TimeWorked in child ticket 2"
    );
}

diag "TimeWorkedReport queue filter works for both queue id and name";
{
    my $other_queue = RT::Test->load_or_create_queue( Name => 'Other' );
    ok $other_queue && $other_queue->id, 'loaded or created Other queue';

    my $other_ticket = RT::Test->create_ticket(
        Queue => $other_queue->id, Subject => 'worked ticket in Other', TimeWorked => 20,
    );
    ok $other_ticket->id, 'created ticket with time worked in Other queue';
    my $other_tid = $other_ticket->id;

    my $root = RT::User->new( RT->SystemUser );
    $root->Load('root');

    my $report_url = "$baseurl/Reports/TimeWorkedReport.html";
    my $start_date = '2020-01-01';
    my $end_date   = '2035-12-31';

    my $run_report = sub {
        my $queue_value = shift;
        $m->get_ok( $report_url, 'fetched TimeWorkedReport form' );
        ok( $m->form_with_fields(qw(StartDate EndDate Queue)), 'found report form' );
        $m->set_fields(
            StartDate => $start_date,
            EndDate   => $end_date,
            Queue     => $queue_value,
        );
        $m->click_button( value => 'See Time' );
    };

    diag 'Queue filter by id (default drop-down)';
    $run_report->( $queue->id );
    $m->content_like( qr{/Ticket/Display\.html\?id=\Q$child1_id\E"},
        'report by queue id includes a General ticket' );
    $m->content_unlike( qr{/Ticket/Display\.html\?id=\Q$other_tid\E"},
        'report by queue id excludes the Other-queue ticket' );
    $m->content_unlike( qr/No tickets found/, 'report by queue id is not empty' );

    diag 'Queue filter by name (AutocompleteQueues preference enabled)';
    $root->SetPreferences( $RT::System =>
            { %{ $root->Preferences($RT::System) || {} }, AutocompleteQueues => 1 } );

    $m->get_ok( $report_url, 'fetched TimeWorkedReport form with autocomplete' );
    ok( $m->form_with_fields(qw(StartDate EndDate Queue)), 'found report form' );
    is( $m->current_form->find_input('Queue')->type, 'text',
        'Queue field is a text input when AutocompleteQueues is enabled' );

    $run_report->( $queue->Name );
    $m->content_like( qr{/Ticket/Display\.html\?id=\Q$child1_id\E"},
        'report by queue name includes a General ticket' );
    $m->content_unlike( qr{/Ticket/Display\.html\?id=\Q$other_tid\E"},
        'report by queue name excludes the Other-queue ticket' );
    $m->content_unlike( qr/No tickets found/, 'report by queue name is not empty' );

    # Restore the default so later additions to this file are unaffected.
    $root->SetPreferences( $RT::System =>
            { %{ $root->Preferences($RT::System) || {} }, AutocompleteQueues => 0 } );
}

done_testing();
