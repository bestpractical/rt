#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test::Shredder;
RT::Test::Shredder::init_db();

plan tests => 16;

diag 'simple queue' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $queue );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with scrip' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $scrip = RT::Model::Scrip->new(current_user => RT->system_user );
    ($id, $msg) = $scrip->create(
        description    => 'my scrip',
        queue          => $queue->id,
        scrip_condition => 'On Create',
        scrip_action    => 'Open Tickets',
        template       => 'Blank',
    );
    ok($id, 'Created scrip') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $queue );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with template' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $template = RT::Model::Template->new(current_user => RT->system_user );
    ($id, $msg) = $template->create(
        name => 'my template',
        queue => $queue->id,
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $queue );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a Right granted' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $group = RT::Model::Group->new(current_user => RT->system_user );
    $group->load_system_internal('Everyone');
    ok($group->id, 'loaded group');

    ($id, $msg) = $group->principal->grant_right(
        right  => 'CreateTicket',
        object => $queue,
    );
    ok($id, 'granted right') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $queue );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a watcher' if $ENV{'TEST_VERBOSE'};
{
# XXX, FIXME: if uncomment these lines then we'll get 'Bizarre...'
#	RT::Test::Shredder::create_savepoint('clean');
    my $group = RT::Model::Group->new(current_user => RT->system_user );
    my ($id, $msg) = $group->create_user_defined(name => 'my group');
    ok($id, 'Created group') or diag "error: $msg";

	RT::Test::Shredder::create_savepoint('bqcreate');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    ($id, $msg) = $queue->add_watcher(
        type   => 'Cc',
        principal => $group->id,
    );
    ok($id, 'added watcher') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $queue );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('bqcreate'), "current DB equal to savepoint");

#	$shredder->put_objects( objects => $group );
#	$shredder->wipeout_all;
#	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}
