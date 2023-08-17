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
    fields    => { SavedSearchDescription => 'test' },
    button    => 'SavedSearchSave',
);
$m->content_contains( q{name="SavedSearchDescription" value="test"},
    'saved test search' );
my ($id) = $m->content =~ /value="(RT::User-\d+-SavedSearch-\d+)"/;
ok( $m->login( 'foo', 'foobar', logout => 1 ), 'logged in' );
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );

my $message = qq{Can not load saved search "$id"};
RT::Interface::Web::EscapeHTML( \$message );
$m->content_contains( $message, 'user foo can not load saved search of root' );

$m->warning_like( qr/User #\d+ tried to load container user #\d+/,
    'get warning' );

diag('Test RT System saved searches');
ok( $m->logout(), 'User foo logged out');
ok( $m->login(), 'root logged in' );
$m->get_ok( $url . '/Search/Build.html?Query=id<20' );
$m->submit_form(
    form_name => 'BuildQuery',
    fields    => { SavedSearchOwner => 'RT::System-1', SavedSearchDescription => 'Less than 20' },
    button    => 'SavedSearchSave',
);
$m->content_contains( q{name="SavedSearchDescription" value="Less than 20"}, 'Saved Less than 20 search' );
($id) = $m->content =~ /value="(RT::System-1-SavedSearch-\d+)"/;

ok( $m->login( 'foo', 'foobar', logout => 1 ), 'User foo logged in' );
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );

$message = qq{No permission to load search};
$m->content_contains( $message, 'user foo can not load RT System system-wide searches' );

# Grant rights to display the saved search interface on Query Builder
ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'CreateSavedSearch'),
    'Granted foo CreateSavedSearch');
ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'LoadSavedSearch'),
    'Granted foo LoadSavedSearch');
ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'ShowSavedSearches'),
    'Granted foo ShowSavedSearches');
$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );
$m->content_contains('Loaded saved search', 'User foo loaded RT System saved search' );

$m->get_ok( $url . "/Search/Build.html?SavedSearchLoad=$id" );
$m->content_lacks('name="SavedSearchSave"', 'Update button not shown to user foo' );
$m->content_lacks('name="SavedSearchDelete"', 'Delete button not shown to user foo' );

# Try to delete directly
$m->get_ok( $url . "/Search/Build.html?SavedSearchDelete=1&SavedSearchId=$id" );
$message = qq{No permission to delete search};
$m->content_contains( $message, 'user foo can not delete RT System saved search' );

ok($user->PrincipalObj->GrantRight(Object => RT->System, Right =>'EditSavedSearches'),
    'Granted foo EditSavedSearches');
$m->get_ok( $url . "/Search/Build.html?SavedSearchDelete=1&SavedSearchId=$id" );
$message = qq{Deleted saved search};
$m->content_contains( $message, 'user foo deleted RT saved search' );


done_testing;
