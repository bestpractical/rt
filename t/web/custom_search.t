#!/usr/bin/perl -w
use strict;

use RT::Test strict  => 1;
use Test::More tests => 23;

my ( $baseurl, $m ) = RT::Test->started_ok;
my $url = $m->rt_base_url;

# reset preferences for easier test?

my $t = RT::Model::Ticket->new( current_user => RT->system_user );
my ( $tkid, $txnid, $msg ) = $t->create(
    subject   => 'for custom search' . $$,
    queue     => 'general',
    owner     => 'root',
    requestor => 'customsearch@localhost'
);
ok( my $id = $t->id, 'Created ticket for custom search' );
ok( $tkid, $msg );
ok $m->login, 'logged in';
my $t_link = $m->find_link( text => "for custom search" . $$ );
like( $t_link->url, qr/$id/, 'link to the ticket we Created' );

$m->content_lacks( 'customsearch@localhost', 'requestor not displayed ' );

$m->get_ok( $url . '/prefs/my_rt' );
my $cus_hp = $m->find_link( text => "My Tickets" );
my $cus_qs = $m->find_link( text => "Quick search" );
$m->get_ok($cus_hp);
$m->content_like(qr'Customize Search');

# add Requestor to the fields
$m->form_name('prefs_edit_search_options');

# can't use submit form for mutli-valued select as it uses set_fields
$m->field( select_display_columns => ['requestors'] );
$m->click_button( name => 'add_col' );

$m->form_name('prefs_edit_search_options');
$m->click_button( name => 'J:A:F-save-prefs_edit_search_options' );

$m->get_ok($url);
$m->content_contains( 'customsearch@localhost', 'requestor now displayed ' );

# now remove Requestor from the fields
$m->get_ok($cus_hp);

$m->form_name('prefs_edit_search_options');
my $cdc = $m->current_form->find_input('current_display_columns');
my ($requestor_value) = grep { /requestor/ } $cdc->value_names;
ok( $requestor_value, "got the requestor value" );

$m->form_name('prefs_edit_search_options');
$m->field( current_display_columns => $requestor_value );
$m->click_button( name => 'remove_col' );

$m->form_name('prefs_edit_search_options');
$m->click_button( name => 'J:A:F-save-prefs_edit_search_options' );

$m->get_ok($url);
$m->content_lacks( 'customsearch@localhost', 'requestor not displayed ' );

# try to disable General from quick search

# Note that there's a small problem in the current implementation,
# since ticked quese are wanted, we do the invesrsion.  So any
# queue added during the quicksearch setting will be unticked.
my $nlinks = $#{ $m->find_all_links( text => "General" ) };

$m->get_ok($cus_qs);
$m->fill_in_action_ok('prefs_edit_quick_search', queues => 0);
$m->submit;

$m->get_ok($url);
is(
    $#{ $m->find_all_links( text => "General" ) },
    $nlinks - 1,
    'General gone from quicksearch list'
);

# get it back
$m->get_ok($cus_qs);
$m->fill_in_action_ok('prefs_edit_quick_search', queues => 'General');
$m->submit;

$m->get_ok($url);
is( $#{ $m->find_all_links( text => "General" ) },
    $nlinks, 'General back in quicksearch list' );
