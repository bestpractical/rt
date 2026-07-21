use strict;
use warnings;
use JSON;

BEGIN { require './t/lifecycles/utils.pl' }

my ( $url, $m ) = RT::Test->started_ok( disable_config_cache => 1 );
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

# Use the pre-existing "sales" lifecycle to avoid racing the server's
# lifecycle cache.
my %valid = (
    type        => 'ticket',
    initial     => ['new'],
    active      => ['open'],
    inactive    => ['resolved'],
    defaults    => { on_create => 'new' },
    transitions => { '' => ['new'], new => ['open'], open => ['resolved'] },
);

# Parseable but invalid: a transition to a nonexistent status.
my %invalid = (
    %valid,
    transitions     => { '' => ['new'], new => [ 'open', 'ghoststatus' ], open => ['resolved'] },
    status_metadata => { open => { description => 'UNIQUERETAINMARKER42' } },
);

sub submit_lifecycle {
    my %fields = @_;

    $m->get_ok( '/Admin/Lifecycles/Modify.html?Name=sales&Type=ticket', 'Open lifecycle editor' );
    my $max_redirect = $m->max_redirect;
    $m->max_redirect(0);
    $m->submit_form(
        form_name => 'ModifyLifecycle',
        fields    => { Maps => '{}', %fields },
        button    => 'Update',
    );
    $m->max_redirect($max_redirect);
}

diag "Test that saving a lifecycle keeps Config out of the redirect URL";
submit_lifecycle( Config => JSON::encode_json( \%valid ) );
is( $m->status, 302, 'Save returns a redirect' );
unlike( $m->response->header('Location'), qr/Config=/, 'Redirect URL does not carry the Config payload' );

diag "Test that a save with validation errors renders inline and retains user input";
submit_lifecycle( Config => JSON::encode_json( \%invalid ) );
is( $m->status, 200, 'Validation failure renders inline instead of redirecting' );
$m->content_contains( 'UNIQUERETAINMARKER42', 'Submitted Config is retained in the editor after an error' );

diag "Test that a failed config save renders inline even when the layout saved";
submit_lifecycle(
    Config => JSON::encode_json( \%invalid ),
    Layout => JSON::encode_json( { nodes => [ { name => 'new', x => 1, y => 2 } ] } ),
);
is( $m->status, 200, 'A failed config save is not redirected even when the layout saved' );

diag "Test that a layout-only save redirects";
sub lifecycles_config_id {
    my $setting = RT::Configuration->new( RT->SystemUser );
    $setting->LoadByCols( Name => 'Lifecycles', Disabled => 0 );
    return $setting->Id;
}

# Any change to the stored Config replaces its Configuration record.
my $config_id = lifecycles_config_id();
RT->Config->RefreshConfigFromDatabase();
submit_lifecycle(
    Config => JSON::encode_json( RT->Config->Get('Lifecycles')->{sales} ),
    Layout => JSON::encode_json( { nodes => [ { name => 'new', x => 11, y => 22 } ] } ),
);
is( lifecycles_config_id(), $config_id, 'Submitted Config left the stored Config unchanged' );
is( $m->status, 302, 'Layout-only save returns a redirect' );

$m->get_ok( $m->response->header('Location'), 'Follow the post-save redirect' );
is_deeply(
    [ map { $_->text } $m->dom->find('ul.action-results li')->each ],
    ['Lifecycle layout updated'],
    'Layout-only save reports only the layout update'
);

sub submit_advanced {
    my ( $form, $button, %fields ) = @_;

    $m->get_ok( '/Admin/Lifecycles/Advanced.html?Name=sales&Type=ticket', 'Open advanced lifecycle editor' );
    my $max_redirect = $m->max_redirect;
    $m->max_redirect(0);
    $m->submit_form(
        form_name => $form,
        fields    => \%fields,
        button    => $button,
    );
    $m->max_redirect($max_redirect);
}

diag "Test that validating in the advanced editor renders inline and retains user input";
submit_advanced(
    'ModifyLifecycleAdvanced', 'Validate',
    Config => JSON::encode_json( { %valid, status_metadata => { open => { description => 'ADVANCEDVALIDATEMARKER' } } } ),
);
is( $m->status, 200, 'Validate renders inline instead of redirecting' );
$m->content_contains( 'ADVANCEDVALIDATEMARKER', 'Submitted Config is retained after validating' );

diag "Test that a failed save in the advanced editor renders inline";
submit_advanced( 'ModifyLifecycleAdvanced', 'Update', Config => JSON::encode_json( \%invalid ) );
is( $m->status, 200, 'Failed save renders inline instead of redirecting' );

diag "Test that validating mappings renders inline";
submit_advanced( 'ModifyLifecycleAdvancedMappings', 'ValidateMaps', Maps => '{}' );
is( $m->status, 200, 'Validate Mappings renders inline instead of redirecting' );

diag "Test that a failed mappings save renders inline";
submit_advanced(
    'ModifyLifecycleAdvancedMappings', 'UpdateMaps',
    Maps => JSON::encode_json( { 'sales -> nosuchlifecycle' => {} } ),
);
is( $m->status, 200, 'Failed mappings save renders inline instead of redirecting' );

done_testing;
