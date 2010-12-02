#!/usr/bin/perl -w
use strict;

use RT::Test tests => 77;
use Web::Scraper;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

my $user = RT::User->new(RT->SystemUser);
$user->LoadByEmail('root@localhost');

my $other_queue = RT::Queue->new(RT->SystemUser);
$other_queue->Create(
    Name => 'Fancypants',
);

my $loopy_queue = RT::Queue->new(RT->SystemUser);
$loopy_queue->Create(
    Name => 'Loopy',
);

my $group = RT::Group->new(RT->SystemUser);
$group->CreateUserDefinedGroup(
    Name => 'Groupies',
    Description => 'for the Metallica Speed of Sound tour',
);

my $outer_group = RT::Group->new(RT->SystemUser);
$outer_group->CreateUserDefinedGroup(
    Name => 'Groupies 2.0',
    Description => 'for the Metallica Ride The Lightning tour',
);

my $watching = scraper {
    process "li.queue-roles", 'queues[]' => scraper {
        # trim the queue name
        process 'span.queue-name', name => sub {
            my $name = shift->as_text;
            $name =~ s/^\s*//;
            $name =~ s/\s*$//;
            return $name;
        };
        process "li.queue-role", 'roles[]' => 'TEXT';
    };
};

diag "check watching page" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_contains('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {});
}

diag "add self as AdminCc on General" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is('RT Administration', 'admin page');
    $m->follow_link( text => 'Queues' );
    $m->title_is('Admin queues', 'queues page');
    $m->follow_link( text => 'General' );
    $m->title_is('Configuration for queue General');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('People related to queue General');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('People related to queue General', 'caught the right form! :)');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->PrincipalId => 'AdminCc',
        },
    });

    $m->title_is('People related to queue General', 'caught the right form! :)');

    my $queue = RT::Queue->new(RT->SystemUser);
    $queue->Load('General');
    ok($queue->IsWatcher(Type => 'AdminCc', PrincipalId => $user->PrincipalId), 'added root as AdminCc on General');
}

diag "check watching page" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'General',
                roles => ['AdminCc'],
            },
        ],
    });
}

diag "add self as Cc on General" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is('RT Administration', 'admin page');
    $m->follow_link( text => 'Queues' );
    $m->title_is('Admin queues', 'queues page');
    $m->follow_link( text => 'General' );
    $m->title_is('Configuration for queue General');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('People related to queue General');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('People related to queue General', 'caught the right form! :)');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->PrincipalId => 'Cc',
        },
    });

    $m->title_is('People related to queue General', 'caught the right form! :)');

    my $queue = RT::Queue->new(RT->SystemUser);
    $queue->Load('General');
    ok($queue->IsWatcher(Type => 'Cc', PrincipalId => $user->PrincipalId), 'added root as Cc on General');
}

diag "check watching page" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'General',
                roles => ['Cc', 'AdminCc'],
            },
        ],
    });
}

diag "add self as AdminCc on Fancypants" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is('RT Administration', 'admin page');
    $m->follow_link( text => 'Queues' );
    $m->title_is('Admin queues', 'queues page');
    $m->follow_link( text => 'Fancypants' );
    $m->title_is('Configuration for queue Fancypants');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('People related to queue Fancypants');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('People related to queue Fancypants', 'caught the right form! :)');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->PrincipalId => 'AdminCc',
        },
    });

    $m->title_is('People related to queue Fancypants', 'caught the right form! :)');

    ok($other_queue->IsWatcher(Type => 'AdminCc', PrincipalId => $user->PrincipalId), 'added root as AdminCc on Fancypants');
}

diag "check watching page" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'Fancypants',
                roles => ['AdminCc'],
            },
            {
                name  => 'General',
                roles => ['Cc', 'AdminCc'],
            },
        ],
    });
}

diag "add group as Cc on Loopy" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is('RT Administration', 'admin page');
    $m->follow_link( text => 'Queues' );
    $m->title_is('Admin queues', 'queues page');
    $m->follow_link( text => 'Loopy' );
    $m->title_is('Configuration for queue Loopy');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('People related to queue Loopy');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            GroupField  => 'Name',
            GroupOp     => 'LIKE',
            GroupString => 'Groupies',
        },
    });

    $m->title_is('People related to queue Loopy', 'caught the right form! :)');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $group->PrincipalId => 'Cc',
        },
    });

    $m->title_is('People related to queue Loopy', 'caught the right form! :)');

    ok($loopy_queue->IsWatcher(Type => 'Cc', PrincipalId => $group->PrincipalId), 'added Groupies as Cc on Loopy');
}

$group->AddMember($user->PrincipalId);

diag "check watching page (no change since root is not a groupy)" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'Fancypants',
                roles => ['AdminCc'],
            },
            {
                name  => 'General',
                roles => ['Cc', 'AdminCc'],
            },
            {
                name  => 'Loopy',
                roles => ['Cc'],
            },
        ],
    });
}

diag "add other group as AdminCc on Loopy" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is('RT Administration', 'admin page');
    $m->follow_link( text => 'Queues' );
    $m->title_is('Admin queues', 'queues page');
    $m->follow_link( text => 'Loopy' );
    $m->title_is('Configuration for queue Loopy');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('People related to queue Loopy');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            GroupField  => 'Name',
            GroupOp     => 'LIKE',
            GroupString => 'Groupies',
        },
    });

    $m->title_is('People related to queue Loopy', 'caught the right form! :)');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $outer_group->PrincipalId => 'AdminCc',
        },
    });

    $m->title_is('People related to queue Loopy', 'caught the right form! :)');

    ok($loopy_queue->IsWatcher(Type => 'AdminCc', PrincipalId => $outer_group->PrincipalId), 'added Groupies 2.0 as AdminCc on Loopy');
}

diag "check watching page (no change since root is not in groupy 2.0)" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'Fancypants',
                roles => ['AdminCc'],
            },
            {
                name  => 'General',
                roles => ['Cc', 'AdminCc'],
            },
            {
                name  => 'Loopy',
                roles => ['Cc'],
            },
        ],
    });
}

$outer_group->AddMember($group->PrincipalId);

diag "user is not a member of the outer group recursively" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_lacks('You are not watching any queues.');

    is_deeply($watching->scrape($m->content), {
        queues => [
            {
                name  => 'Fancypants',
                roles => ['AdminCc'],
            },
            {
                name  => 'General',
                roles => ['Cc', 'AdminCc'],
            },
            {
                name  => 'Loopy',
                roles => ['Cc', 'AdminCc'],
            },
        ],
    });
}
