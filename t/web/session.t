
use strict;
use warnings;

use RT::Test tests => undef;

plan skip_all => 'SQLite has shared file sessions' if RT->Config->Get('DatabaseType') eq 'SQLite';

# Web server hangs when processing the same session row after tied
# %session on Oracle with non-inline web servers :/
# Use file session instead for now.
if ( RT->Config->Get('DatabaseType') eq 'Oracle' && ( $ENV{'RT_TEST_WEB_HANDLER'} || '' ) ne 'inline' ) {
    RT->Config->Set( 'WebSessionClass', 'Apache::Session::File' );
}

my ($baseurl, $agent) = RT::Test->started_ok;
my $url = $agent->rt_base_url;

diag "Test server running at $baseurl";

# get the top page
{
    $agent->get($url);
    is ($agent->status, 200, "Loaded a page");
}

# test a login
{
    $agent->login('root' => 'password');
    # the field isn't named, so we have to click link 0
    is( $agent->status, 200, "Fetched the page ok");
    $agent->content_contains("Logout", "Found a logout link");
}

my ($session_id) = $agent->cookie_jar->as_string =~ /RT_SID_[^=]+=(\w+);/;

diag 'Load session for root user';
my %session;
RT::Interface::Web::Session::Load(
    Id => $session_id,
);

is ( $session{'_session_id'}, $session_id, 'Got session id ' . $session_id );
is ( $session{'CurrentUser'}->Name, 'root', 'Session is for root user' );

diag 'Test queues cache';
my $user_id = $session{'CurrentUser'}->Id;
ok ( $session{'SelectObject---RT::Queue---' . $user_id . '---CreateTicket---0'}, 'Queues cached for create ticket');
is ( $session{'SelectObject---RT::Queue---' . $user_id . '---CreateTicket---0'}{'objects'}->[0]{'Name'},
    'General', 'General queue is in cached list' );

my $last_updated = $session{'SelectObject---RT::Queue---' . $user_id . '---CreateTicket---0'}{'lastupdated'};
ok( $last_updated, "Got a lastupdated timestamp of $last_updated");

# Wait for 1 sec so we can confirm lastupdated doesn't change
sleep 1;
$agent->get($url);
is ($agent->status, 200, "Loaded a page");

RT::Interface::Web::Session::Load(
    Id => $session_id,
);

is ( $session{'_session_id'}, $session_id, 'Got session id ' . $session_id );
is ( $session{'CurrentUser'}->Name, 'root', 'Session is for root user' );
is ($last_updated, $session{'SelectObject---RT::Queue---' . $user_id . '---CreateTicket---0'}{'lastupdated'},
    "lastupdated is still $last_updated");

RT::Interface::Web::Session::Set(
    Key   => 'Testing',
    Value => 'TestValue',
);

is ( $session{'Testing'}, 'TestValue', 'Set a test value' );

RT::Interface::Web::Session::Load(
    Id => $session_id,
);

is ( $session{'Testing'}, 'TestValue', 'Test value still set after Load' );

RT::Interface::Web::Session::Delete(
    Key => 'Testing',
);

ok ( !(exists $session{'Testing'}), 'Test value deleted' );

RT::Interface::Web::Session::Load(
    Id => $session_id,
);

ok ( !(exists $session{'Testing'}), 'Test value still deleted after Load' );

diag 'Test logging out';

# Log in again first
ok ( $agent->logout(), 'Logged out' );
$agent->login('root' => 'password');
# the field isn't named, so we have to click link 0
is( $agent->status, 200, "Fetched the page ok");
$agent->content_contains("Logout", "Found a logout link");

my ($session_id2) = $agent->cookie_jar->as_string =~ /RT_SID_[^=]+=(\w+);/;

ok ( $agent->logout(), 'Logged out' );

RT::Interface::Web::Session::Load(
    Id => $session_id2,
);

isnt ( $session{'_session_id'}, $session_id, 'Got a new session id' );
ok ( !( exists $session{'CurrentUser'} ), 'New session is empty' );


done_testing;
