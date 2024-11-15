
use strict;
use warnings;

use RT::Test tests => 17;

my $root = RT::User->new( $RT::SystemUser );
$root->Load('root');
my $uid = $root->id;
ok( $uid, 'loaded root' );

my $group = RT::Group->new( $RT::SystemUser );
my ($gid) = $group->CreateUserDefinedGroup( Name => 'foo' );
ok( $gid, 'created group foo');
ok( $group->AddMember( $root->PrincipalId ) );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok($m->login, 'logged in');

$m->follow_link_ok({text => "Tickets"}, "to query builder");

$m->form_name("BuildQuery");

$m->field(ValueOfid => 10 );
$m->click("AddClause");
$m->content_contains( 'id &lt; 10', "added new clause");

$m->form_name("BuildQuery");
$m->field(SavedSearchName => 'user_saved');
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchName'), 'user_saved', "name is correct");
like($m->value('SavedSearchOwner'), qr/^\d+$/, "owner is correct");
$m->field(SavedSearchName => 'group_saved');
$m->select(SavedSearchOwner => $gid);
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), $gid, "owner is correct");
is($m->value('SavedSearchName'), 'group_saved', "name is correct");
$m->select(SavedSearchOwner => $uid);
$m->field(SavedSearchName => 'user_saved');
$m->click("SavedSearchSave");


$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), $uid, "owner is correct");
is($m->value('SavedSearchName'), 'user_saved', "name is correct");
$m->select(SavedSearchOwner => RT->System->Id);
$m->field(SavedSearchName => 'system_saved');
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), 1, "owner is correct");
is($m->value('SavedSearchName'), 'system_saved', "name is correct");
