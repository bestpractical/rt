#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Ticket->new(RT::CurrentUser->new('root'));
my ($ok, $msg) = $ticket->Create(Queue => 1, Owner => 'nobody', Subject => 'bad music');
ok($ok);

my ($baseurl, $m) = RT::Test->started_ok;

my $test_page = "/Ticket/Create.html?Queue=1";

$m->get_ok($baseurl);
ok $m->login, 'logged in';

# valid referer
$m->add_header(Referer => $baseurl);
$m->get_ok($test_page);
$m->content_lacks("Referer is unknown site");
$m->title_is('Create a new ticket');

# now send a referer from an attacker
$m->add_header(Referer => 'http://example.net');
$m->get_ok($test_page);
$m->content_contains("Referer is unknown site");
$m->warning_like(qr/Referer is unknown site/);

# try a whitelisted argument from an attacker
$m->add_header(Referer => 'http://example.net');
$m->get_ok("/Ticket/Display.html?id=1");
$m->content_lacks("Referer is unknown site");
$m->title_is('#1: bad music');

# now a non-whitelisted argument
$m->get_ok("/Ticket/Display.html?id=1&Action=Take");
$m->content_contains("Referer is unknown site");
$m->warning_like(qr/Referer is unknown site/);


# now try self-service with CSRF
my $user = RT::User->new(RT->SystemUser);
$user->Create(Name => "SelfService", Password => "chops", Privileged => 0);

$m = RT::Test::Web->new;
$m->get_ok($baseurl);
$m->get_ok("$baseurl/index.html?user=SelfService&pass=chops");
$m->title_is("Open tickets", "got self-service interface");
$m->content_contains("My open tickets", "got self-service interface");

# post without referer
$m->add_header(Referer => undef);
$m->get_ok("/SelfService/Create.html?Queue=1");
$m->content_contains("No Referer header");
$m->warning_like(qr/No Referer header/);

undef $m;
done_testing;
