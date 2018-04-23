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
    $m->follow_link_ok( { text => 'Links' }, "Followed link to Links" );

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
        view => 'Modify',
        field => 'TimeWorked',
        form => 'TicketModify',
        title => "Modify ticket #$child1_id: child ticket 1",
        time => 45,
        user => 'user_a',
    }, {
        id => $child2_id,
        view => 'Modify',
        field => 'TimeWorked',
        form => 'TicketModify',
        title => "Modify ticket #$child2_id: child ticket 2",
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
        qr{(?s)Worked:.+?value">2\.83 hours \(170 minutes\)},
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
        qr{(?s)Worked:.+?value">45 minutes},
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
        qr{(?s)Worked:.+?value">2\.08 hours \(125 minutes\)},
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

done_testing();
