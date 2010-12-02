#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 19;

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

my ($baseurl, $m) = RT::Test->started_ok;

ok( RT::Test->set_rights(
    { Principal => $user_a, Right => [qw(ShowConfigTab ShowTemplate ModifyTemplate)] },
), 'set rights');

ok $m->login('user_a', 'password'), 'logged in as user A';

# get to the templates screen
$m->follow_link( text => 'Configuration' );
$m->title_is(q{RT Administration}, 'admin screen');

$m->follow_link( text => 'Global' );
$m->title_is(q{Admin/Global configuration}, 'global admin');

$m->follow_link( text => 'Templates' );
$m->title_is(q{Modify templates which apply to all queues}, 'global templates');

$m->follow_link( text => 'Resolved' ); # template name
$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');

# now try changing Type back and forth
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Perl');

$m->field(Type => 'Simple');
$m->submit;

$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Simple', 'updated type to simple');

$m->field(Type => 'Perl');
$m->submit;

$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Simple', 'need the ExecuteCode right to update Type to Perl');
$m->content_contains('Permission Denied');

ok( RT::Test->add_rights(
    { Principal => $user_a, Right => [qw(ExecuteCode)] },
), 'add ExecuteCode rights');

$m->field(Type => 'Perl');
$m->submit;

$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Perl', 'now that we have ExecuteCode we can update Type to Perl');

