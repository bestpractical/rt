#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test strict => 1; use Test::More;
use Test::Deep;
use File::Spec;
use RT::Test::Shredder;
RT::Test::Shredder::init_db();

plan tests => 4;

diag 'global template' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $template = RT::Model::Template->new(current_user => RT->system_user );
    my ($id, $msg) = $template->create(
        name => 'my template',
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $template );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

diag 'local template' if $ENV{'TEST_VERBOSE'};
{
	RT::Test::Shredder::create_savepoint('clean');
    my $template = RT::Model::Template->new(current_user => RT->system_user );
    my ($id, $msg) = $template->create(
        name => 'my template',
        queue => 'General',
        content => "\nsome content",
    );
    ok($id, 'Created template') or diag "error: $msg";

	my $shredder = RT::Test::Shredder::shredder_new();
	$shredder->put_objects( objects => $template );
	$shredder->wipeout_all;
	cmp_deeply( RT::Test::Shredder::dump_current_and_savepoint('clean'), "current DB equal to savepoint");
}

