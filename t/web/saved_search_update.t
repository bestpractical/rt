
use strict;
use warnings;

use RT::Test tests => 18;

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
$m->field(SavedSearchDescription => 'user_saved');
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchDescription'), 'user_saved', "name is correct");
like($m->value('SavedSearchOwner'), qr/^RT::User-\d+$/, "name is correct");
ok(
    scalar grep { $_ eq "RT::Group-$gid" }
      $m->current_form->find_input('SavedSearchOwner')->possible_values,
    'found group foo'
);
$m->field(SavedSearchDescription => 'group_saved');
$m->select(SavedSearchOwner => "RT::Group-$gid");
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), "RT::Group-$gid", "privacy is correct");
is($m->value('SavedSearchDescription'), 'group_saved', "name is correct");
$m->select(SavedSearchOwner => "RT::User-$uid");
$m->field(SavedSearchDescription => 'user_saved');
$m->click("SavedSearchSave");


$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), "RT::User-$uid", "privacy is correct");
is($m->value('SavedSearchDescription'), 'user_saved', "name is correct");
$m->select(SavedSearchOwner => "RT::System-1");
$m->field(SavedSearchDescription => 'system_saved');
$m->click("SavedSearchSave");

$m->form_name("BuildQuery");
is($m->value('SavedSearchOwner'), "RT::System-1", "privacy is correct");
is($m->value('SavedSearchDescription'), 'system_saved', "name is correct");

