#!/usr/bin/perl -w
use strict;

use Test::More tests => 15;
use RT;
RT::LoadConfig;
RT::Init;
use Test::WWW::Mechanize;

$RT::WebURL ||= 0; # avoid stupid warning
my $BaseURL = $RT::WebURL;
use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my $queue_name = 'General';

my $m = Test::WWW::Mechanize->new;
isa_ok($m, 'Test::WWW::Mechanize');

$m->get_ok( $BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');

my $qid;
{
    $m->content =~ /<SELECT\s+NAME\s*="Queue">.*?<OPTION\s+VALUE="(\d+)"\s*\d*>\s*\Q$queue_name\E\s*<\/OPTION>/msi;
    ok( $qid = $1, "found id of the '$queue_name' queue");
}

$m->form_number(1);
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');

$m->form('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_like(qr/Attachments test/, 'we have subject on the page');
$m->content_like(qr/Some content/, 'and content');
$m->content_like(qr/Download bplogo\.gif/, 'page has file name');

$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->form('TicketUpdate');
$m->field('Attach',  LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form('TicketUpdate');
$m->field('Attach',  FaviconFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_like(qr/Download bplogo\.gif/, 'page has file name');
$m->content_like(qr/Download favicon\.png/, 'page has file name');

