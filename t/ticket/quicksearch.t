
#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More; 
plan tests => 10;
use_ok('RT');
use RT::Test;


my $q = RT::Model::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.$$;
$q->create(Name => $queue);
ok ($q->id, "Created the queue");

my $t1 = RT::Model::Ticket->new($RT::SystemUser);
my ( $id, undef, $msg ) = $t1->create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Requestor => ['search2@example.com'],
);
ok( $id, $msg );

use_ok("RT::Search::Googleish");
my $tickets = RT::Model::Tickets->new($RT::SystemUser);
my $quick = RT::Search::Googleish->new(Argument => "",
                                 TicketsObj => $tickets);
my @tests = (
    "General new open root"     => "( Owner = 'root' ) AND ( Queue = 'General' ) AND ( Status = 'new' OR Status = 'open' )", 
    "fulltext:jesse"       => "( Content LIKE 'jesse' )",
    $queue                 => "( Queue = '$queue' )",
    "root $queue"          => "( Owner = 'root' ) AND ( Queue = '$queue' )",
    "notauser $queue"      => "( Queue = '$queue' ) AND ( Subject LIKE 'notauser' )",
    "notauser $queue root" => "( Owner = 'root' ) AND ( Queue = '$queue' ) AND ( Subject LIKE 'notauser' )");

while (my ($from, $to) = splice @tests, 0, 2) {
    is($quick->QueryToSQL($from), $to, "<$from> -> <$to>");
}
