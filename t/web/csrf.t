use strict;
use warnings;

use RT::Test tests => undef;

my $ticket = RT::Ticket->new(RT::CurrentUser->new('root'));
my ($ok, $msg) = $ticket->Create(Queue => 1, Owner => 'nobody', Subject => 'bad music');
ok($ok);
my $other = RT::Test->load_or_create_queue(Name => "Other queue", Disabled => 0);
my $other_queue_id = $other->id;

my ($baseurl, $m) = RT::Test->started_ok;

my $test_page = "/Ticket/Create.html?Queue=1";
my $test_path = "/Ticket/Create.html";

ok $m->login, 'logged in';

# valid referer
$m->add_header(Referer => $baseurl);
$m->get_ok($test_page);
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('Create a new ticket in General');

# off-site referer BUT provides auth
$m->add_header(Referer => 'http://example.net');
$m->get_ok("$test_page&user=root&pass=password");
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('Create a new ticket in General');

# explicitly no referer BUT provides auth
$m->add_header(Referer => undef);
$m->get_ok("$test_page&user=root&pass=password");
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('Create a new ticket in General');

# CSRF parameter whitelist tests
my $searchBuildPath = '/Search/Build.html';

# CSRF whitelist for /Search/Build.html param SavedSearchLoad
$m->add_header(Referer => undef);
$m->get_ok("$searchBuildPath?SavedSearchLoad=foo");
$m->content_lacks('Possible cross-site request forgery');
$m->title_is('Query Builder');

# CSRF pass for /Search/Build.html no param
$m->add_header(Referer => undef);
$m->get_ok("$searchBuildPath");
$m->content_lacks('Possible cross-site request forgery');
$m->title_is('Query Builder');

# CSRF fail for /Search/Build.html arbitrary param only
$m->add_header(Referer => undef);
$m->get_ok("$searchBuildPath?foo=bar");
$m->content_contains('Possible cross-site request forgery');
$m->title_is('Possible cross-site request forgery');

# CSRF fail for /Search/Build.html arbitrary param with SavedSearchLoad
$m->add_header(Referer => undef);
$m->get_ok("$searchBuildPath?SavedSearchLoad=foo&foo=bar");
$m->content_contains('Possible cross-site request forgery');
$m->title_is('Possible cross-site request forgery');

# CSRF pass for /Search/Build.html param NewQuery
$m->add_header(Referer => undef);
$m->get_ok("$searchBuildPath?NewQuery=1");
$m->content_lacks('Possible cross-site request forgery');
$m->title_is('Query Builder');

# CSRF pass for /Ticket/Update.html items in ticket action menu
$m->add_header(Referer => undef);
$m->get_ok('/Ticket/Update.html?id=1&Action=foo');
$m->content_lacks('Possible cross-site request forgery');

# CSRF pass for /Ticket/Update.html reply to message in ticket history
$m->add_header(Referer => undef);
$m->get_ok('/Ticket/Update.html?id=1&QuoteTransaction=1&Action=Reply');
$m->content_lacks('Possible cross-site request forgery');

# CSRF pass for /Articles/Article/ExtractIntoClass.html
# Action->Extract Article on ticket menu
$m->add_header(Referer => undef);
$m->get_ok('/Articles/Article/ExtractIntoClass.html?Ticket=1');
$m->content_lacks('Possible cross-site request forgery');

# now send a referer from an attacker
$m->add_header(Referer => 'http://example.net');
$m->get_ok($test_page);
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Ticket/Create.html</tt>");
$m->content_contains("the Referrer header supplied by your browser (example.net:80) is not allowed");
$m->title_is('Possible cross-site request forgery');

# reinstate mech's usual header policy
$m->delete_header('Referer');

