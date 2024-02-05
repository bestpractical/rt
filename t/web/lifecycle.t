use strict;
use warnings;

BEGIN { require './t/lifecycles/utils.pl' }

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

diag "Test lifecycle creation";

$m->get_ok('/Admin/Lifecycles/Create.html');
$m->submit_form_ok(
    {
        form_name => 'CreateLifecycle',
        fields    => { Name => ' foobar ', }, # Intentially add spaces to test the auto cleanup.
        button    => 'Create',
    },
    'Create lifecycle foobar'
);

$m->text_contains( 'foobar', 'Lifecycle foobar created' );

# Test if index page has it too
$m->follow_link_ok( { text => 'Select', url_regex => qr{/Admin/Lifecycles} } );
$m->follow_link_ok( { text => 'foobar' } );


# Test more updates


diag "Test lifecycle deletion";

$m->follow_link_ok( { url_regex => qr{/Admin/Lifecycles/Advanced.html} } );
$m->submit_form_ok(
    {
        form_name => 'ModifyLifecycleAdvanced',
        button    => 'Delete',
    },
    'Delete lifecycle foobar'
);

$m->text_contains('Lifecycle foobar deleted');
$m->follow_link_ok( { text => 'Select', url_regex => qr{/Admin/Lifecycles} } );
$m->text_lacks( 'foobar', 'foobar is gone' );

done_testing;
