#!/usr/bin/perl -w
use strict;

use RT::Test tests => 45;
use Web::Scraper;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

my $other_queue = RT::Queue->new($RT::SystemUser);
$other_queue->Create(
    Name => 'Fancypants',
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
    $m->title_is('Editing Configuration for queue General');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('Modify people related to queue General');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('Modify people related to queue General', 'caught the right form! :)');

    my $user = RT::User->new($RT::SystemUser);
    $user->LoadByEmail('root@localhost');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->id => 'AdminCc',
        },
    });

    $m->title_is('Modify people related to queue General', 'caught the right form! :)');

    my $queue = RT::Queue->new($RT::SystemUser);
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
    $m->title_is('Editing Configuration for queue General');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('Modify people related to queue General');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('Modify people related to queue General', 'caught the right form! :)');

    my $user = RT::User->new($RT::SystemUser);
    $user->LoadByEmail('root@localhost');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->id => 'Cc',
        },
    });

    $m->title_is('Modify people related to queue General', 'caught the right form! :)');

    my $queue = RT::Queue->new($RT::SystemUser);
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
    $m->title_is('Editing Configuration for queue Fancypants');
    $m->follow_link( text => 'Watchers' );
    $m->title_is('Modify people related to queue Fancypants');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            UserField  => 'Name',
            UserOp     => 'LIKE',
            UserString => 'root',
        },
    });

    $m->title_is('Modify people related to queue Fancypants', 'caught the right form! :)');

    my $user = RT::User->new($RT::SystemUser);
    $user->LoadByEmail('root@localhost');

    $m->submit_form_ok({
        form_number => 3,
        fields => {
            'Queue-AddWatcher-Principal-' . $user->id => 'AdminCc',
        },
    });

    $m->title_is('Modify people related to queue Fancypants', 'caught the right form! :)');

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

