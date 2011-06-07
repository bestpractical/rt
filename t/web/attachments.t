#!/usr/bin/perl -w
use strict;

use RT::Test tests => 25;

use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bpslogo.png';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Queue->new(RT->Nobody);
my $qid = $queue->Load('General');
ok( $qid, "Loaded General queue" );

$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_contains("Create a new ticket", 'ticket create page');

$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_contains('Attachments test', 'we have subject on the page');
$m->content_contains('Some content', 'and content');
$m->content_contains('Download bpslogo.png', 'page has file name');

$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->form_name('TicketUpdate');
$m->field('Attach',  LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form_name('TicketUpdate');
$m->field('Attach',  FaviconFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_contains('Download bpslogo.png', 'page has file name');
$m->content_contains('Download favicon.png', 'page has file name');


diag "test mobile ui";
$m->get_ok( $baseurl . '/m/ticket/create?Queue=' . $qid );

$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_contains('Attachments test', 'we have subject on the page');
$m->content_contains('bpslogo.png', 'page has file name');

$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->form_name('TicketUpdate');
$m->field('Attach',  LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form_name('TicketUpdate');
$m->field('Attach',  FaviconFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_contains('bpslogo.png', 'page has file name');
$m->content_contains('favicon.png', 'page has file name');
