#!/usr/bin/perl -w
use strict;

use RT::Test; use Test::More tests => 14;


use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';
my $queue_name = 'General';
my $qid;
{
    $m->content =~ /<SELECT\s+name\s*="Queue"\s*>.*?<OPTION\s+value="(\d+)".*?>\s*\Q$queue_name\E\s*<\/OPTION>/msig;
    ok( $qid = $1, "found id of the '$queue_name' queue");
}

$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');
$m->form_name('TicketCreate');
$m->field('subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_like(qr/Attachments test/, 'we have subject on the page');
$m->content_like(qr/Some content/, 'and content');
$m->content_like(qr/Download bplogo\.gif/, 'page has file name');
$m->follow_link_ok(text => 'Reply');
$m->form_name('TicketUpdate');
$m->field('Attach',  LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form_name('TicketUpdate');
$m->field('Attach',  FaviconFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_like(qr/Download bplogo\.gif/, 'page has file name');
$m->content_like(qr/Download favicon\.png/, 'page has file name');

