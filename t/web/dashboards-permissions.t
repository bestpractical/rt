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
    for qw/SubscribeDashboard CreateOwnDashboard SeeOwnDashboard ModifyOwnDashboard DeleteOwnDashboard/;

ok $m->login(customer => 'customer'), "logged in";

$m->follow_link_ok( {id => 'home-dashboard_create'});
$m->form_name('ModifyDashboard');
is_deeply([$m->current_form->find_input('Privacy')->possible_values], ["RT::User-" . $user_obj->Id], "the only selectable privacy is user");
$m->content_lacks('Delete', "Delete button hidden because we are creating");

diag 'Test group dashboard create rights';

my $user2 = RT::Test->load_or_create_user(
    Name => 'user2', Password => 'password', Privileged => 1
);
ok $user2 && $user2->id, 'loaded or created user';

my $group1 = RT::Test->load_or_create_group(
    'Group1',
    Members => [$user2],
);

ok $m->logout(), "Logged out";
ok $m->login( 'user2' => 'password' ), "logged in";

$m->content_contains('All Dashboards', 'All Dashboards menu item found' );
$m->content_lacks('New Dashboard', 'New Dashboard menu correctly not found');

$group1->PrincipalObj->GrantRight(Right => $_, Object => $group1)
    for qw/SeeGroup CreateGroupDashboard/;

$m->get_ok('/', 'Reloaded home page');

$m->content_contains('All Dashboards', 'All Dashboards menu item found' );
$m->content_contains('New Dashboard', 'New Dashboard link found via group rights');

done_testing();
