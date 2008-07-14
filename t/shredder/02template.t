#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test;
BEGIN {
    my $shredder_utils = RT::Test::get_relocatable_file('utils.pl',
        File::Spec->curdir());
    require $shredder_utils;
}
init_db();

plan tests => 7;

diag 'global template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Model::Template->new(current_user => RT->system_user );
    my ($id, $msg) = $template->create(
        name => 'my template',
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->put_objects( objects => $template );
	$shredder->wipeout_all;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'local template' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Model::Template->new(current_user => RT->system_user );
    my ($id, $msg) = $template->create(
        name => 'my template',
        queue => 'General',
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->put_objects( objects => $template );
	$shredder->wipeout_all;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'template used in scrip' if $ENV{'TEST_VERBOSE'};
{
	create_savepoint('clean');
    my $template = RT::Model::Template->new(current_user => RT->system_user );
    my ($id, $msg) = $template->create(
        name => 'my template',
        queue => 'General',
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

    my $scrip = RT::Model::Scrip->new(current_user => RT->system_user );
    ($id, $msg) = $scrip->create(
        description    => 'my scrip',
        queue          => 'General',
        scrip_condition => 'On Create',
        scrip_action    => 'Open Tickets',
        template       => $template->id,
    );
    ok($id, 'Created scrip') or diag "error: $msg";

	my $shredder = shredder_new();
	$shredder->put_objects( objects => $template );
	$shredder->wipeout_all;
	cmp_deeply( dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}
