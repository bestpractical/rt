use strict;
use warnings;
use HTTP::Cookies;

use RT::Test nodata => 1, tests => 31;
my ($baseurl, $agent) = RT::Test->started_ok;

# Create a user with basically no rights, to start.
my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer-'.$$.'@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer-'.$$);
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
ok($ret, "ACL test password set. $msg");

# Now test the web interface, making sure objects come and go as
# required.


my $cookie_jar = HTTP::Cookies->new;

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);

# get the top page
$agent->login( $user_obj->Name, 'customer');

# Test for absence of Configure and Preferences tabs.
ok(!$agent->find_link( url => "$RT::WebPath/Admin/",
                       text => 'Admin'), "No admin tab" );
ok(!$agent->find_link( url => "$RT::WebPath/User/Prefs.html",
                       text => 'Preferences'), "No prefs pane" );

# Now test for their presence, one at a time.  Sleep for a bit after
# ACL changes, thanks to the 10s ACL cache.
my ($grantid,$grantmsg) =$user_obj->PrincipalObj->GrantRight(Right => 'ShowConfigTab', Object => RT->System);

ok($grantid,$grantmsg);

$agent->reload;

$agent->content_contains('Logout', "Reloaded page successfully");
ok($agent->find_link( url => "$RT::WebPath/Admin/",
                       text => 'Admin'), "Found admin tab" );
my ($revokeid,$revokemsg) =$user_obj->PrincipalObj->RevokeRight(Right => 'ShowConfigTab');
ok ($revokeid,$revokemsg);
($grantid,$grantmsg) =$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
ok ($grantid,$grantmsg);
$agent->reload();
$agent->content_contains('Logout', "Reloaded page successfully");
ok($agent->find_link(
                       id => 'preferences-settings' ), "Found prefs pane" );
($revokeid,$revokemsg) = $user_obj->PrincipalObj->RevokeRight(Right => 'ModifySelf');
ok ($revokeid,$revokemsg);
# Good.  Now load the search page and test Load/Save Search.
$agent->follow_link( url => "$RT::WebPath/Search/Build.html",
                     text => 'Tickets');
is($agent->status, 200, "Fetched search builder page");
$agent->content_lacks("Load saved search", "No search loading box");
$agent->content_lacks("Saved searches", "No saved searches box");

($grantid,$grantmsg) = $user_obj->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
ok($grantid,$grantmsg);
$agent->reload();
$agent->content_contains("Load saved search", "Search loading box exists");
$agent->content_unlike(qr/input\s+type=['"]submit['"][^>]+name=['"]SavedSearchSave['"]/i,
   "Still no saved searches box");

($grantid,$grantmsg) =$user_obj->PrincipalObj->GrantRight(Right => 'CreateSavedSearch');
ok ($grantid,$grantmsg);
$agent->reload();
$agent->content_contains("Load saved search", "Search loading box still exists");
$agent->content_like(qr/input\s+type=['"]submit['"][^>]+name=['"]SavedSearchSave['"]/i,
   "Saved searches box exists");

# Create a group, and a queue, so we can test limited user visibility
# via SelectOwner.

my $queue_obj = RT::Queue->new(RT->SystemUser);
($ret, $msg) = $queue_obj->Create(Name => 'CustomerQueue-'.$$,
                                  Description => 'queue for SelectOwner testing');
ok($ret, "SelectOwner test queue creation. $msg");
my $group_obj = RT::Group->new(RT->SystemUser);
($ret, $msg) = $group_obj->CreateUserDefinedGroup(Name => 'CustomerGroup-'.$$,
                              Description => 'group for SelectOwner testing');
ok($ret, "SelectOwner test group creation. $msg");

# Add our customer to the customer group, and give it queue rights.
($ret, $msg) = $group_obj->AddMember($user_obj->PrincipalObj->Id());
ok($ret, "Added customer to its group. $msg");
($grantid,$grantmsg) =$group_obj->PrincipalObj->GrantRight(Right => 'OwnTicket',
                                     Object => $queue_obj);

ok($grantid,$grantmsg);
($grantid,$grantmsg) =$group_obj->PrincipalObj->GrantRight(Right => 'SeeQueue',
                                     Object => $queue_obj);
ok ($grantid,$grantmsg);
# Now.  When we look at the search page we should be able to see
# ourself in the list of possible owners.

$agent->reload();
ok($agent->form_name('BuildQuery'), "Yep, form is still there");
my $input = $agent->current_form->find_input('ValueOfActor');
ok(grep(/customer-$$/, $input->value_names()), "Found self in the actor listing");

