use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

# create user and queue {{{
my $user_obj = RT::User->new(RT->SystemUser);
my ($ok, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ok, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ok, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
my $currentuser = RT::CurrentUser->new($user_obj);

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);

$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $queue)
    for qw/SeeQueue ShowTicket OwnTicket/;

$user_obj->PrincipalObj->GrantRight(Right => $_, Object => $RT::System)
    for qw/SubscribeDashboard AdminOwnDashboard SeeOwnDashboard/;

ok $m->login(customer => 'customer'), "logged in";


$m->follow_link_ok( {id => 'reports-reports-dashboard_create'});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('PrincipalId')->possible_values], [$user_obj->Id], "the only selectable privacy is user");
$m->content_lacks('Delete', "Delete button hidden because we are creating");

diag 'A dashboard is named on the saved search it uses only to those who may see it';

my $alice = RT::Test->load_or_create_user( Name => 'alice', Password => 'password' );
my $bob   = RT::Test->load_or_create_user( Name => 'bob',   Password => 'password' );

RT::Test->add_rights(
    {   Principal => 'Privileged',
        Right     => [
            qw/LoadSavedSearch SeeSavedSearch AdminOwnSavedSearch
                SeeOwnDashboard AdminOwnDashboard/
        ],
    },
);

diag 'A system saved search, used by a personal dashboard of bob and a system one';

my $search = RT::SavedSearch->new( RT->SystemUser );
( $ok, $msg ) = $search->Create(
    Name        => 'Shared tickets',
    Type        => 'Ticket',
    PrincipalId => RT->System->Id,
    Content     => {
        Query       => "Status = 'new'",
        Format      => q{'<b><a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a></b>/TITLE:#'},
        OrderBy     => 'id',
        Order       => 'ASC',
        RowsPerPage => 50,
    },
);
ok( $ok, "created a system saved search: $msg" );

my $content = { Elements => [ { portlet_type => 'search', id => $search->id } ] };

my $personal = RT::Dashboard->new( RT::CurrentUser->new($bob) );
( $ok, $msg ) = $personal->Create(
    Name        => 'Bob confidential dashboard',
    PrincipalId => $bob->Id,
    Content     => $content,
);
ok( $ok, "created a personal dashboard for bob: $msg" );

my $global = RT::Dashboard->new( RT->SystemUser );
( $ok, $msg ) = $global->Create(
    Name        => 'Company wide dashboard',
    PrincipalId => RT->System->Id,
    Content     => $content,
);
ok( $ok, "created a system dashboard: $msg" );

is( $search->DependedOnBy->Count, 2, 'both dashboards depend on the saved search' );

my $search_url = $url . 'Search/Build.html?SavedSearchLoad=' . $search->id;

diag 'alice may see neither dashboard';

my $alice_m = RT::Test::Web->new;
ok( $alice_m->login( 'alice', 'password' ), 'logged in as alice' );

$alice_m->get_ok($search_url);
$alice_m->content_contains( 'Shared tickets',                     'alice loaded the saved search' );
$alice_m->content_contains( 'used in the following 2 dashboards', 'alice is told how many depend on it' );

$alice_m->content_lacks( 'Bob confidential dashboard',        'personal dashboard name is not shown' );
$alice_m->content_lacks( 'Company wide dashboard',            'system dashboard name is not shown' );
$alice_m->content_lacks( 'Dashboards/' . $personal->id . '/', 'personal dashboard is not linked' );
$alice_m->content_lacks( 'Dashboards/' . $global->id . '/',   'system dashboard is not linked' );
$alice_m->content_contains( 'Dashboard #' . $personal->id, 'personal dashboard is listed by id' );
$alice_m->content_contains( 'Dashboard #' . $global->id,   'system dashboard is listed by id' );

# The visible rendering is "Dashboard #17: Some name", so a bare id is the one
# without a colon after it.
$alice_m->content_lacks( 'Dashboard #' . $personal->id . ':', 'the personal id carries no name' );
$alice_m->content_lacks( 'Dashboard #' . $global->id . ':',   'the system id carries no name' );

$alice_m->next_warning_like( qr/tried to load container user/, 'refusing the personal dashboard is logged' );
$alice_m->next_warning_like( qr/tried to load container user/, 'the list is rendered twice, so it is logged twice' );

diag 'SeeDashboard gets alice the system dashboard, and only that one';

RT::Test->add_rights( { Principal => 'Privileged', Right => ['SeeDashboard'] } );

$alice_m->get_ok($search_url);
$alice_m->content_contains( 'Dashboard #' . $global->id . ': Company wide dashboard',
    'system dashboard is named after its id' );
$alice_m->content_contains( 'Dashboards/' . $global->id . '/', 'system dashboard is linked' );

