#!/usr/bin/perl -w

use WWW::Mechanize;
use HTTP::Cookies;

use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

# Create a user with basically no rights, to start.
my $user_obj = RT::User->new($RT::SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer-'.$$.'@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer-'.$$);
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
ok($ret, "ACL test password set. $msg");

# Now test the web interface, making sure objects come and go as
# required.

my $cookie_jar = HTTP::Cookies->new;
my $agent = WWW::Mechanize->new();

# give the agent a place to stash the cookies

$agent->cookie_jar($cookie_jar);


# get the top page
my $url = $RT::WebURL;
$agent->get($url);

is ($agent->{'status'}, 200, "Loaded a page - $RT::WebURL");
# {{{ test a login

# follow the link marked "Login"

ok($agent->{form}->find_input('user'));

ok($agent->{form}->find_input('pass'));
ok ($agent->{'content'} =~ /username:/i);
$agent->field( 'user' => 'customer-'.$$ );
$agent->field( 'pass' => 'customer' );
# the field isn't named, so we have to click link 0
$agent->click(0);
is($agent->{'status'}, 200, "Fetched the page ok");
ok($agent->{'content'} =~ /Logout/i, "Found a logout link");

# Test for absence of Configure and Preferences tabs.
ok(!$agent->find_link( url => "$RT::WebPath/Admin/",
		       text => 'Configuration'), "No config tab" );
ok(!$agent->find_link( url => "$RT::WebPath/User/Prefs.html",
		       text => 'Preferences'), "No prefs pane" );

# Now test for their presence, one at a time.  Sleep for a bit after
# ACL changes, thanks to the 10s ACL cache.
$user_obj->PrincipalObj->GrantRight(Right => 'ShowConfigTab');
$agent->reload();
ok($agent->{'content'} =~ /Logout/i, "Reloaded page successfully");
ok($agent->find_link( url => "$RT::WebPath/Admin/",
		       text => 'Configuration'), "Found config tab" );
$user_obj->PrincipalObj->RevokeRight(Right => 'ShowConfigTab');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');
$agent->reload();
ok($agent->{'content'} =~ /Logout/i, "Reloaded page successfully");
ok($agent->find_link( url => "$RT::WebPath/User/Prefs.html",
		       text => 'Preferences'), "Found prefs pane" );
$user_obj->PrincipalObj->RevokeRight(Right => 'ModifySelf');

# Good.  Now load the search page and test Load/Save Search.
$agent->follow_link( url => "$RT::WebPath/Search/Build.html",
		     text => 'Tickets');
is($agent->{'status'}, 200, "Fetched search builder page");
ok($agent->{'content'} !~ /Load saved search/i, "No search loading box");
ok($agent->{'content'} !~ /Saved searches/i, "No saved searches box");

$user_obj->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$agent->reload();
ok($agent->{'content'} =~ /Load saved search/i, "Search loading box exists");
ok($agent->{'content'} !~ /input\s+type=.submit.\s+name=.Save./i, 
   "Still no saved searches box");

$user_obj->PrincipalObj->GrantRight(Right => 'CreateSavedSearch');
$agent->reload();
ok($agent->{'content'} =~ /Load saved search/i, 
   "Search loading box still exists");
ok($agent->{'content'} =~ /input\s+type=.submit.\s+name=.Save./i, 
   "Saved searches box exists");

# Create a group, and a queue, so we can test limited user visibility
# via SelectOwner.

my $queue_obj = RT::Queue->new($RT::SystemUser);
($ret, $msg) = $queue_obj->Create(Name => 'CustomerQueue', 
				  Description => 'queue for SelectOwner testing');
ok($ret, "SelectOwner test queue creation. $msg");
my $group_obj = RT::Group->new($RT::SystemUser);
($ret, $msg) = $group_obj->CreateUserDefinedGroup(Name => 'CustomerGroup',
			      Description => 'group for SelectOwner testing');
ok($ret, "SelectOwner test group creation. $msg");

# Add our customer to the customer group, and give it queue rights.
($ret, $msg) = $group_obj->AddMember($user_obj->PrincipalObj->Id());
ok($ret, "Added customer to its group. $msg");
$group_obj->PrincipalObj->GrantRight(Right => 'OwnTicket',
				     Object => $queue_obj);
$group_obj->PrincipalObj->GrantRight(Right => 'SeeQueue',
				     Object => $queue_obj);

# Now.  When we look at the search page we should be able to see
# ourself in the list of possible owners.

$agent->reload();
ok($agent->form_name('BuildQuery'), "Yep, form is still there");
my $input = $agent->current_form->find_input('ValueOfActor');
ok(grep(/customer-$$/, $input->value_names()), "Found self in the actor listing");

1;
