use strict;
use warnings;
use RT::Test tests => 106;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, "Logged in" );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue->id, "loaded the General queue" );

my ( $deleted, $active, $inactive ) = RT::Test->create_tickets(
    { Queue   => 'General' },
    { Subject => 'deleted ticket', },
    { Subject => 'active ticket', },
    { Subject => 'inactive ticket', }
);

my ( $deleted_id, $active_id, $inactive_id ) =
  ( $deleted->id, $active->id, $inactive->id );

$deleted->SetStatus('deleted');
is( $deleted->Status, 'deleted', "deleted $deleted_id" );

$inactive->SetStatus('resolved');
is( $inactive->Status, 'resolved', 'resolved $inactive_id' );

for my $type ( "DependsOn", "MemberOf", "RefersTo" ) {
    for my $c (qw/base target/) {
        my $id;

        diag "create ticket with links of type $type $c";
        {
            ok( $m->goto_create_ticket($queue), "go to create ticket" );
            $m->form_name('TicketCreate');
            $m->field( Subject => "test ticket creation with $type $c" );
            if ( $c eq 'base' ) {
                $m->field( "new-$type", "$deleted_id $active_id $inactive_id" );
            }
            else {
                $m->field( "$type-new", "$deleted_id $active_id $inactive_id" );
            }

            $m->submit;
            $m->content_like(qr/Ticket \d+ created/, 'created ticket');
            $m->content_contains("Can&#39;t link to a deleted ticket");
            $id = RT::Test->last_ticket->id;
        }

        diag "add ticket links of type $type $c";
        {
            my $ticket = RT::Test->create_ticket(
                Queue   => 'General',
                Subject => "test $type $c",
            );
            $id = $ticket->id;

            $m->goto_ticket($id);
            $m->follow_link_ok( { text => 'Links' }, "Followed link to Links" );

            ok( $m->form_with_fields("$id-DependsOn"), "found the form" );
            if ( $c eq 'base' ) {
                $m->field( "$id-$type", "$deleted_id $active_id $inactive_id" );
            }
            else {
                $m->field( "$type-$id", "$deleted_id $active_id $inactive_id" );
            }
            $m->submit;
            $m->content_contains("Can&#39;t link to a deleted ticket");

            if ( $c eq 'base' ) {
                $m->content_like(
                    qr{"DeleteLink--$type-.*?ticket/$active_id"},
                    "$c for $type: has active ticket",
                );
                $m->content_like(
                    qr{"DeleteLink--$type-.*?ticket/$inactive_id"},
                    "base for $type: has inactive ticket",
                );
                $m->content_unlike(
                    qr{"DeleteLink--$type-.*?ticket/$deleted_id"},
                    "base for $type: no deleted ticket",
                );
            }
            else {
                $m->content_like(
                    qr{"DeleteLink-.*?ticket/$active_id-$type-"},
                    "$c for $type: has active ticket",
                );
                $m->content_like(
                    qr{"DeleteLink-.*?ticket/$inactive_id-$type-"},
                    "base for $type: has inactive ticket",
                );
                $m->content_unlike(
                    qr{"DeleteLink-.*?ticket/$deleted_id-$type-"},
                    "base for $type: no deleted ticket",
                );
            }
        }

        $m->goto_ticket($id);
        $m->content_like( qr{$active_id:.*?\[new\]}, "has active ticket", );
        $m->content_like(
            qr{$inactive_id:.*?\[resolved\]},
            "has inactive ticket",
        );
        $m->content_unlike( qr{$deleted_id.*?\[deleted\]}, "no deleted ticket",
        );
    }
}

