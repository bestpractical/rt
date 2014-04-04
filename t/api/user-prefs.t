
use strict;
use warnings;
use RT;
use RT::Test tests => undef;

use_ok( 'RT::User' );

my $create_user = RT::User->new(RT->SystemUser);
isa_ok($create_user, 'RT::User');
my ($ret, $msg) = $create_user->Create(Name => 'CreateTest1'.$$,
    EmailAddress => $$.'create-test-1@example.com');
ok ($ret, "Creating user CreateTest1 - " . $msg );

# Create object to operate as the test user
my $user1 = RT::User->new($create_user);
($ret, $msg) = $user1->Load($create_user->Id);
ok ($ret, "Loaded the new user $msg");

diag "Set a search preference";
my $prefs = {
     'Order' => 'DESC|ASC|ASC|ASC',
     'OrderBy' => 'Due',
     'Format' => '\'<a href="__WebPath__/Ticket/Display.html?id=__id__">__id__</a>/TITLE:#\',
\'<a href="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a>/TITLE:Subject\',
\'__Priority__\',
\'__QueueName__\',
\'__ExtendedStatus__\',
\'__Due__\'',
     'RowsPerPage' => '50'
};

ok (!$user1->HasRight( Right => 'ModifySelf', Object => $RT::System), "Can't ModifySelf");
($ret, $msg) = $user1->SetPreferences("SearchDisplay", $prefs);
ok( !$ret, "No permission to set preferences");
ok (($ret, $msg) = $create_user->PrincipalObj->GrantRight( Right => 'ModifySelf'),
    "Granted ModifySelf");
($ret, $msg) = $user1->SetPreferences("SearchDisplay", $prefs);
ok( $ret, "Search preference set");

diag "Fetch preference";
ok (my $saved_prefs = $user1->Preferences("SearchDisplay"), "Fetched prefs");
is ($prefs->{OrderBy}, 'Due', "Prefs look ok");

diag "Delete prefs";
ok (($ret, $msg) = $create_user->PrincipalObj->RevokeRight( Right => 'ModifySelf'),
    "Revoked ModifySelf");
($ret, $msg) = $user1->DeletePreferences("SearchDisplay");
ok( !$ret, "No permission to delete preferences");
ok (($ret, $msg) = $create_user->PrincipalObj->GrantRight( Right => 'ModifySelf'),
    "Granted ModifySelf");
($ret, $msg) = $user1->DeletePreferences("SearchDisplay");
ok( $ret, "Search preference deleted");

$saved_prefs = $user1->Preferences("SearchDisplay");
ok (!$saved_prefs, "No saved preferences returned");

done_testing;

