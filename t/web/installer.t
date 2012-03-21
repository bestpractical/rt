#!/usr/bin/perl
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
    $m->content_like(qr/RT\s+pour\s+example\.com/i);
    $m->submit_form_ok(
        {
            with_fields => {
                Lang => 'en',
            },
            button => 'ChangeLang',
        },
        'change language to english'
    );
    $m->content_like(qr/RT\s+for\s+example\.com/i);
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
    $m->submit();
    $m->content_contains('Connection succeeded');
    $m->submit_form_ok({ button => 'Next' });

    # Basic options
    $m->submit_form_ok({
        with_fields => {
            Password    => 'password',
        }
    }, 'set root password');

    # Mail options
    $m->submit_form_ok({
        with_fields => {
            OwnerEmail  => 'admin@example.com',
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
    ok $m->login(), 'logged in';
}

undef $m;
done_testing;
