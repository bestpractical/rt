
#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More qw/no_plan/;
use_ok('RT');
RT::LoadConfig();
RT::Init();

my $q = RT::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.rand(200);
$q->Create(Name => $queue);
ok ($q->id, "Created the queue");

my $t1 = RT::Ticket->new($RT::SystemUser);
my ( $id, undef $msg ) = $t1->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Requestor => ['search2@example.com'],
);
ok( $id, $msg );

use_ok("RT::Search::Quick");
my $tickets = RT::Tickets->new($RT::SystemUser);
my $quick = RT::Search::Quick->new(Argument => "",
                                 TicketsObj => $tickets);
my @tests = (
    $queue                 => "Queue = '$queue'",
    "root $queue"          => "Owner = 'root' AND Queue = '$queue'",
    "notauser $queue"      => "Content LIKE 'notauser' AND Queue = '$queue'",
    "notauser $queue root" => "Content LIKE 'notauser' AND Queue = '$queue'".
                              " AND Owner = 'root'"
);

while (my ($from, $to) = splice @tests, 0, 2) {
    is($quick->QueryToSQL($from), $to, "<$from> -> <$to>");
}
