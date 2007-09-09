#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 78;
use RT::Test;
use RT::Model::Ticket;

my $q = RT::Model::Queue->new( $RT::SystemUser );
my $queue = 'SearchTests-'. rand(200);
$q->create( Name => $queue );

my ($total, @data, @tickets, %test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    while (@data) {
        my $t = RT::Model::Ticket->new($RT::SystemUser);
        my ( $id, undef $msg ) = $t->create(
            Queue => $q->id,
            %{ shift(@data) },
        );
        ok( $id, "ticket Created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}

sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
        $tix->from_sql( "( $query_prefix ) AND ( $key )" );

        my $error = 0;

        my $count = 0;
        $count++ foreach grep $_, values %{ $test{$key} };
        is($tix->count, $count, "found correct number of ticket(s) by '$key'") or $error = 1;

        my $good_tickets = 1;
        while ( my $ticket = $tix->next ) {
            next if $test{$key}->{ $ticket->Subject };
            diag $ticket->Subject ." ticket has been found when it's not expected";
            $good_tickets = 0;
        }
        ok( $good_tickets, "all tickets are good with '$key'" ) or $error = 1;

        diag "Wrong SQL query for '$key':". $tix->build_select_query if $error;
    }
}

@data = (
    { Subject => 'xy', Requestor => ['x@example.com', 'y@example.com'] },
    { Subject => 'x', Requestor => 'x@example.com' },
    { Subject => 'y', Requestor => 'y@example.com' },
    { Subject => '-', },
    { Subject => 'z', Requestor => 'z@example.com' },
);
%test = (
    'Requestor = "x@example.com"'  => { xy => 1, x => 1, y => 0, '-' => 0, z => 0 },
    'Requestor != "x@example.com"' => { xy => 0, x => 0, y => 1, '-' => 1, z => 1 },

    'Requestor = "y@example.com"'  => { xy => 1, x => 0, y => 1, '-' => 0, z => 0 },
    'Requestor != "y@example.com"' => { xy => 0, x => 1, y => 0, '-' => 1, z => 1 },

    'Requestor LIKE "@example.com"'     => { xy => 1, x => 1, y => 1, '-' => 0, z => 1 },
    'Requestor NOT LIKE "@example.com"' => { xy => 0, x => 0, y => 0, '-' => 1, z => 0 },

    'Requestor IS NULL'            => { xy => 0, x => 0, y => 0, '-' => 1, z => 0 },
    'Requestor IS NOT NULL'        => { xy => 1, x => 1, y => 1, '-' => 0, z => 1 },

# this test is a todo, we run it later
#    'Requestor = "x@example.com" AND Requestor = "y@example.com"'   => { xy => 1, x => 0, y => 0, '-' => 0, z => 0 },
    'Requestor = "x@example.com" OR Requestor = "y@example.com"'    => { xy => 1, x => 1, y => 1, '-' => 0, z => 0 },

    'Requestor != "x@example.com" AND Requestor != "y@example.com"' => { xy => 0, x => 0, y => 0, '-' => 1, z => 1 },
    'Requestor != "x@example.com" OR Requestor != "y@example.com"'  => { xy => 0, x => 1, y => 1, '-' => 1, z => 1 },

    'Requestor = "x@example.com" AND Requestor != "y@example.com"'  => { xy => 0, x => 1, y => 0, '-' => 0, z => 0 },
    'Requestor = "x@example.com" OR Requestor != "y@example.com"'   => { xy => 1, x => 1, y => 0, '-' => 1, z => 1 },

    'Requestor != "x@example.com" AND Requestor = "y@example.com"'  => { xy => 0, x => 0, y => 1, '-' => 0, z => 0 },
    'Requestor != "x@example.com" OR Requestor = "y@example.com"'   => { xy => 1, x => 0, y => 1, '-' => 1, z => 1 },
);
@tickets = add_tix_from_data();
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue'");
    is($tix->count, $total, "found $total tickets");
}
run_tests();

TODO: {
    local $TODO = "we can't generate this query yet";
    %test = (
        'Requestor = "x@example.com" AND Requestor = "y@example.com"'
            => { xy => 1, x => 0, y => 0, '-' => 0, z => 0 },
    );
    run_tests();
}

