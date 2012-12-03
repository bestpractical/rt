use strict;
use warnings;

use RT::Test tests => 19;
my ($baseurl, $m) = RT::Test->started_ok;

my $url = $m->rt_base_url;

my $user_obj = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $user_obj->LoadOrCreateByEmail('customer@example.com');
ok($ret, 'ACL test user creation');
$user_obj->SetName('customer');
$user_obj->SetPrivileged(1);
($ret, $msg) = $user_obj->SetPassword('customer');
$user_obj->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'EditSavedSearches');
$user_obj->PrincipalObj->GrantRight(Right => 'CreateSavedSearch');
$user_obj->PrincipalObj->GrantRight(Right => 'ModifySelf');

ok $m->login( customer => 'customer' ), "logged in";

$m->get ( $url."Search/Build.html");

#create a saved search
$m->form_name ('BuildQuery');

$m->field ( "ValueOfAttachment" => 'stupid');
$m->field ( "SavedSearchDescription" => 'stupid tickets');
$m->click_button (name => 'SavedSearchSave');

$m->get ( $url.'Prefs/MyRT.html' );
$m->content_contains('stupid tickets', 'saved search listed in rt at a glance items');

ok $m->login('root', 'password', logout => 1), 'we did log in as root';

$m->get ( $url.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field ('body-Selected' => ['component-QuickCreate', 'system-Unowned Tickets', 'system-My Tickets']);
$m->click_button (name => 'remove');
$m->form_name ('SelectionBox-body');
#$m->click_button (name => 'body-Save');
$m->get ( $url );
$m->content_lacks ('highest priority tickets', 'remove everything from body pane');

$m->get ( $url.'Prefs/MyRT.html' );
$m->form_name ('SelectionBox-body');
$m->field ('body-Available' => ['component-QuickCreate', 'system-Unowned Tickets', 'system-My Tickets']);
$m->click_button (name => 'add');

$m->form_name ('SelectionBox-body');
$m->field ('body-Selected' => ['component-QuickCreate']);
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
$m->click_button (name => 'movedown');

$m->form_name ('SelectionBox-body');
#$m->click_button (name => 'body-Save');
$m->get ( $url );
$m->content_contains('highest priority tickets', 'adds them back');


#create a saved search with special chars
$m->get( $url . "Search/Build.html" );
$m->form_name('BuildQuery');
$m->field( "ValueOfAttachment"      => 'stupid' );
$m->field( "SavedSearchDescription" => 'special chars [test] [_1] ~[_1~]' );
$m->click_button( name => 'SavedSearchSave' );
my ($name) = $m->content =~ /value="(RT::User-\d+-SavedSearch-\d+)"/;
ok( $name, 'saved search name' );
$m->get( $url . 'Prefs/MyRT.html' );
$m->content_contains( 'special chars [test] [_1] ~[_1~]',
    'saved search listed in rt at a glance items' );

$m->get( $url . 'Prefs/MyRT.html' );
$m->form_name('SelectionBox-body');
$m->field(
    'body-Available' => [
        'component-QuickCreate',
        'system-Unowned Tickets',
        'system-My Tickets',
        'saved-' . $name,
    ]
);
$m->click_button( name => 'add' );

$m->get($url);
$m->content_like( qr/special chars \[test\] \d+ \[_1\]/,
    'special chars in titlebox' );


# Edit a system saved search to contain "[more]"
{
    my $search = RT::Attribute->new( RT->SystemUser );
    $search->LoadByNameAndObject( Name => 'Search - My Tickets', Object => RT->System );
    my ($id, $desc) = ($search->id, RT->SystemUser->loc($search->Description, '&#34;N&#34;'));
    ok $id, 'loaded search attribute';

    $m->get_ok($url);
    $m->follow_link_ok({ url_regex => qr"Prefs/Search\.html\?name=.+?Attribute-$id" }, 'Edit link');
    $m->content_contains($desc, "found description: $desc");

    ok +($search->SetDescription( $search->Description . " [more]" ));

    $m->get_ok($m->uri); # "reload_ok"
    $m->content_contains($desc . " [more]", "found description: $desc");
}

