#!/usr/bin/perl -w
use strict;

use Test::More tests => 10;
BEGIN {
    use RT;
    RT::LoadConfig;
    RT::Init;
}
use Test::WWW::Mechanize;

$RT::WebPath ||= ''; # Shut up a warning
use constant BaseURL => "http://localhost:".$RT::WebPort.$RT::WebPath."/";

# reset preferences for easier test?

my $t = RT::Ticket->new($RT::SystemUser);
$t->Create(Subject => 'for custom search', Queue => 'general',
	   Owner => 'root', Requestor => 'customsearch@localhost');
ok(my $id = $t->id, 'created ticket for custom search');

my $m = Test::WWW::Mechanize->new ( autocheck => 1 );
isa_ok($m, 'Test::WWW::Mechanize');

$m->get( BaseURL."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');

my $t_link = $m->find_link( text => "for custom search" );
like ($t_link->url, qr/$id/, 'link to the ticket we created');

$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');

my ($cus_hp, undef, $cus_qs) = $m->find_all_links( text => "Customize" );
$m->get ($cus_hp);
$m->content_like (qr'highest priority tickets');

# add Requestor to the fields
$m->form_name ('BuildQuery');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field (SelectDisplayColumns => ['Requestors']);
$m->click_button (name => 'AddCol') ;

$m->form_name ('BuildQuery');
$m->click_button (name => 'Save');

$m->follow_link (text => 'Go back') or die;
$m->content_contains ('customsearch@localhost', 'requestor now displayed ');


# now remove Requestor from the fields
$m->get ($cus_hp);

$m->form_name ('BuildQuery');
$m->field (CurrentDisplayColumns => 'Requestors');
$m->click_button (name => 'RemoveCol') ;

$m->form_name ('BuildQuery');
$m->click_button (name => 'Save');

$m->follow_link (text => 'Go back') or die;
$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');


# try to disable General from quick search

# Note that there's a small problem in the current implementation,
# since ticked quese are wanted, we do the invesrsion.  So any
# queue added during the quicksearch setting will be unticked.
my $nlinks = $#{$m->find_all_links( text => "General" )};
warn $nlinks;
$m->get ($cus_qs);
$m->form_name ('Preferences');
$m->untick('Want-General', '1');
$m->click_button (name => 'Save');

$m->follow_link (text => 'Go back') or die;
is ($#{$m->find_all_links( text => "General" )}, $nlinks - 1,
    'General gone from quicksearch list');

# get it back
$m->get ($cus_qs);
$m->form_name ('Preferences');
$m->tick('Want-General', '1');
$m->click_button (name => 'Save');

$m->follow_link (text => 'Go back') or die;
is ($#{$m->find_all_links( text => "General" )}, $nlinks,
    'General back in quicksearch list');
