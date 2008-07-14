
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
    queue      => $q->id,
    subject    => 'SearchTest1',
    requestor => ['search2@example.com'],
);
ok( $id, $msg );

use_ok("RT::Search::Googleish");

my $active_statuses = join( " OR ", map "Status = '$_'", RT::Model::Queue->active_status_array());

my $tickets = RT::Model::TicketCollection->new(current_user => RT->system_user);
my $quick = RT::Search::Googleish->new(argument => "",
                                 tickets_obj => $tickets);
my @tests = (
    "General new open root"     => "( owner = 'root' ) AND ( queue = 'General' ) AND ( status = 'new' OR status = 'open' )", 
    "fulltext:jesse"       => "( content LIKE 'jesse' ) AND ( $active_statuses )",
    $queue                 => "( queue = '$queue' ) AND ( $active_statuses )",
    "root $queue"          => "( owner = 'root' ) AND ( queue = '$queue' ) AND ( $active_statuses )",
    "notauser $queue"      => "( queue = '$queue' ) AND ( $active_statuses ) AND ( Subject LIKE 'notauser' )",
    "notauser $queue root" => "( owner = 'root' ) AND ( queue = '$queue' ) AND ( $active_statuses ) AND ( Subject LIKE 'notauser' )");

while (my ($from, $to) = splice @tests, 0, 2) {
    is(lc $quick->query_to_sql($from), lc $to, "<$from> -> <$to>");
}
