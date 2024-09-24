use strict;
use warnings;

use RT::Test tests => undef;
my $user = RT::User->new(RT->SystemUser);
ok(
    $user->Create(
        Name       => 'foo',
        Privileged => 1,
        Password   => 'foobar'
    )
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'root logged in' );
$m->get_ok( $url . '/Search/Build.html?Query=id<100' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchName => 'test' },
    button    => 'SavedSearchSave',
);
$m->content_contains( q{name="SavedSearchName" value="test"},
    'saved test search' );
my $id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[1];
ok( $m->login( 'foo', 'foobar', logout => 1 ), 'logged in' );
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );

my $message = q{No permission to load search};
$m->content_contains( $message, 'user foo can not load saved search of root' );

$m->warning_like( qr/User #\d+ does not have rights to load container user #\d+/, 'get warning' );

diag('Test RT System saved searches');
ok( $m->logout(), 'User foo logged out');
ok( $m->login(), 'root logged in' );
$m->get_ok( $url . '/Search/Build.html?Query=id<20' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchOwner => RT->System->Id, SavedSearchName => 'Less than 20' },
    button    => 'SavedSearchSave',
);
$id = ($m->form_number(3)->find_input('SavedSearchLoad')->possible_values)[3];
$m->content_contains( q{name="SavedSearchName" value="Less than 20"}, 'Saved Less than 20 search' );

ok( $m->login( 'foo', 'foobar', logout => 1 ), 'User foo logged in' );
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );

$m->content_lacks( $message, 'user foo can load RT System system-wide searches' );

# Grant rights to display the saved search interface on Query Builder
ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'LoadSavedSearch'),
    'Granted foo LoadSavedSearch');
ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'SeeSavedSearch'),
    'Granted foo SeeSavedSearch');
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );
$m->content_contains('Loaded saved search', 'User foo loaded RT System saved search' );

$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );
$m->content_lacks('name="SavedSearchSave"', 'Update button not shown to user foo' );
$m->content_lacks('name="SavedSearchDelete"', 'Delete button not shown to user foo' );

# Try to delete directly
$m->get_ok( $url . "/Search/Build.html?SavedSearchDelete=1&SavedSearchId=$id" );
$message = qq{No permission to delete search};
$m->content_contains( $message, 'user foo can not delete RT System saved search' );

ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'AdminSavedSearch'),
    'Granted foo AdminSavedSearch');
$m->get_ok( $url . "/Search/Build.html?SavedSearchDelete=1&SavedSearchId=$id" );
$message = qq{Deleted saved search};
$m->content_contains( $message, 'user foo deleted RT saved search' );


done_testing;
