#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 119;
use RT::Ticket;

my $q = RT::Test->load_or_create_queue( Name => 'Regression' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

my ($total, @data, @tickets, %test) = (0, ());

sub add_tix_from_data {
    my @res = ();
    while (@data) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my ( $id, undef $msg ) = $t->Create(
            Queue => $q->id,
            %{ shift(@data) },
        );
        ok( $id, "ticket created" ) or diag("error: $msg");
        push @res, $t;
        $total++;
    }
    return @res;
}

sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $key ( sort keys %test ) {
        my $tix = RT::Tickets->new($RT::SystemUser);
        $tix->FromSQL( "( $query_prefix ) AND ( $key )" );

        my $error = 0;

        my $count = 0;
        $count++ foreach grep $_, values %{ $test{$key} };
        is($tix->Count, $count, "found correct number of ticket(s) by '$key'") or $error = 1;

        my $good_tickets = ($tix->Count == $count);
        while ( my $ticket = $tix->Next ) {
            next if $test{$key}->{ $ticket->Subject };
            diag $ticket->Subject ." ticket has been found when it's not expected";
            $good_tickets = 0;
        }
        ok( $good_tickets, "all tickets are good with '$key'" ) or $error = 1;

        diag "Wrong SQL query for '$key':". $tix->BuildSelectQuery if $error;
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
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();

# mixing searches by watchers with other conditions
# http://rt3.fsck.com/Ticket/Display.html?id=9322
%test = (
    'Subject LIKE "x" AND Requestor = "y@example.com"' =>
        { xy => 1, x => 0, y => 0, '-' => 0, z => 0 },
    'Subject NOT LIKE "x" AND Requestor = "y@example.com"' =>
        { xy => 0, x => 0, y => 1, '-' => 0, z => 0 },
    'Subject LIKE "x" AND Requestor != "y@example.com"' =>
        { xy => 0, x => 1, y => 0, '-' => 0, z => 0 },
    'Subject NOT LIKE "x" AND Requestor != "y@example.com"' =>
        { xy => 0, x => 0, y => 0, '-' => 1, z => 1 },

    'Subject LIKE "x" OR Requestor = "y@example.com"' =>
        { xy => 1, x => 1, y => 1, '-' => 0, z => 0 },
    'Subject NOT LIKE "x" OR Requestor = "y@example.com"' =>
        { xy => 1, x => 0, y => 1, '-' => 1, z => 1 },
    'Subject LIKE "x" OR Requestor != "y@example.com"' =>
        { xy => 1, x => 1, y => 0, '-' => 1, z => 1 },
    'Subject NOT LIKE "x" OR Requestor != "y@example.com"' =>
        { xy => 0, x => 1, y => 1, '-' => 1, z => 1 },

# group of cases when user doesn't exist in DB at all
    'Subject LIKE "x" AND Requestor = "not-exist@example.com"' =>
        { xy => 0, x => 0, y => 0, '-' => 0, z => 0 },
    'Subject NOT LIKE "x" AND Requestor = "not-exist@example.com"' =>
        { xy => 0, x => 0, y => 0, '-' => 0, z => 0 },
    'Subject LIKE "x" AND Requestor != "not-exist@example.com"' =>
        { xy => 1, x => 1, y => 0, '-' => 0, z => 0 },
    'Subject NOT LIKE "x" AND Requestor != "not-exist@example.com"' =>
        { xy => 0, x => 0, y => 1, '-' => 1, z => 1 },
#    'Subject LIKE "x" OR Requestor = "not-exist@example.com"' =>
#        { xy => 1, x => 1, y => 0, '-' => 0, z => 0 },
#    'Subject NOT LIKE "x" OR Requestor = "not-exist@example.com"' =>
#        { xy => 0, x => 0, y => 1, '-' => 1, z => 1 },
    'Subject LIKE "x" OR Requestor != "not-exist@example.com"' =>
        { xy => 1, x => 1, y => 1, '-' => 1, z => 1 },
    'Subject NOT LIKE "x" OR Requestor != "not-exist@example.com"' =>
        { xy => 1, x => 1, y => 1, '-' => 1, z => 1 },

    'Subject LIKE "z" AND (Requestor = "x@example.com" OR Requestor = "y@example.com")' =>
        { xy => 0, x => 0, y => 0, '-' => 0, z => 0 },
    'Subject NOT LIKE "z" AND (Requestor = "x@example.com" OR Requestor = "y@example.com")' =>
        { xy => 1, x => 1, y => 1, '-' => 0, z => 0 },
    'Subject LIKE "z" OR (Requestor = "x@example.com" OR Requestor = "y@example.com")' =>
        { xy => 1, x => 1, y => 1, '-' => 0, z => 1 },
    'Subject NOT LIKE "z" OR (Requestor = "x@example.com" OR Requestor = "y@example.com")' =>
        { xy => 1, x => 1, y => 1, '-' => 1, z => 0 },
);
run_tests();

TODO: {
    local $TODO = "we can't generate this query yet";
    %test = (
        'Requestor = "x@example.com" AND Requestor = "y@example.com"'
            => { xy => 1, x => 0, y => 0, '-' => 0, z => 0 },
        'Subject LIKE "x" OR Requestor = "not-exist@example.com"' =>
            { xy => 1, x => 1, y => 0, '-' => 0, z => 0 },
        'Subject NOT LIKE "x" OR Requestor = "not-exist@example.com"' =>
            { xy => 0, x => 0, y => 1, '-' => 1, z => 1 },
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
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue'");
    is($tix->Count, $total, "found $total tickets");
}
run_tests();


# owner is special watcher because reference is duplicated in two places,
# owner was an ENUM field now it's WATCHERFIELD, but should support old
# style ENUM searches for backward compatibility
my $nobody = RT::Nobody();
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->id ."'");
    ok($tix->Count, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = '". $nobody->Name ."'");
    ok($tix->Count, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->id ."'");
    is($tix->Count, 0, "found ticket(s)");
}
{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner != '". $nobody->Name ."'");
    is($tix->Count, 0, "found ticket(s)");
}

{
    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner.Name LIKE 'nob'");
    ok($tix->Count, "found ticket(s)");
}

{
    # create ticket and force type to not a 'ticket' value
    # bug #6898@rt3.fsck.com
    # and http://marc.theaimsgroup.com/?l=rt-devel&m=112662934627236&w=2
    @data = ( { Subject => 'not a ticket' } );
    my($t) = add_tix_from_data();
    $t->_Set( Field             => 'Type',
              Value             => 'not a ticket',
              CheckACL          => 0,
              RecordTransaction => 0,
            );
    $total--;

    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND Owner = 'Nobody'");
    is($tix->Count, $total, "found ticket(s)");
}

{
    my $everyone = RT::Group->new( $RT::SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok($everyone->id, "loaded 'everyone' group");
    my($id, $msg) = $everyone->PrincipalObj->GrantRight( Right => 'OwnTicket',
                                                         Object => $q
                                                       );
    ok($id, "granted OwnTicket right to Everyone on '$queue'") or diag("error: $msg");

    my $u = RT::User->new( $RT::SystemUser );
    $u->LoadOrCreateByEmail('alpha@example.com');
    ok($u->id, "loaded user");
    @data = ( { Subject => '4', Owner => $u->id } );
    my($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "created ticket with custom owner" );
    my $u_alpha_id = $u->id;

    $u = RT::User->new( $RT::SystemUser );
    $u->LoadOrCreateByEmail('bravo@example.com');
    ok($u->id, "loaded user");
    @data = ( { Subject => '5', Owner => $u->id } );
    ($t) = add_tix_from_data();
    is( $t->Owner, $u->id, "created ticket with custom owner" );
    my $u_bravo_id = $u->id;

    my $tix = RT::Tickets->new($RT::SystemUser);
    $tix->FromSQL("Queue = '$queue' AND
                   ( Owner = '$u_alpha_id' OR
                     Owner = '$u_bravo_id' )"
                 );
    is($tix->Count, 2, "found ticket(s)");
}


exit(0)
