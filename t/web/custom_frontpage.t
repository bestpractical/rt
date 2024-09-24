use strict;
use warnings;

use RT::Test tests => undef;
use JSON;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'AdminSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
$user_obj->PrincipalObj->GrantRight(Right => 'SeeDashboard');
$user_obj->PrincipalObj->GrantRight(Right => 'SeeOwnDashboard');
$user_obj->PrincipalObj->GrantRight(Right => 'AdminOwnDashboard');

ok $m->login( customer => 'customer' ), "logged in";

$m->get ( $url."Search/Build.html");

#create a saved search
$m->form_name ('BuildQuery');

$m->field ( "ValueOfAttachment" => 'stupid');
$m->field ( "SavedSearchName" => 'stupid tickets');
$m->click_button (name => 'SavedSearchSave');

$m->get_ok( $url . "Dashboards/Modify.html?Create=1" );
$m->form_name('ModifyDashboard');
$m->field( Name => 'My homepage' );
$m->click_button( value => 'Create' );

$m->follow_link_ok( { text => 'Content' } );
$m->content_contains('stupid tickets', 'saved search listed in rt at a glance items');

ok $m->login('root', 'password', logout => 1), 'we did log in as root';

$m->get_ok( $url . "Dashboards/Modify.html?Create=1" );
$m->form_name('ModifyDashboard');
$m->field( Name => 'My homepage' );
$m->click_button( value => 'Create' );

my ($id) = ( $m->uri =~ /id=(\d+)/ );
ok( $id, "got a dashboard ID, $id" );

my %searches;
for my $search_name ( 'My Tickets', 'Unowned Tickets', 'Bookmarked Tickets' ) {
    my $search = RT::SavedSearch->new( RT->SystemUser );
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

# remove all portlets from the body pane except 'newest unowned tickets'
$m->follow_link_ok( { text => 'Content' } );

my $res = $m->post(
    $url . "Dashboards/Queries.html?id=$id",
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, "remove all portlets from body except 'newest unowned tickets'" );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->get_ok( $url . 'Prefs/MyRT.html' );
$m->submit_form_ok(
    {   form_name => 'UpdateDefaultDashboard',
        button    => "DefaultDashboard-$id",
    },
);

$m->content_contains( 'Preferences saved' );

$m->get( $url );
$m->content_contains( 'newest unowned tickets', "'newest unowned tickets' is present" );
$m->content_lacks( 'highest priority tickets', "'highest priority tickets' is not present" );
$m->content_unlike( qr/id="body".*Bookmarked Tickets/s, "'Bookmarked Tickets' is not present" );  # 'Bookmarked Tickets' also shows up in the nav, so we need to be more specific
$m->content_lacks( 'Quick ticket creation', "'Quick ticket creation' is not present" );

$m->get_ok( $url . "Dashboards/Queries.html?id=$id" );

# add back the previously removed portlets
push(
    @{$content->[0]{Elements}[0]},
    $searches{'My Tickets'},
    $searches{'Bookmarked Tickets'},
    {
        portlet_type => 'component',
        component    => 'QuickCreate',
        description  => 'QuickCreate',
        path         => '/Elements/QuickCreate',

    }
);

push(
    @{$content->[0]{Elements}[1]},
    map {
        portlet_type => 'component',
        component    => $_,
        description  => $_,
        path         => "/Elements/$_",
    },
    qw/MyReminders QueueList Dashboards RefreshHomepage/
);

$res = $m->post(
    $url . "Dashboards/Queries.html?id=$id",
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, 'add back previously removed portlets' );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->get( $url );
$m->content_contains( 'newest unowned tickets', "'newest unowned tickets' is present" );
$m->content_contains( 'highest priority tickets', "'highest priority tickets' is present" );
$m->content_like( qr/id="body".*Bookmarked Tickets/s, "'Bookmarked Tickets' is present" );
$m->content_contains( 'Quick ticket creation', "'Quick ticket creation' is present" );

#create a saved search with special chars
$m->get( $url . "Search/Build.html" );
$m->form_name('BuildQuery');
$m->field( "ValueOfAttachment" => 'stupid' );
$m->field( "SavedSearchName"   => 'special chars [test] [_1] ~[_1~]' );
$m->click_button( name => 'SavedSearchSave' );

my $search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];

