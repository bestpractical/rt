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

diag "Test that saving a large lifecycle keeps Config out of the redirect URL";
{
    # A large Config in the post-save redirect URL would overflow the web
    # server's buffers (414). Use the pre-existing "sales" lifecycle to avoid
    # racing the server's lifecycle cache.
    my %config = (
        type     => 'ticket',
        initial  => ['new'],
        active   => [ map {"active$_"} 1 .. 60 ],
        inactive => ['resolved'],
        defaults => { on_create => 'new' },
        transitions => {
            ''  => ['new'],
            new => [ map {"active$_"} 1 .. 60 ],
            map { ( "active$_" => ['resolved'] ) } 1 .. 60,
        },
        status_metadata =>
            { map { ( "active$_" => { description => "Active status number $_ with a long descriptive sentence." } ) } 1 .. 60 },
    );
    my $config_json = JSON::encode_json( \%config );
    ok( length($config_json) > 5000, 'Config JSON is large (' . length($config_json) . ' bytes)' );

    $m->get_ok( '/Admin/Lifecycles/Modify.html?Name=sales&Type=ticket', 'Open lifecycle editor' );

    my $max_redirect = $m->max_redirect;
    $m->max_redirect(0);
    $m->submit_form(
        form_name => 'ModifyLifecycle',
        fields    => { Config => $config_json, Maps => '{}' },
        button    => 'Update',
    );
    is( $m->status, 302, 'Save returns a redirect' );
    my $location = $m->response->header('Location') // '';
    unlike( $location, qr/Config=/, 'Redirect URL does not carry the Config payload' );
    unlike( $location, qr/active60/, 'Redirect URL does not contain lifecycle status data' );
    $m->max_redirect($max_redirect);

    $m->get_ok( $location, 'Follow the post-save redirect' );
    $m->text_contains( 'Lifecycle updated', 'Lifecycle updated message shown after redirect' );

    RT->Config->RefreshConfigFromDatabase();
    my $reloaded = RT->Config->Get('Lifecycles')->{sales};
    ok( ( grep { $_ eq 'active60' } @{ $reloaded->{active} || [] } ), 'Saved status persisted after redirect' );
}

diag "Test that a save with validation errors retains user input and does not redirect";
{
    $m->get_ok( '/Admin/Lifecycles/Modify.html?Name=sales&Type=ticket', 'Open lifecycle editor' );

    # Parseable but invalid (transition to a nonexistent status). The marker
    # lives only in the submitted Config, so finding it proves input retention.
    my %invalid = (
        type        => 'ticket',
        initial     => ['new'],
        active      => ['open'],
        inactive    => ['resolved'],
        defaults    => { on_create => 'new' },
        transitions => {
            ''   => ['new'],
            new  => [ 'open', 'ghoststatus' ],
            open => ['resolved'],
        },
        status_metadata => { open => { description => 'UNIQUERETAINMARKER42' } },
    );

    my $max_redirect = $m->max_redirect;
    $m->max_redirect(0);
    $m->submit_form(
        form_name => 'ModifyLifecycle',
        fields    => { Config => JSON::encode_json( \%invalid ), Maps => '{}' },
        button    => 'Update',
    );
    is( $m->status, 200, 'Validation failure renders inline instead of redirecting' );
    $m->max_redirect($max_redirect);
    $m->text_contains( 'Nonexistent status ghoststatus', 'Validation warning is shown' );
    $m->content_contains( 'UNIQUERETAINMARKER42', 'Submitted Config is retained in the editor after an error' );

    RT->Config->RefreshConfigFromDatabase();
    my $reloaded = RT->Config->Get('Lifecycles')->{sales};
    ok( ( grep { $_ eq 'active60' } @{ $reloaded->{active} || [] } ), 'Invalid submission was not persisted' );
}

diag "Test that a failed config save is not redirected away even when the layout saved";
{
    $m->get_ok( '/Admin/Lifecycles/Modify.html?Name=sales&Type=ticket', 'Open lifecycle editor' );

    # The layout change persists, but the config fails validation (ghoststatus).
    # We must not redirect (which would reload the saved config and drop the
    # user's edits); the marker proves the submitted Config is retained.
    my %invalid = (
        type        => 'ticket',
        initial     => ['new'],
        active      => ['open'],
        inactive    => ['resolved'],
        defaults    => { on_create => 'new' },
        transitions => { '' => ['new'], new => [ 'open', 'ghoststatus' ], open => ['resolved'] },
        status_metadata => { open => { description => 'LAYOUTFAILMARKER' } },
    );

    my $max_redirect = $m->max_redirect;
    $m->max_redirect(0);
    $m->submit_form(
        form_name => 'ModifyLifecycle',
        fields    => {
            Config => JSON::encode_json( \%invalid ),
            Layout => JSON::encode_json( { nodes => [ { name => 'new', x => 1, y => 2 } ] } ),
            Maps   => '{}',
        },
        button => 'Update',
    );
    is( $m->status, 200, 'A failed config save is not redirected even when the layout saved' );
    $m->max_redirect($max_redirect);
    $m->content_contains( 'LAYOUTFAILMARKER', 'Submitted Config is retained despite the layout saving' );
}

done_testing;
