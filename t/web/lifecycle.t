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

RT->Config->RefreshConfigFromDatabase();
RT::Lifecycle->FillCache;
my $lifecycle = RT::Lifecycle->new;
$lifecycle->Load(' foobar ');
ok( !$lifecycle->Name, 'Lifecycle " foo bar " does not exist' );
$lifecycle->Load('foobar');
is( $lifecycle->Name, 'foobar', 'Lifecycle name is corrected to "foobar"' );

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

$m->follow_link_ok( { text      => 'triage' } );
$m->follow_link_ok( { url_regex => qr{/Admin/Lifecycles/Advanced.html} } );
$m->submit_form_ok(
    {
        form_name => 'ModifyLifecycleAdvanced',
        button    => 'Delete',
    },
    'Delete lifecycle triage'
);
$m->text_like(
    qr/Lifecycle 'triage' deleted from database. To delete this lifecycle, you must also remove it from the following config file:.+RT_SiteConfig\.pm line \d+/,
    'Delete message'
);
my $configuration = RT::Configuration->new( RT->SystemUser );
$configuration->LoadByCols( Name => 'Lifecycles', Disabled => 0 );
ok( !$configuration->DecodedContent->{triage}, 'Lifecycle triage is indeed deleted from database' );
$m->follow_link_ok( { text => 'Select', url_regex => qr{/Admin/Lifecycles} } );
$m->text_contains( 'triage', 'Lifecycle triage still exists' );

done_testing;
