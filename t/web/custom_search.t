use strict;
use warnings;

use RT::Test tests => 13;
my ($baseurl, $m) = RT::Test->started_ok;
my $url = $m->rt_base_url;

# reset preferences for easier test?



my $t = RT::Ticket->new(RT->SystemUser);
$t->Create(Subject => 'for custom search'.$$, Queue => 'general',
           Owner => 'root', Requestor => 'customsearch@localhost');
ok(my $id = $t->id, 'created ticket for custom search');

ok $m->login, 'logged in';

my $t_link = $m->find_link( text => "for custom search".$$ );
like ($t_link->url, qr/$id/, 'link to the ticket we created');

$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');
$m->get ( $url.'Prefs/MyRT.html' );
my $cus_hp = $m->find_link( text => "My Tickets" );
my $cus_qs = $m->find_link( text => "Queue list" );
$m->get ($cus_hp);
$m->content_contains('highest priority tickets');

# add Requestor to the fields
$m->form_name ('BuildQuery');
# can't use submit form for mutli-valued select as it uses set_fields
$m->field (SelectDisplayColumns => ['Requestors']);
$m->click_button (name => 'AddCol') ;

$m->form_name ('BuildQuery');
$m->click_button (name => 'Save');

$m->get( $url );
$m->content_contains ('customsearch@localhost', 'requestor now displayed ');


# now remove Requestor from the fields
$m->get ($cus_hp);

$m->form_name ('BuildQuery');

my $cdc = $m->current_form->find_input('CurrentDisplayColumns');
my ($requestor_value) = grep { /Requestor/ } $cdc->possible_values;
ok($requestor_value, "got the requestor value");

$m->field (CurrentDisplayColumns => $requestor_value);
$m->click_button (name => 'RemoveCol') ;

$m->form_name ('BuildQuery');
$m->click_button (name => 'Save');

$m->get( $url );
$m->content_lacks ('customsearch@localhost', 'requestor not displayed ');


# try to disable General from queue list

# Note that there's a small problem in the current implementation,
# since ticked quese are wanted, we do the invesrsion.  So any
# queue added during the queue list setting will be unticked.
my $nlinks = $#{$m->find_all_links( text => "General" )};
$m->get ($cus_qs);
$m->form_name ('Preferences');
$m->untick('Want-General', '1');
$m->click_button (name => 'Save');

$m->get( $url );
is ($#{$m->find_all_links( text => "General" )}, $nlinks - 1,
    'General gone from queue list');

# get it back
$m->get ($cus_qs);
$m->form_name ('Preferences');
$m->tick('Want-General', '1');
$m->click_button (name => 'Save');

$m->get( $url );
is ($#{$m->find_all_links( text => "General" )}, $nlinks,
    'General back in queue list');
