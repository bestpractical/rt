use strict;
use warnings;
use RT::Test tests => undef;

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

diag "add ticket links of type MemberOf base"; {
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

my @updates = ({
    id => $child1_id,
    view => 'Modify',
    field => 'TimeWorked',
    form => 'TicketModify',
    title => "Modify ticket #$child1_id",
}, {
    id => $child2_id,
    view => 'Update',
    field => 'UpdateTimeWorked',
    form => 'TicketUpdate',
    title => "Update ticket #$child2_id (child ticket 2)",
});


foreach my $update ( @updates ) {
    $m->goto_ticket( $update->{id}, $update->{view} );
    $m->title_is( $update->{title}, 'have child ticket page' );
    ok( $m->form_name( $update->{form} ), 'found the form' );
    $m->field( $update->{field}, 90 );
    $m->submit_form( button => 'SubmitTicket' );
}

$m->goto_ticket( $parent_id );
$m->title_is( "#$parent_id: timeworked parent");
$m->content_like( qr{180 minutes}, "found expected minutes in parent ticket" );

undef $m;
done_testing();
