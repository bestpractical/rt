use strict;
use warnings;
use RT::Test tests => 14;

my ($baseurl, $m) = RT::Test->started_ok;
ok($m->login, "Logged in");

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok($queue->Id, "loaded the General queue");

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tid, $txn, $msg) = $ticket->Create(
        Queue => $queue->id,
        Subject => 'test links',
        );
ok $tid, 'created a ticket #'. $tid or diag "error: $msg";

$m->goto_ticket($tid);

$m->follow_link_ok( { text => 'Links' }, "Followed link to Links" );

ok $m->form_with_fields("$tid-DependsOn"), "found the form";
my $not_a_ticket_url = "http://example.com/path/to/nowhere";
$m->field("$tid-DependsOn", $not_a_ticket_url);
$m->field("DependsOn-$tid", $not_a_ticket_url);
$m->field("$tid-MemberOf", $not_a_ticket_url);
$m->field("MemberOf-$tid", $not_a_ticket_url);
$m->field("$tid-RefersTo", $not_a_ticket_url);
$m->field("RefersTo-$tid", $not_a_ticket_url);
$m->submit;

foreach my $type ("depends on", "member of", "refers to") {
    $m->content_like(qr/$type.+$not_a_ticket_url/,"base for $type");
    $m->content_like(qr/$not_a_ticket_url.+$type/,"target for $type");
}

$m->goto_ticket($tid);