# clicking the resume request button gets us to the test page
$m->follow_link(text_regex => qr{resume your request});
$m->content_lacks("Possible cross-site request forgery");
like($m->response->request->uri, qr{^http://[^/]+\Q$test_path\E\?CSRF_Token=\w+$});
$m->title_is('Create a new ticket in General');

# try a whitelisted argument from an attacker
$m->add_header(Referer => 'http://example.net');
$m->get_ok("/Ticket/Display.html?id=1");
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('#1: bad music');

# now a non-whitelisted argument
$m->get_ok("/Ticket/Display.html?id=1&Action=Take");
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Ticket/Display.html</tt>");
$m->content_contains("the Referrer header supplied by your browser (example.net:80) is not allowed");
$m->title_is('Possible cross-site request forgery');

$m->delete_header('Referer');
$m->follow_link(text_regex => qr{resume your request});
$m->content_lacks("Possible cross-site request forgery");
like($m->response->request->uri, qr{^http://[^/]+\Q/Ticket/Display.html});
$m->title_is('#1: bad music');
$m->content_contains('Owner changed from Nobody to root');

# force mech to never set referer
$m->add_header(Referer => undef);
$m->get_ok($test_page);
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Ticket/Create.html</tt>");
$m->content_contains("your browser did not supply a Referrer header");
$m->title_is('Possible cross-site request forgery');

$m->follow_link(text_regex => qr{resume your request});
$m->content_lacks("Possible cross-site request forgery");
is($m->response->redirects, 0, "no redirection");
like($m->response->request->uri, qr{^http://[^/]+\Q$test_path\E\?CSRF_Token=\w+$});
$m->title_is('Create a new ticket in General');

# try sending the wrong csrf token, then the right one
$m->add_header(Referer => undef);
$m->get_ok($test_page);
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Ticket/Create.html</tt>");
$m->content_contains("your browser did not supply a Referrer header");
$m->title_is('Possible cross-site request forgery');

# Sending a wrong CSRF is just a normal request.  We'll make a request
# with just an invalid token, which means no Queue=, which means
# Create.html errors out.
my $link = $m->find_link(text_regex => qr{resume your request});
(my $broken_url = $link->url) =~ s/(CSRF_Token)=\w+/$1=crud/;
$m->get($broken_url);
$m->content_like(qr/Queue\s+could not be loaded/);
$m->title_is('RT Error');
$m->warning_like(qr/Queue\s+could not be loaded/);

# The token doesn't work for other pages, or other arguments to the same page.
$m->add_header(Referer => undef);
$m->get_ok($test_page);
$m->content_contains("Possible cross-site request forgery");
my ($token) = $m->content =~ m{CSRF_Token=(\w+)};

$m->add_header(Referer => undef);
$m->get_ok("/Admin/Queues/Modify.html?id=new&Name=test&CSRF_Token=$token");
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Admin/Queues/Modify.html</tt>");
$m->content_contains("your browser did not supply a Referrer header");
$m->title_is('Possible cross-site request forgery');

$m->follow_link(text_regex => qr{resume your request});
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('Configuration for queue test');

# Try the same page, but different query parameters, which are blatted by the token
$m->get_ok("/Ticket/Create.html?Queue=$other_queue_id&CSRF_Token=$token");
$m->content_lacks("Possible cross-site request forgery");
$m->title_is('Create a new ticket in General');
$m->text_unlike(qr/Queue:\s*Other queue/);
$m->text_like(qr/Queue:\s*General/);

# Ensure that file uploads work across the interstitial
$m->delete_header('Referer');
$m->get_ok($test_page);
$m->content_contains("Create a new ticket in General", 'ticket create page');
$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');

my $logofile = "$RT::StaticPath/images/bpslogo.png";
open LOGO, "<", $logofile or die "Can't open logo file: $!";
binmode LOGO;
my $logo_contents = do {local $/; <LOGO>};
close LOGO;
$m->field('Attach',  $logofile);

# Lose the referer before the POST
$m->add_header(Referer => undef);
$m->submit;
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/Ticket/Create.html</tt>");
$m->follow_link(text_regex => qr{resume your request});
$m->content_contains('Download bpslogo.png', 'page has file name');
$m->follow_link_ok({text => "Download bpslogo.png"});
is($m->content, $logo_contents, "Binary content matches");


# now try self-service with CSRF
my $user = RT::User->new(RT->SystemUser);
$user->Create(Name => "SelfService", Password => "chops", Privileged => 0);

$m = RT::Test::Web->new;
$m->get_ok("$baseurl/index.html?user=SelfService&pass=chops");
$m->title_is("Open tickets", "got self-service interface");
$m->content_contains("My open tickets", "got self-service interface");

# post without referer
$m->add_header(Referer => undef);
$m->get_ok("/SelfService/Create.html?Queue=1");
$m->content_contains("Possible cross-site request forgery");
$m->content_contains("If you really intended to visit <tt>$baseurl/SelfService/Create.html</tt>");
$m->content_contains("your browser did not supply a Referrer header");
$m->title_is('Possible cross-site request forgery');

$m->follow_link(text_regex => qr{resume your request});
$m->content_lacks("Possible cross-site request forgery");
is($m->response->redirects, 0, "no redirection");
like($m->response->request->uri, qr{^http://[^/]+\Q/SelfService/Create.html\E\?CSRF_Token=\w+$});
$m->title_is('Create a ticket in #1');
$m->content_contains('Describe the issue below:');

done_testing;
