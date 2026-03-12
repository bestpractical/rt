use strict;
use warnings;

$ENV{RT_TEST_WEB_HANDLER} = 'plack+rt-server';
use RT::Test
    tests       => undef,
    nodb        => 1,
    server_ok   => 1;

my ($base, $m) = RT::Test->started_ok;

$m->warning_like(qr/If this is a new installation of RT/,
                 "Got startup warning");

$m->get_ok($base);
like $m->uri, qr/Install/, 'at installer';

diag "Verify clicking Let's go with htmx boosted request does not crash";
{
    # The installer page is htmx boosted, so clicking "Let's go!" submits
    # the form as a boosted request. The Redirect in the handler goes through
    # the htmx boosted path which must skip database-dependent calls
    # (MaybeRebuildLifecycleCache, ExpandShortenerCode) in install mode.
    $m->add_header( 'HX-Request' => 'true' );
    $m->add_header( 'HX-Boosted' => 'true' );

    $m->submit_form_ok( { button => 'Run', }, 'click Let\'s go with htmx boosted request' );

    like( $m->response->header('HX-Push-Url'), qr/DatabaseType\.html/, 'HX-Push-Url points to DatabaseType page' );
    $m->content_like( qr/DatabaseType/, 'response contains database type selection' );
    $m->content_unlike( qr/unblessed reference/i, 'no unblessed reference error' );
    $m->content_unlike( qr/System Error/i,        'no system error page' );

    $m->delete_header('HX-Request');
    $m->delete_header('HX-Boosted');
}

# Reset Mech back to the installer via a normal request so subsequent
# tests (language change form submission, etc.) work correctly.
$m->get_ok($base);
like $m->uri, qr/Install/, 'back at installer after htmx test';

diag "Testing language change";
{
    $m->submit_form_ok(
        {
            with_fields => {
                Lang => 'fr',
            },
            button => 'ChangeLang',
        },
        'change language to french'
    );
    $m->content_like(qr/Pour commencer/);
    $m->submit_form_ok(
        {
            with_fields => {
                Lang => 'en',
            },
            button => 'ChangeLang',
        },
        'change language to english'
    );
    $m->content_like(qr/Getting started/);
}

diag "Walking through install screens setting defaults";
{
    $m->click_ok('Run');

    # Database type
    $m->content_contains('DatabaseType');
    $m->content_contains($_, "found database $_")
        for qw(MySQL PostgreSQL Oracle SQLite);
    $m->submit();

    # Database details
    $m->content_contains('DatabaseName');
    if (RT->Config->Get('DatabaseType') eq 'SQLite') {
        $m->submit;
    } else {
        $m->submit_form(with_fields => {
            DatabaseAdmin         => $ENV{RT_DBA_USER},
            DatabaseAdminPassword => $ENV{RT_DBA_PASSWORD},
            DatabasePassword      => "rt_pass",
        });
    }
    $m->content_contains('Connection succeeded');
    $m->submit_form_ok({ button => 'Next' });

    # Basic options
    $m->submit_form_ok({
        with_fields => {
            Password    => 'password',
        }
    }, 'set root password');

    # Mail options
    my $sendmail = File::Spec->rel2abs( File::Spec->catfile(
        't', 'security', 'fake-sendmail' ) );
    $m->submit_form_ok({
        with_fields => {
            OwnerEmail   => 'admin@example.com',
            SendmailPath => $sendmail,
        },
    }, 'set admin email');

    # Mail addresses
    $m->submit_form_ok({
        with_fields => {
            CorrespondAddress   => 'rt@example.com',
            CommentAddress      => 'rt-comment@example.com',
        },
    }, 'set addresses');

    # Initialize database
    $m->content_contains('database');
    $m->submit();

    # Finish
    $m->content_contains('/RT_SiteConfig.pm');
    $m->content_contains('Finish');
    $m->submit();

    $m->content_contains('Login');
    RT->LoadConfig;
    RT->Init;
    ok $m->login(), 'logged in';
}

RT::Test::__drop_database();
done_testing;