$alice_m->content_lacks( 'Bob confidential dashboard',        'personal dashboard name is still not shown' );
$alice_m->content_lacks( 'Dashboards/' . $personal->id . '/', 'personal dashboard is still not linked' );
$alice_m->content_contains( 'Dashboard #' . $personal->id, 'personal dashboard is still listed by id' );
$alice_m->content_lacks( 'Dashboard #' . $personal->id . ':', 'and still carries no name' );

$alice_m->next_warning_like( qr/tried to load container user/, 'refusing the personal dashboard is logged' );
$alice_m->next_warning_like( qr/tried to load container user/, 'the list is rendered twice, so it is logged twice' );

diag 'bob sees his own dashboard';

my $bob_m = RT::Test::Web->new;
ok( $bob_m->login( 'bob', 'password' ), 'logged in as bob' );

$bob_m->get_ok($search_url);
$bob_m->content_contains( 'Bob confidential dashboard',        'personal dashboard name is shown' );
$bob_m->content_contains( 'Dashboards/' . $personal->id . '/', 'personal dashboard is linked' );

diag 'Only dashboards belong in the list, so anything else is skipped';

my $ticket = RT::Test->create_ticket(
    Queue   => $queue->Name,
    Subject => 'Confidential ticket subject',
);
( $ok, $msg ) = $ticket->AddLink( Type => 'DependsOn', Target => 'savedsearch:' . $search->id );
ok( $ok, "linked a ticket to the saved search: $msg" );

is( $search->DependedOnBy->Count, 3, 'the ticket depends on the search too' );

$alice_m->get_ok($search_url);
$alice_m->content_lacks( 'Confidential ticket subject',              'the ticket is not named' );
$alice_m->content_lacks( 'Ticket/Display.html?id=' . $ticket->id,    'nor linked' );
$alice_m->content_contains( 'Dashboard #' . $personal->id, 'and the dashboards are listed as before' );

$alice_m->next_warning_like( qr/tried to load container user/, 'refusing the personal dashboard is logged' );
$alice_m->next_warning_like( qr/tried to load container user/, 'the list is rendered twice, so it is logged twice' );

diag 'The guard is on the record, so a dashboard linked from a ticket is unnamed too';

RT::Test->add_rights(
    { Principal => 'Privileged', Right => [qw/SeeQueue ShowTicket/], Object => $queue } );

( $ok, $msg ) = $ticket->AddLink( Type => 'RefersTo', Target => 'dashboard:' . $personal->id );
ok( $ok, "linked the ticket to bob's dashboard: $msg" );

my $links_url = $url . 'Views/Component/ShowLinks?ObjectType=RT::Ticket&ObjectId=' . $ticket->id;

$alice_m->get_ok($links_url);
$alice_m->content_contains( 'Dashboard #' . $personal->id, 'the dashboard is listed among the links' );
$alice_m->content_lacks( 'Bob confidential dashboard', 'but alice may not see it, so it is not named' );
$alice_m->content_lacks( 'Dashboard #' . $personal->id . ':', 'and the id carries no name' );

# Unlike the dependency list above, the generic link renderer still offers the
# link, the same way it does for an unreadable ticket.
$alice_m->content_contains( 'Dashboards/' . $personal->id . '/', 'the link itself is not hidden here' );

# ShowLinks reads the dashboard once per relation row it considers, and each
# refusal is logged.
$alice_m->next_warning_like( qr/tried to load container user/, 'refusing the personal dashboard is logged' )
    for 1 .. 7;

$bob_m->get_ok($links_url);
$bob_m->content_contains( 'Bob confidential dashboard', 'bob sees his own dashboard named' );

diag 'A dashboard alice may not see is listed in her menu by id, and linked by id alone';

( $ok, $msg ) = $alice->SetPreferences( 'DashboardsInMenu',
    { dashboards => [ $personal->id, $global->id ] } );
ok( $ok, "put both dashboards in alice's menu: $msg" );

# The menu is read once per session, so alice needs a new one.
my $menu_m = RT::Test::Web->new;
ok( $menu_m->login( 'alice', 'password' ), 'logged in as alice again' );

$menu_m->get_ok($url);
$menu_m->content_contains( 'Company wide dashboard', 'the dashboard alice may see is in her menu' );
$menu_m->content_contains( 'Dashboard #' . $personal->id, "bob's is in her menu too, by id" );
$menu_m->content_lacks( 'Bob confidential dashboard', 'but not named' );
$menu_m->content_contains( 'Dashboards/' . $personal->id . '"', 'and linked by id alone' );
$menu_m->content_lacks( 'Dashboards/' . $personal->id . '/', 'with no name in the path' );

# The menu is rebuilt on every page, and logging in lands on more than one.
$menu_m->next_warning_like( qr/tried to load container user/, "refusing bob's dashboard is logged" )
    for 1 .. 6;

done_testing;
