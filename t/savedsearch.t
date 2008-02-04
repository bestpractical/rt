use strict;
use warnings;
use RT::Test; use Test::More tests => 26;
use RT::Model::User;
use RT::Model::Group;
use RT::Model::Ticket;
use RT::Model::Queue;

use_ok('RT::SavedSearch');
use_ok('RT::SavedSearches');


# Set up some infrastructure.  These calls are tested elsewhere.

my $searchuser = RT::Model::User->new(current_user => RT->system_user);
my ($ret, $msg) = $searchuser->create(name => 'searchuser'.$$,
		    privileged => 1,
		    email => "searchuser\@p$$.example.com",
		    real_name => 'Search user');
ok($ret, "Created searchuser: $msg");
$searchuser->principal_object->grant_right(right => 'LoadSavedSearch');
$searchuser->principal_object->grant_right(right => 'CreateSavedSearch');
$searchuser->principal_object->grant_right(right => 'ModifySelf');

# This is the group whose searches searchuser should be able to see.
my $ingroup = RT::Model::Group->new(current_user => RT->system_user);
$ingroup->create_user_defined_group(name => 'searchgroup1'.$$);
$ingroup->add_member($searchuser->id);
$searchuser->principal_object->grant_right(right => 'EditSavedSearches', object => $ingroup);
$searchuser->principal_object->grant_right(right => 'ShowSavedSearches', object => $ingroup);

# This is the group whose searches searchuser should not be able to see.
my $outgroup = RT::Model::Group->new(current_user => RT->system_user);
$outgroup->create_user_defined_group(name => 'searchgroup2'.$$);
$outgroup->add_member(RT->system_user->id);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
$queue->create(name => 'SearchQueue'.$$);
$searchuser->principal_object->grant_right(right => 'SeeQueue', object => $queue);
$searchuser->principal_object->grant_right(right => 'ShowTicket', object => $queue);
$searchuser->principal_object->grant_right(right => 'OwnTicket', object => $queue);


my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->create(queue => $queue->id,
		requestor => [ $searchuser->name ],
		owner => $searchuser,
		subject => 'saved search test');


# Now start the search madness.
my $format = '\'   <b><a href="/Ticket/Display.html?id=__id__">__id__</a></b>/TITLE:#\',
\'<b><a href="/Ticket/Display.html?id=__id__">__subject__</a></b>/TITLE:subject\',
\'__Status__\',
\'__Queuename__\',
\'__owner_name__\',
\'__Priority__\',
\'__NEWLINE__\',
\'\',
\'<small>__Requestors__</small>\',
\'<small>__CreatedRelative__</small>\',
\'<small>__ToldRelative__</small>\',
\'<small>__LastUpdatedRelative__</small>\',
\'<small>__time_left__</small>\'';

my $curruser = RT::CurrentUser->new(id => $searchuser->id);
warn "My search user = ".$searchuser->id;
my $mysearch = RT::SavedSearch->new( current_user => $curruser );
( $ret, $msg ) = $mysearch->save(
    privacy      => 'RT::Model::User-' . $searchuser->id,
    type         => 'Ticket',
    name         => 'owned by me',
    search_params => {
        'format' => $format,
        'query'  => "Owner = '" . $searchuser->name . "'"
    }
);


ok($ret, "mysearch was Created - $msg");


my $groupsearch = RT::SavedSearch->new(current_user => $curruser);
($ret, $msg) = $groupsearch->save(privacy => 'RT::Model::Group-' . $ingroup->id,
				  type => 'Ticket',
				  name => 'search queue',
				  search_params => {'format' => $format,
						   'query' => "Queue = '"
						       . $queue->name . "'"});
ok($ret, "groupsearch was Created");

my $othersearch = RT::SavedSearch->new(current_user => $curruser);
($ret, $msg) = $othersearch->save(privacy => 'RT::Model::Group-' . $outgroup->id,
				  type => 'Ticket',
				  name => 'searchuser requested',
				  search_params => {'format' => $format,
						   'query' => 
						       "Requestor.name LIKE 'search'"});
ok(!$ret, "othersearch NOT Created");
like($msg, qr/Failed to load object for/, "...for the right reason");

