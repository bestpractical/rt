use strict;
use warnings;

use HTTP::Status qw();
use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $onlooker = RT::User->new(RT->SystemUser);
($ret, $msg) = $onlooker->LoadOrCreateByEmail('onlooker@example.com');
ok($ret, 'ACL test user creation');
$onlooker->SetName('onlooker');
$onlooker->SetPrivileged(1);
($ret, $msg) = $onlooker->SetPassword('onlooker');

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);

for my $user ($user_obj, $onlooker) {
    for my $right (qw/ModifySelf SeeSavedSearch/) {
        $user->PrincipalObj->GrantRight(Right => $right);
    }
    for my $right (qw/SeeQueue ShowTicket OwnTicket/) {
        $user->PrincipalObj->GrantRight(Right => $right, Object => $queue);
    }
}

my %searches;
# Add some system non-ticket searches
ok $m->login('root'), "logged in as root";
$m->get_ok( $url . "/Search/Chart.html?Query=" . 'id=1' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName  => 'first chart',
        SavedSearchOwner       => RT->System->Id,
    },
    button => 'SavedSearchSave',
);

$m->content_contains("Chart first chart saved", 'saved first chart' );
my $search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'first chart'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Chart: first chart",
};

$m->get_ok( $url . "/Search/Build.html?Class=RT::Transactions&Query=" . 'TicketId=1' );

$m->submit_form(
    form_name => 'BuildQuery',
    fields    => {
        SavedSearchName  => 'first txn search',
        SavedSearchOwner => RT->System->Id,
    },
    button => 'SavedSearchSave',
);
# We don't show saved message on page :/
$m->content_contains("Save as New", 'saved first txn search' );

$search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'first txn search'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Transaction: first txn search",
};

ok $m->login(customer => 'customer', logout => 1), "logged in";

$m->get_ok($url."Dashboards/index.html");
$m->content_lacks('<a href="/Dashboards/Modify.html?Create=1">New</a>', 
                  "No 'new dashboard' link because we have no AdminOwnDashboard");

$m->no_warnings_ok;

$m->get($url."Dashboards/Modify.html?Create=1");
is($m->status, HTTP::Status::HTTP_FORBIDDEN);
$m->content_contains("Permission Denied");
$m->content_lacks("Save Changes");

$m->warning_like(qr/Permission Denied/, "got a permission denied warning");


$user_obj->PrincipalObj->GrantRight(Right => 'AdminOwnDashboard', Object => $RT::System);

$m->get_ok($url."Dashboards/Modify.html?Create=1");
$m->text_lacks("Permission Denied");
$m->content_contains("Create");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("New", "'New' link because we now have AdminOwnDashboard");
$m->follow_link_ok({ id => 'reports-reports-dashboard_create'});
$m->form_name('ModifyDashboard');
$m->field("Name" => 'different dashboard');
$m->click_button(value => 'Create');
$m->content_contains("Dashboard created");
$user_obj->PrincipalObj->GrantRight(Right => 'SeeOwnDashboard', Object => $RT::System);
$m->get($url."Dashboards/index.html");
$m->follow_link_ok({ text => 'different dashboard'});
$m->text_lacks("Permission Denied", "we now have SeeOwnDashboard");

$m->get_ok($url."Dashboards/index.html");
$m->content_contains("different dashboard", "we now have SeeOwnDashboard");
$m->text_lacks("Permission Denied");

$m->follow_link_ok({text => "different dashboard"});
$m->content_contains("Basics");
$m->content_contains("Content");
$m->content_lacks("Subscription", "we don't have the SubscribeDashboard right");

$m->follow_link_ok({text => "Basics"});
$m->content_contains("Modify the dashboard different dashboard");

# add 'Unowned Tickets' to body of 'different dashboard' dashboard
$m->follow_link_ok({text => "Content"});
$m->content_contains("Modify the content of dashboard different dashboard");

my ( $id ) = ( $m->uri =~ /id=(\d+)/ );
ok( $id, "got a dashboard ID, $id" );  # 8

for my $search_name ( 'My Tickets', 'Unowned Tickets', 'Bookmarked Tickets' ) {
    my $search = RT::SavedSearch->new(RT->SystemUser);
    $search->LoadByCols( Name => $search_name );
    $searches{$search_name} = {
        portlet_type => 'search',
        id           => $search->Id,
        description  => "Ticket: $search_name",
    };
}

