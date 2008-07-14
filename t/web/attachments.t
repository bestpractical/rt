#!/usr/bin/perl -w
use strict;

use RT::Test; use Test::More tests => 14;


use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';
my $queue = RT::Model::Queue->new($RT::nobody);
my $qid = $queue->load('General');
ok( $qid, "Loaded General queue" );

$m->form_name('CreateTicketInQueue');
$m->field('queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');
$m->form_name('TicketCreate');
$m->field('subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('content', 'Some content');
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
$m->field('update_content', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_like(qr/Download bplogo\.gif/, 'page has file name');
$m->content_like(qr/Download favicon\.png/, 'page has file name');

