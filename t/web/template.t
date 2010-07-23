#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 26;

my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login, 'logged in';

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
is($m->value('Type'), 'Full');

$m->field(Type => 'Simple');
$m->submit;

$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Simple');

$m->field(Type => 'Full');
$m->submit;

$m->title_is(q{Modify template Resolved}, 'modifying the Resolved template');
$m->form_name('ModifyTemplate');
is($m->value('Type'), 'Full');