my $content = [
    {
        Layout   => 'col-md-8, col-md-4',
        Elements => [ [ $searches{'Unowned Tickets'} ], [], ],
    }
];
my $res = $m->post(
    $url . "Dashboards/Queries.html?id=$id",
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, "add 'unowned tickets' to body" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

my $dashboard = RT::Dashboard->new($currentuser);
$dashboard->LoadById($id);
is($dashboard->Name, 'different dashboard', "'different dashboard' name is correct");

is($dashboard->PrincipalId, $user_obj->Id, "correct privacy");
is($dashboard->PossibleHiddenSearches, 0, "all searches are visible");

my @searches = $dashboard->Searches;
is(@searches, 1, "one saved search in the dashboard");
like($searches[0]->Name, qr/Unowned Tickets/, "correct search name");

push @{ $content->[0]{Elements}[0] }, map { $searches{$_} } 'My Tickets', 'first chart', 'first txn search';

$res = $m->post(
    $url . 'Dashboards/Queries.html?id=' . $id,
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, "add more searches to body" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$dashboard->LoadById($id);
@searches = $dashboard->Searches;

is(@searches, 4, "4 saved searches in the dashboard");
like($searches[0]->Name, qr/Unowned Tickets/, "correct existing search name");
like($searches[1]->Name, qr/My Tickets/, "correct new search name");
is($searches[2]->Name, 'first chart',      "correct existing search name");
is($searches[3]->Name, 'first txn search', "correct new search name");

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Create(
    Queue     => $queue->Id,
    Requestor => [ $user_obj->Name ],
    Owner     => $user_obj,
    Subject   => 'dashboard test',
);

$m->get_ok($url."Dashboards/index.html");
$m->follow_link_ok({text => "different dashboard"});
$m->follow_link_ok({id => 'page-show'});
$m->content_contains("50 highest priority tickets I own");
$m->content_contains("50 newest unowned tickets");
$m->content_contains("first chart");
$m->content_contains("first txn search");
$m->content_unlike( qr/Bookmarked Tickets.*Bookmarked Tickets/s,
    'only dashboard queries show up' );
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/$id/This fragment left intentionally blank");
$m->content_contains("50 highest priority tickets I own");
$m->content_contains("50 newest unowned tickets");
$m->content_unlike( qr/Bookmarked Tickets.*Bookmarked Tickets/s,
    'only dashboard queries show up' );
$m->content_contains("dashboard test", "ticket subject");

$m->get_ok("/Dashboards/Modify.html?id=$id");

$m->form_name('ModifyDashboard');
$m->untick('Enabled', 1);
$m->submit_form( button => 'Save' );
$m->text_contains(q{Disabled changed from (no value) to "1"});

$user_obj->PrincipalObj->GrantRight(Right => "SuperUser", Object => $RT::System);

# now test that we warn about searches others can't see
# first create a personal saved search...
$m->get_ok($url."Search/Build.html");
$m->follow_link_ok({text => 'Advanced'});
$m->form_with_fields('Query');
$m->field(Query => "id > 0");
$m->submit;

$m->form_with_fields('SavedSearchDescription');
$m->field(SavedSearchName => "personal search");
$m->click_button(name => "SavedSearchSave");

# get the saved search name from the content
$search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'personal search'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Ticket: personal search",
};

# then the system-wide dashboard
$m->get_ok($url."Dashboards/Modify.html?Create=1");

$m->form_name('ModifyDashboard');
$m->field("Name" => 'system dashboard');
$m->field("PrincipalId" => RT->System->Id);
$m->content_lacks('Delete', "Delete button hidden because we are creating");
$m->click_button(value => 'Create');
$m->content_lacks("No permission to create dashboards");
$m->content_contains("Dashboard created");

$m->follow_link_ok({id => 'page-content'});

my ( $system_id ) = ( $m->uri =~ /id=(\d+)/ );
ok( $system_id, "got a dashboard ID for the system dashboard, $system_id" );

push(
    @{ $content->[0]{Elements}[0] },
    $searches{'personal search'},
);

$res = $m->post(
    $url . "Dashboards/Queries.html?id=$system_id",
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, "add 'personal search' to body" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->get_ok($url."Dashboards/Queries.html?id=$system_id");
$m->content_contains("Warning: may not be visible to all viewers");

$m->follow_link_ok({id => 'page-show'});
$m->content_contains("personal search", "saved search shows up");
$m->content_contains("dashboard test", "matched ticket shows up");

# make sure the onlooker can't see the search...
$onlooker->PrincipalObj->GrantRight(Right => 'SeeDashboard', Object => $RT::System);

my $omech = RT::Test::Web->new;
ok $omech->login(onlooker => 'onlooker'), "logged in";
$omech->get_ok("/Dashboards");

$omech->follow_link_ok({text => 'system dashboard'});
$omech->content_lacks("personal search", "saved search doesn't show up");
$omech->content_lacks("dashboard test", "matched ticket doesn't show up");

$omech->warning_like(qr/User .* does not have rights to load container user/, "can't see other users' personal searches");

# make sure that navigating to dashboard pages with bad IDs throws an error
my $bad_id = $system_id + 1;

for my $page (qw/Modify Queries Render Subscription/) {
    $m->get("/Dashboards/$page.html?id=$bad_id");
    $m->content_like(qr/Could not load dashboard $bad_id/);
    $m->next_warning_like(qr/Unable to load dashboard with $bad_id/);
    $m->next_warning_like(qr/Could not load dashboard $bad_id/);
}

done_testing();
