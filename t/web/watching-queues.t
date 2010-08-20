#!/usr/bin/perl -w
use strict;

use RT::Test tests => 25;
use Test::XPath;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';


diag "check watching page" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Tools' );
    $m->title_is('Tools', 'tools screen');
    $m->follow_link( text => 'Watching Queues' );
    $m->title_is('Watching Queues', 'watching screen');

    $m->content_contains('You are not watching any queues.');

    my $tx = new_tx($m->content);
    $tx->not_ok('//ul[contains(@class,"queue-list")]', 'no queue list when watching nothing');
}

diag "add self as AdminCc on queue" if $ENV{'TEST_VERBOSE'};
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

    my $tx = new_tx($m->content);
    $tx->ok('//ul[contains(@class,"queue-list")]', sub {
        $_->is('count(.//li[contains(@class,"queue-roles")])', 1, 'only one queue');
        $_->ok('.//li[contains(@class,"queue-roles")]', sub {
            $_->like('.//span[contains(@class,"queue-name")][text()]', qr/^\s*General\s*$/, 'correct queue');
            $_->ok('.//ul[contains(@class,"queue-role-list")]', sub {
                $_->is('count(.//li[contains(@class,"queue-role")])', 1, 'only one role');
                $_->like('.//li[contains(@class,"queue-role")][text()]', qr/^\s*AdminCc\s*$/, 'correct role');
            });
        });
    });
}

sub new_tx {
    my $content = shift;

    # need to recover from embedded javascript using <!-- -->
    my $tx = Test::XPath->new(
        xml     => $content,
        is_html => 1,
        options => { recover => 1 },
    );

    return $tx;
}

