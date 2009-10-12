#!/usr/bin/env perl
use strict;
use warnings;

use RT::Test tests => 43;
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create( Name => 'other' );
ok( $queue->id, 'created queue other');

my $ticket_found_1 = RT::Ticket->new($RT::SystemUser);
my $ticket_found_2 = RT::Ticket->new($RT::SystemUser);
my $ticket_not_found = RT::Ticket->new($RT::SystemUser);

$ticket_found_1->Create(
    Subject   => 'base ticket 1'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 1',
);
ok( $ticket_found_1->id, 'created ticket for custom search');


$ticket_found_2->Create(
    Subject   => 'base ticket 2'.$$,
    Queue     => 'general',
    Owner     => 'root',
    Requestor => 'customsearch@localhost',
    Content   => 'this is base ticket 2',
);
ok( $ticket_found_2->id, 'created ticket for custom search');

$ticket_not_found = RT::Ticket->new($RT::SystemUser);
$ticket_not_found->Create(
    Subject   => 'not found subject' . $$,
    Queue     => 'other',
    Owner     => 'nobody',
    Requestor => 'notfound@localhost',
    Content   => 'this is not found content',
);
ok( $ticket_not_found->id, 'created ticket for custom search');

ok($m->login, 'logged in');

my @queries = (
    'base ticket',            'root',
    'customsearch@localhost', 'requestor:customsearch',
    'subject:base',           'subject:"base ticket"',
    'queue:general',          'owner:root',
);

for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
}

$ticket_not_found->SetStatus('open');
is( $ticket_not_found->Status, 'open', 'status of not found ticket is open' );
@queries = qw/new status:new/;
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_contains( 'base ticket 2', 'base ticket 2 is found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
}

@queries = ( 'fulltext:"base ticket 1"', "'base ticket 1'" );
for my $q (@queries) {
    $m->form_with_fields('q');
    $m->field( q => $q );
    $m->submit;
    $m->content_contains( 'base ticket 1', 'base ticket 1 is found' );
    $m->content_lacks( 'base ticket 2',     'base ticket 2 is not found' );
    $m->content_lacks( 'not found subject', 'not found ticket is not found' );
}
