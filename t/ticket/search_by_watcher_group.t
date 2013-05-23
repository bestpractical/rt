use strict;
use warnings;

use RT::Test tests => undef;

use Test::Warn;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;


my $group;
{
    $group = RT::Group->new( RT->SystemUser );
    my ($id, $msg) = $group->CreateUserDefinedGroup( Name => 'Test' );
    ok $id, "$msg";
}

my $root = RT::Test->load_or_create_user( Name => 'root', MemberOf => $group->id );
ok $root && $root->id;

RT::Test->create_tickets(
    { Queue => $q, },
    { Subject => '-', },
    { Subject => 'o', Owner => $root->id },
    { Subject => 'r', Requestor => $root->id },
    { Subject => 'c', Cc => $root->id },
    { Subject => 'a', AdminCc => $root->id },
);

run_tests(
    'OwnerGroup = "Test"' => { '-' => 0, o => 1, r => 0, c => 0, a => 0 },
    'RequestorGroup = "Test"' => { '-' => 0, o => 0, r => 1, c => 0, a => 0 },
    'CCGroup = "Test"' => { '-' => 0, o => 0, r => 0, c => 1, a => 0 },
    'AdminCCGroup = "Test"' => { '-' => 0, o => 0, r => 0, c => 0, a => 1 },
    'WatcherGroup = "Test"' => { '-' => 0, o => 1, r => 1, c => 1, a => 1 },
);

warning_like {
    my $tickets = RT::Tickets->new( RT->SystemUser );
    my ($status, $msg) = $tickets->FromSQL('OwnerGroup != "Test"');
    ok !$status, "incorrect op: $msg";
} qr{Invalid OwnerGroup Op: !=};

done_testing();

sub run_tests {
    my @test = @_;
    while ( my ($query, $checks) = splice @test, 0, 2 ) {
        run_test( $query, %$checks );
    }
}

sub run_test {
    my ($query, %checks) = @_;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL($query);
    my $error = 0;

    my $count = 0;
    $count++ foreach grep $_, values %checks;
    is($tix->Count, $count, "found correct number of ticket(s) by '$query'") or $error = 1;

    my $good_tickets = ($tix->Count == $count);
    while ( my $ticket = $tix->Next ) {
        next if $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}
