
#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More; 
plan tests => 10;
use_ok('RT');



my $q = RT::Model::Queue->new(current_user => RT->system_user);
my $queue = 'SearchTests-'.$$;
$q->create(name => $queue);
ok ($q->id, "Created the queue");

my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ( $id, undef, $msg ) = $t1->create(
    Queue      => $q->id,
    subject    => 'SearchTest1',
    Requestor => ['search2@example.com'],
);
ok( $id, $msg );

use_ok("RT::Search::Googleish");
my $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
my $quick = RT::Search::Googleish->new(Argument => "",
                                 TicketsObj => $tickets);
my @tests = (
    "General new open root"     => "( Owner = 'root' ) AND ( Queue = 'General' ) AND ( Status = 'new' OR Status = 'open' )", 
    "fulltext:jesse"       => "( Content LIKE 'jesse' )",
    $queue                 => "( Queue = '$queue' )",
    "root $queue"          => "( Owner = 'root' ) AND ( Queue = '$queue' )",
    "notauser $queue"      => "( Queue = '$queue' ) AND ( subject LIKE 'notauser' )",
    "notauser $queue root" => "( Owner = 'root' ) AND ( Queue = '$queue' ) AND ( subject LIKE 'notauser' )");

while (my ($from, $to) = splice @tests, 0, 2) {
    is($quick->query_to_sql($from), $to, "<$from> -> <$to>");
}
