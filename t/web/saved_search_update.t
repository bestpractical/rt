
use strict;
use warnings;

use RT::Test tests => undef;

my $root = RT::User->new( $RT::SystemUser );
$root->Load('root');
my $uid = $root->id;
ok( $uid, 'loaded root' );

my $group = RT::Group->new( $RT::SystemUser );
my ($gid) = $group->CreateUserDefinedGroup( Name => 'foo' );
ok( $gid, 'created group foo');

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
    !( scalar grep { $_ eq "RT::Group-$gid" }
      $m->current_form->find_input('SavedSearchOwner')->possible_values ),
    'no group foo'
);

RT::Test->add_rights(
    {
        Principal => $root,
        Right     => [qw(ShowSavedSearches EditSavedSearches)],
        Object    => $group,
    },
);

$m->reload;
$m->form_name("BuildQuery");

ok(
    (
        scalar grep { $_ eq "RT::Group-$gid" }
          $m->current_form->find_input( 'SavedSearchOwner' )->possible_values
    ),
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

# save a group copy of saved search for later super user use
$m->select( SavedSearchOwner => "RT::Group-$gid" );
$m->field( SavedSearchDescription => 'copy saved' );
$m->click( "SavedSearchCopy" );
$m->form_name("BuildQuery");
is( $m->value( 'SavedSearchOwner' ), "RT::Group-$gid", "privacy is correct" );
is( $m->value( 'SavedSearchDescription' ), 'copy saved', "name is correct" );


$m->logout;


my $user_a = RT::Test->load_or_create_user( Name => 'user_a', Password => 'password', );
$uid = $user_a->id;
ok( $uid, 'loaded user_a' );

RT::Test->add_rights(
    {
        Principal => $user_a,
        Right     => [qw(CreateSavedSearch LoadSavedSearch ModifySelf)],
        Object    => RT->System,
    },
);

ok($m->login('user_a', 'password'), 'logged in');

$m->follow_link_ok( { text => "Tickets" }, "to query builder" );
$m->form_name( "BuildQuery" );

ok(
    !(
        grep { $_ eq "RT::Group-$gid" }
        $m->current_form->find_input( 'SavedSearchLoad' )->possible_values
    ),
    'no group foo in load'
);

ok(
    !(
        grep { $_ eq "RT::Group-$gid" }
        $m->current_form->find_input( 'SavedSearchOwner' )->possible_values
    ),
    'no group foo in save'
);

RT::Test->add_rights(
    {
        Principal => $user_a,
        Right     => [qw(ShowSavedSearches)],
        Object    => $group,
    },
);

$m->reload;
$m->form_name( "BuildQuery" );

ok(
    (
        scalar grep { /RT::Group-$gid/ }
          $m->current_form->find_input( 'SavedSearchLoad' )->possible_values
    ),
    'found group foo in load'
);

ok(
    !(
        scalar grep { $_ eq "RT::Group-$gid" }
        $m->current_form->find_input( 'SavedSearchOwner' )->possible_values
    ),
    'still no group foo in save'
);

RT::Test->add_rights(
    {
        Principal => $user_a,
        Right     => [qw(EditSavedSearches)],
        Object    => $group,
    },
);

$m->reload;
$m->form_name( "BuildQuery" );

ok(
    (
        scalar grep { /RT::Group-$gid/ }
          $m->current_form->find_input( 'SavedSearchLoad' )->possible_values
    ),
    'found group foo in load'
);

ok(
    (
        scalar grep { $_ eq "RT::Group-$gid" }
          $m->current_form->find_input( 'SavedSearchOwner' )->possible_values
    ),
    'also found group foo in save'
);

done_testing;
