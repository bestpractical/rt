use strict;
use warnings;
use RT::Test tests => undef;

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

# A non-ticket (external) URL can be linked in either direction for every relationship. The
# row-based Links editor is JS-driven, so add the links via the API, then verify the display.
my $not_a_ticket_url = "http://example.com/path/to/nowhere";
for my $type (qw/DependsOn MemberOf RefersTo/) {
    my ($ok, $msg) = $ticket->AddLink( Type => $type, Target => $not_a_ticket_url );
    ok $ok, "$type: ticket -> URL: $msg";
    ( $ok, $msg ) = $ticket->AddLink( Type => $type, Base => $not_a_ticket_url );
    ok $ok, "$type: URL -> ticket: $msg";
}

$m->goto_ticket($tid);

$m->content_like( qr{<a[^>]+href="\Q$not_a_ticket_url\E"}, 'URL is rendered as a clickable external link' );
for my $section (qw/DependsOn DependedOnBy MemberOf Members RefersTo ReferredToBy/) {
    ok $m->dom->at(qq{#links-section-$section .links-type-table[data-links-object-type="URL"] a[href="$not_a_ticket_url"]}),
        "URL appears in the $section section";
}

done_testing;