@data = (
    { Subject => 'xy', Cc => ['x@example.com'], Requestor => [ 'y@example.com' ] },
    { Subject => 'x-', Cc => ['x@example.com'], Requestor => [] },
    { Subject => '-y', Cc => [],                Requestor => [ 'y@example.com' ] },
    { Subject => '-', },
    { Subject => 'zz', Cc => ['z@example.com'], Requestor => [ 'z@example.com' ] },
    { Subject => 'z-', Cc => ['z@example.com'], Requestor => [] },
    { Subject => '-z', Cc => [],                Requestor => [ 'z@example.com' ] },
);
%test = (
    'Cc = "x@example.com" AND Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 0, '-y' => 0, '-' => 0, zz => 0, 'z-' => 0, '-z' => 0 },
    'Cc = "x@example.com" OR Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 1, '-y' => 1, '-' => 0, zz => 0, 'z-' => 0, '-z' => 0 },

    'Cc != "x@example.com" AND Requestor = "y@example.com"' =>
        { xy => 0, 'x-' => 0, '-y' => 1, '-' => 0, zz => 0, 'z-' => 0, '-z' => 0 },
    'Cc != "x@example.com" OR Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 0, '-y' => 1, '-' => 1, zz => 1, 'z-' => 1, '-z' => 1 },

    'Cc IS NULL AND Requestor = "y@example.com"' =>
        { xy => 0, 'x-' => 0, '-y' => 1, '-' => 0, zz => 0, 'z-' => 0, '-z' => 0 },
    'Cc IS NULL OR Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 0, '-y' => 1, '-' => 1, zz => 0, 'z-' => 0, '-z' => 1 },

    'Cc IS NOT NULL AND Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 0, '-y' => 0, '-' => 0, zz => 0, 'z-' => 0, '-z' => 0 },
    'Cc IS NOT NULL OR Requestor = "y@example.com"' =>
        { xy => 1, 'x-' => 1, '-y' => 1, '-' => 0, zz => 1, 'z-' => 1, '-z' => 0 },
);
@tickets = add_tix_from_data();
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue'");
    is($tix->count, $total, "found $total tickets");
}
run_tests();

# owner is special watcher because reference is duplicated in two places,
# owner was an ENUM field now it's WATCHERFIELD, but should support old
# style ENUM searches for backward compatibility
my $nobody = RT::Nobody();
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner = '". $nobody->id ."'");
    ok($tix->count, "found ticket(s)");
}
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner = '". $nobody->Name ."'");
    ok($tix->count, "found ticket(s)");
}
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner != '". $nobody->id ."'");
    is($tix->count, 0, "found ticket(s)");
}
{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner != '". $nobody->Name ."'");
    is($tix->count, 0, "found ticket(s)");
}

{
    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner.Name LIKE 'nob'");
    ok($tix->count, "found ticket(s)");
}

{
    # create ticket and force type to not a 'ticket' value
    # bug #6898@rt3.fsck.com
    # and http://marc.theaimsgroup.com/?l=rt-devel&m=112662934627236&w=2
    @data = ( { Subject => 'not a ticket' } );
    my($t) = add_tix_from_data();
    $t->_set( column             => 'Type',
              value             => 'not a ticket',
              CheckACL          => 0,
              RecordTransaction => 0,
            );
    $total--;

    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND Owner = 'Nobody'");
    is($tix->count, $total, "found ticket(s)");
}

{
    my $everyone = RT::Model::Group->new( $RT::SystemUser );
    $everyone->load_system_internal_group('Everyone');
    ok($everyone->id, "loaded 'everyone' group");
    my($id, $msg) = $everyone->PrincipalObj->GrantRight( Right => 'OwnTicket',
                                                         Object => $q
                                                       );
    ok($id, "granted OwnTicket right to Everyone on '$queue'") or diag("error: $msg");

    my $u = RT::Model::User->new( $RT::SystemUser );
    $u->load_or_create_by_email('alpha@example.com');
    ok($u->id, "loaded user");
    @data = ( { Subject => '4', Owner => $u->id } );
    my($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "Created ticket with custom owner" );
    my $u_alpha_id = $u->id;

    $u = RT::Model::User->new( $RT::SystemUser );
    $u->load_or_create_by_email('bravo@example.com');
    ok($u->id, "loaded user");
    @data = ( { Subject => '5', Owner => $u->id } );
    ($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "Created ticket with custom owner" );
    my $u_bravo_id = $u->id;

    my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
    $tix->from_sql("Queue = '$queue' AND
                   ( Owner = '$u_alpha_id' OR
                     Owner = '$u_bravo_id' )"
                 );
    is($tix->count, 2, "found ticket(s)");
}


exit(0)
