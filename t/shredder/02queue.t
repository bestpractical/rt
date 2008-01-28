#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 16;

diag 'simple queue' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with scrip' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $scrip = RT::Model::Scrip->new(current_user => RT->system_user );
    ($id, $msg) = $scrip->create(
        Description    => 'my scrip',
        Queue          => $queue->id,
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => 'Blank',
    );
    ok($id, 'Created scrip') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $template = RT::Model::Template->new(current_user => RT->system_user );
    ($id, $msg) = $template->create(
        name => 'my template',
        Queue => $queue->id,
        Content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a right granted' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    my ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    my $group = RT::Model::Group->new(current_user => RT->system_user );
    $group->load_system_internal_group('Everyone');
    ok($group->id, 'loaded group');

    ($id, $msg) = $group->principal_object->grant_right(
        Right  => 'CreateTicket',
        Object => $queue,
    );
    ok($id, 'granted right') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a watcher' if $ENV{'TEST_VERBOSE'};
{
# XXX, FIXME: if uncomment these lines then we'll get 'Bizarre...'
#	create_savepoint('clean');
    my $group = RT::Model::Group->new(current_user => RT->system_user );
    my ($id, $msg) = $group->create_userDefinedGroup(name => 'my group');
    ok($id, 'Created group') or diag "error: $msg";

	create_savepoint('bqcreate');
    my $queue = RT::Model::Queue->new(current_user => RT->system_user );
    ($id, $msg) = $queue->create( name => 'my queue' );
    ok($id, 'Created queue') or diag "error: $msg";

    ($id, $msg) = $queue->AddWatcher(
        Type   => 'Cc',
        principal_id => $group->id,
    );
    ok($id, 'added watcher') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('bqcreate'), "current DB equal to savepoint");

#	$shredder->PutObjects( Objects => $group );
#	$shredder->WipeoutAll;
#	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