$othersearch = RT::SavedSearch->new(current_user => RT->system_user);
($ret, $msg) = $othersearch->save(privacy => 'RT::Model::Group-' . $outgroup->id,
				  type => 'Ticket',
				  name => 'searchuser requested',
				  search_params => {'format' => $format,
						   'query' => 
						       "Requestor.name LIKE 'search'"});
ok($ret, "othersearch Created by systemuser");

# Now try to load some searches.

# This should work.
my $loadedsearch1 = RT::SavedSearch->new(current_user => $curruser);
$loadedsearch1->load('RT::Model::User-'.$curruser->id, $mysearch->id);
is($loadedsearch1->id, $mysearch->id, "Loaded mysearch");
like($loadedsearch1->get_parameter('query'), qr/Owner/, 
     "Retrieved query of mysearch");
# Check through the other accessor methods.
is($loadedsearch1->privacy, 'RT::Model::User-' . $curruser->id,
   "privacy of mysearch correct");
is($loadedsearch1->name, 'owned by me', "name of mysearch correct");
is($loadedsearch1->type, 'Ticket', "Type of mysearch correct");

# See if it can be used to search for tickets.
my $tickets = RT::Model::TicketCollection->new(current_user => $curruser);
$tickets->from_sql($loadedsearch1->get_parameter('query'));
diag $loadedsearch1->get_parameter('query');
is($tickets->count, 1, "Found a ticket");

# This should fail -- wrong object.
# my $loadedsearch2 = RT::SavedSearch->new($curruser);
# $loadedsearch2->load('RT::Model::User-'.$curruser->id, $groupsearch->id);
# isnt($loadedsearch2->id, $othersearch->id, "Didn't load groupsearch as mine");
# ...but this should succeed.
my $loadedsearch3 = RT::SavedSearch->new(current_user => $curruser);
$loadedsearch3->load('RT::Model::Group-'.$ingroup->id, $groupsearch->id);
is($loadedsearch3->id, $groupsearch->id, "Loaded groupsearch");
like($loadedsearch3->get_parameter('query'), qr/Queue/,
     "Retrieved query of groupsearch");
# Can it get tickets?
$tickets = RT::Model::TicketCollection->new(current_user => $curruser);
$tickets->from_sql($loadedsearch3->get_parameter('query'));
is($tickets->count, 1, "Found a ticket");

# This should fail -- no permission.
my $loadedsearch4 = RT::SavedSearch->new(current_user => $curruser);
$loadedsearch4->load($othersearch->privacy, $othersearch->id);
isnt($loadedsearch4->id, $othersearch->id, "Did not load othersearch");

# Try to update an existing search.
$loadedsearch1->update(	search_params => {'format' => $format,
			'query' => "Queue = '" . $queue->name . "'" } );
like($loadedsearch1->get_parameter('query'), qr/Queue/,
     "Updated mysearch parameter");
is($loadedsearch1->type, 'Ticket', "mysearch is still for tickets");
is($loadedsearch1->privacy, 'RT::Model::User-'.$curruser->id,
   "mysearch still belongs to searchuser");
like($mysearch->get_parameter('query'), qr/Queue/, "other mysearch object updated");


## right ho.  Test the pseudo-collection object.

my $genericsearch = RT::SavedSearch->new(current_user => $curruser);
$genericsearch->save(name => 'generic search',
		     type => 'all',
		     search_params => {'query' => "Queue = 'General'"});

my $ticketsearches = RT::SavedSearches->new(current_user => $curruser);
$ticketsearches->limit_to_privacy('RT::Model::User-'.$curruser->id, 'Ticket');
is($ticketsearches->count, 1, "Found searchuser's ticket searches");

my $allsearches = RT::SavedSearches->new(current_user => $curruser);
$allsearches->limit_to_privacy('RT::Model::User-'.$curruser->id);
is($allsearches->count, 2, "Found all searchuser's searches");

# Delete a search.
($ret, $msg) = $genericsearch->delete;
ok($ret, "Deleted genericsearch ".$msg);



$allsearches = RT::SavedSearches->new(current_user => $curruser);
$allsearches->limit_to_privacy('RT::Model::User-'.$curruser->id);
is($allsearches->count, 1, "Found all searchuser's searches after deletion");

while (my $search = $allsearches->next) {
    diag($search->id, $search->name);
}

