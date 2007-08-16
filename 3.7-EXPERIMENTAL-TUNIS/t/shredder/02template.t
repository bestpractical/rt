#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Deep;
BEGIN { require "t/shredder/utils.pl"; }
init_db();

plan tests => 7;

diag 'global template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Template->new( $RT::SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $template );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'local template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Template->new( $RT::SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => 'General',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $template );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'template used in scrip' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Template->new( $RT::SystemUser );
    my ($id, $msg) = $template->Create(
        Name => 'my template',
        Queue => 'General',
        Content => "\nsome content",
    );
    ok($id, 'created template') or diag "error: $msg";

    my $scrip = RT::Scrip->new( $RT::SystemUser );
    ($id, $msg) = $scrip->Create(
        Description    => 'my scrip',
        Queue          => 'General',
        ScripCondition => 'On Create',
        ScripAction    => 'Open Tickets',
        Template       => $template->id,
    );
    ok($id, 'created scrip') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->PutObjects( Objects => $template );
	$shredder->WipeoutAll;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

if( is_all_successful() ) {
	cleanup_tmp();
} else {
	diag( note_on_fail() );
}

