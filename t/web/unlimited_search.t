#!/usr/bin/perl

use strict;
use Test::More tests => 8;

use RT::Test;
RT::Test->started_ok;

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
for ( 1 .. 75 ) {
    $ticket->create(
        subject   => 'Ticket ' . $_,
        queue     => 'General',
        owner     => 'root',
        requestor => 'unlimitedsearch@localhost',
    );
}

my $agent = RT::Test::Web->new;
ok $agent->login('root', 'password'), 'logged in as root';

$agent->get_ok('/Search/Build.html');
$agent->form_name( 'build_query' );
$agent->field('id_op', '>');
$agent->field('value_of_id', '0');
$agent->submit('add_clause');
$agent->form_name( 'build_query' );
$agent->field('rows_per_page', '0');
$agent->submit('do_search');
$agent->follow_link_ok({text=>'Show Results'});
$agent->content_like(qr/Ticket 75/);

$agent->follow_link_ok({text=>'New Search'});
$agent->form_name( 'build_query' );
$agent->field('id_op', '>');
$agent->field('value_of_id', '0');
$agent->submit('add_clause');
$agent->form_name( 'build_query' );
$agent->field('rows_per_page', '50');
$agent->submit('do_search');
$agent->follow_link_ok({text=>'Bulk Update'});
$agent->content_unlike(qr/Ticket 51/);
