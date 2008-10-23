#!/usr/bin/env perl
use strict;
use warnings;
use RT::Test;
use Test::More tests => 18;

my ($baseurl, $m) = RT::Test->started_ok;
ok($m->login, "Logged in");

my $queue = RT::Test->load_or_create_queue(name => 'General');
ok($queue->id, "loaded the General queue");

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my ($tid, $txn, $msg) = $ticket->create(
        queue => $queue->id,
        subject => 'test links',
        );
ok $tid, 'created a ticket #'. $tid or diag "error: $msg";

$m->goto_ticket($tid);

$m->follow_link_ok( { text => 'Links' }, "Followed link to Links" );

my $not_a_ticket_url = "http://example.com/path/to/nowhere";
my $moniker = $m->moniker_for('RT::Action::CreateTicketLinks');

for my $field (
    qw/depends_on depended_on_by member_of has_member refers_to referred_to_by/
  )
{
    $m->fill_in_action_ok( $moniker, $field => $not_a_ticket_url );
}
$m->submit;

foreach my $type ("depends on", "member of", "refers to") {
    $m->content_like(qr/$type.+$not_a_ticket_url/,"base for $type");
    $m->content_like(qr/$not_a_ticket_url.+$type/,"target for $type");
}

$m->goto_ticket($tid);
