#!/usr/bin/perl -w
use strict;

use RT::Test tests => 17;
$RT::Test::SKIP_REQUEST_WORK_AROUND = 1;

use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Queue->new($RT::Nobody);
my $qid = $queue->Load('General');
ok( $qid, "Loaded General queue" );

$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');

$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_like(qr/Attachments test/, 'we have subject on the page');
$m->content_like(qr/Some content/, 'and content');
$m->content_like(qr/Download bplogo\.gif/, 'page has file name');

open LOGO, "<", LogoFile or die "Can't open logo file: $!";
binmode LOGO;
my $logo_contents = do {local $/; <LOGO>};
close LOGO;
$m->follow_link_ok({text => "Download bplogo.gif"});
is($m->content_type, "image/gif");
is($m->content, $logo_contents, "Binary content matches");

$m->back;
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

$m->content_like(qr/Download bplogo\.gif/, 'page has file name');
$m->content_like(qr/Download favicon\.png/, 'page has file name');

