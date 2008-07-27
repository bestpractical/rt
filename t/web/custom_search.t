#!/usr/bin/perl -w
use strict;

use RT::Test; use Test::More tests => 11;

my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

# reset preferences for easier test?



my $t = RT::Model::Ticket->new(current_user => RT->system_user);
my ($tkid,$txnid, $msg) = $t->create(subject => 'for custom search'.$$, queue => 'general',
	   owner => 'root', requestor => 'customsearch@localhost');
ok(my $id = $t->id, 'Created ticket for custom search');
ok($tkid, $msg);
ok $m->login, 'logged in';
my $t_link = $m->find_link( text => "for custom search".$$ );
like ($t_link->url, qr/$id/, 'link to the ticket we Created');

$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');
$m->get ( $url.'Prefs/MyRT.html' );
my $cus_hp = $m->find_link( text => "My Tickets" );
my $cus_qs = $m->find_link( text => "Quick search" );
$m->get ($cus_hp);
$m->content_like (qr'highest priority tickets');

# add Requestor to the fields
$m->form_name('build_query');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field (select_display_columns => ['requestors']);
$m->click_button (name => 'add_col') ;

$m->form_name('build_query');
$m->click_button (name => 'save');

$m->get( $url );
$m->content_contains ('customsearch@localhost', 'requestor now displayed ');

# now remove Requestor from the fields
$m->get ($cus_hp);

$m->form_name('build_query');
$m->field (current_display_columns => 'Requestors');
$m->click_button (name => 'remove_col') ;

$m->form_name('build_query');
$m->click_button (name => 'save');

$m->get( $url );
$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');


# try to disable General from quick search

# Note that there's a small problem in the current implementation,
# since ticked quese are wanted, we do the invesrsion.  So any
# queue added during the quicksearch setting will be unticked.
my $nlinks = $#{$m->find_all_links( text => "General" )};
$m->get ($cus_qs);
$m->form_name('preferences');
$m->untick('Want-General', '1');
$m->click_button (name => 'save');

$m->get( $url );
is ($#{$m->find_all_links( text => "General" )}, $nlinks - 1,
    'General gone from quicksearch list');

# get it back
$m->get ($cus_qs);
$m->form_name('preferences');
$m->tick('Want-General', '1');
$m->click_button (name => 'save');

$m->get( $url );
is ($#{$m->find_all_links( text => "General" )}, $nlinks,
    'General back in quicksearch list');
