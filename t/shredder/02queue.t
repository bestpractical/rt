#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Deep;
use File::Spec;
use Test::More tests => 16;
use RT::Test ();
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}
init_db();


diag 'simple queue' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Queue->new( $RT::SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with scrip' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Queue->new( $RT::SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $scrip = RT::Scrip->new( $RT::SystemUser );
    ($id, $msg) = $scrip->Create(
        Description    => 'my scrip',
        Queue          => $queue->id,
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => 'Blank',
    );
    ok($id, 'created scrip') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Queue->new( $RT::SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $template = RT::Template->new( $RT::SystemUser );
    ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => $queue->id,
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $queue );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'queue with a right granted' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $queue = RT::Queue->new( $RT::SystemUser );
    my ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    my $group = RT::Group->new( $RT::SystemUser );
    $group->LoadSystemInternalGroup('Everyone');
    ok($group->id, 'loaded group');

    ($id, $msg) = $group->PrincipalObj->GrantRight(
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
    my $group = RT::Group->new( $RT::SystemUser );
    my ($id, $msg) = $group->CreateUserDefinedGroup(Name => 'my group');
    ok($id, 'created group') or diag "error: $msg";

	create_savepoint('bqcreate');
    my $queue = RT::Queue->new( $RT::SystemUser );
    ($id, $msg) = $queue->Create( Name => 'my queue' );
    ok($id, 'created queue') or diag "error: $msg";

    ($id, $msg) = $queue->AddWatcher(
        Type   => 'Cc',
        PrincipalId => $group->id,
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