$m->get_ok( $url . "Dashboards/Queries.html?id=$id" );
$m->content_contains( 'special chars [test] [_1] ~[_1~]',
    'saved search listed in rt at a glance items' );

# add saved search to body
push(
    @{$content->[0]{Elements}[0]},
    {
        portlet_type => 'search',
        id           => $search_id,
        description  => "Ticket: special chars [test] [_1] ~[_1~]",
    }
);

$res = $m->post(
    $url . "Dashboards/Queries.html?id=$id",
    { Update => 1, Content => JSON::encode_json($content) },
);


is( $res->code, 200, 'add saved search to body' );
like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->get($url);
$m->content_like( qr/special chars \[test\] \d+ \[_1\]/,
    'special chars in titlebox' );

# Edit a system saved search to contain "[more]"
{
    my $search = RT::SavedSearch->new( RT->SystemUser );
    $search->LoadByCols( Name => 'My Tickets' );
    my ($id, $name) = ($search->id, $search->Name);
    ok $id, 'loaded search';

    $m->get_ok($url);
    $m->follow_link_ok({ url_regex => qr"Prefs/Search\.html\?id=$id" }, 'Edit link');
    $m->content_contains($name, "found name: $name");

    ok +($search->SetName( $search->Name . " [more]" ));

    $m->get_ok($m->uri); # "reload_ok"
    $m->content_contains($name . " [more]", "found name: $name [more]");
}

# Add some system non-ticket searches
$m->get_ok( $url . "/Search/Chart.html?Query=" . 'id=1' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName  => 'first chart',
        SavedSearchOwner => RT->System->Id,
    },
    button => 'SavedSearchSave',
);
$m->content_contains("Chart first chart saved", 'saved first chart' );
$search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];
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

$m->get_ok( $url . "/Search/Chart.html?Class=RT::Transactions&Query=" . 'id>1' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName  => 'first txn chart',
        SavedSearchOwner => RT->System->Id,
    },
    button => 'SavedSearchSave',
);
$m->content_contains("Chart first txn chart saved", 'saved first txn chart' );

$search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'first txn chart'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Chart: first txn chart",
};

# Add asset saved searches
$m->get_ok( $url . "/Search/Build.html?Class=RT::Assets&Query=" . 'id>0' );

$m->submit_form(
    form_name => 'BuildQuery',
    fields    => {
        SavedSearchName  => 'first asset search',
        SavedSearchOwner => RT->System->Id,
    },
    button => 'SavedSearchSave',
);
# We don't show saved message on page :/
$m->content_contains("Save as New", 'saved first asset search' );

$search_id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'first asset search'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Asset: first asset search",
};

$m->get_ok( $url . "/Search/Chart.html?Class=RT::Assets&Query=" . 'id>0' );

$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName  => 'first asset chart',
        SavedSearchOwner => RT->System->Id,
    },
    button => 'SavedSearchSave',
);
$m->content_contains("Chart first asset chart saved", 'saved first txn chart' );
$search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];
$searches{'first asset chart'} = {
    portlet_type => 'search',
    id           => $search_id,
    description  => "Asset: first asset chart",
};


$m->get_ok( $url . "Dashboards/Queries.html?id=$id" );
push(
    @{ $content->[0]{Elements}[0] },
    map { $searches{$_} } 'first chart',
    'first txn search',
    'first txn chart',
    'first asset search',
    'first asset chart'
);

$res = $m->post(
    $url . "Dashboards/Queries.html?id=$id",
    { Update => 1, Content => JSON::encode_json($content) },
);

is( $res->code, 200, 'add system saved searches to body' );
$m->content_contains( 'Dashboard updated' );

$m->get_ok($url);
$m->text_contains('first chart');
$m->text_contains('first txn search');
$m->text_contains('first txn chart');
$m->text_contains('Transaction count', 'txn chart content');
$m->text_contains('first asset search');
$m->text_contains('first asset chart');
$m->text_contains('Asset count', 'asset chart content');

done_testing;
