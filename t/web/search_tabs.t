#!/usr/bin/perl
use warnings;
use strict;

use RT::Test tests => 12;
my ($baseurl, $agent) = RT::Test->started_ok;

my $ticket = RT::Ticket->new(RT->SystemUser);
for ( 1 .. 2 ) {
    $ticket->Create(
        Subject   => 'Ticket ' . $_,
        Queue     => 'General',
        Owner     => 'root',
        Requestor => 'clownman@localhost',
    );
}

ok $agent->login('root', 'password'), 'logged in as root';

# [issues.bestpractical.com #16841] {
$agent->get_ok('/Search/Build.html');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '1');
$agent->submit('AddClause');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '2');
$agent->field('AndOr', 'OR');
$agent->submit('AddClause');

$agent->follow_link_ok({id => 'page-results'});
$agent->title_is('Found 2 tickets');
# }

# [issues.bestpractical.com #17237] {
$agent->follow_link_ok({text => 'New Search'});
$agent->title_is('Query Builder');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '1');
$agent->submit('AddClause');

$agent->form_name('BuildQuery');
$agent->field('idOp', '=');
$agent->field('ValueOfid', '2');
$agent->field('AndOr', 'OR');
$agent->click_button(name => 'DoSearch');

$agent->title_is('Found 2 tickets');

$agent->follow_link_ok({id => 'page-results'});
$agent->title_is('Found 2 tickets');
# }

