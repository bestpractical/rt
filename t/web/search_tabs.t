#!/usr/bin/perl

use strict;

use RT::Test tests => 7;
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

