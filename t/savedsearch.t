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
$searchuser->principal_object->GrantRight(Right => 'LoadSavedSearch');
$searchuser->principal_object->GrantRight(Right => 'CreateSavedSearch');
$searchuser->principal_object->GrantRight(Right => 'ModifySelf');

# This is the group whose searches searchuser should be able to see.
my $ingroup = RT::Model::Group->new(current_user => RT->system_user);
$ingroup->create_userDefinedGroup(name => 'searchgroup1'.$$);
$ingroup->AddMember($searchuser->id);
$searchuser->principal_object->GrantRight(Right => 'EditSavedSearches',
				      Object => $ingroup);
$searchuser->principal_object->GrantRight(Right => 'ShowSavedSearches',
				      Object => $ingroup);

# This is the group whose searches searchuser should not be able to see.
my $outgroup = RT::Model::Group->new(current_user => RT->system_user);
$outgroup->create_userDefinedGroup(name => 'searchgroup2'.$$);
$outgroup->AddMember(RT->system_user->id);

my $queue = RT::Model::Queue->new(current_user => RT->system_user);
$queue->create(name => 'SearchQueue'.$$);
$searchuser->principal_object->GrantRight(Right => 'SeeQueue', Object => $queue);
$searchuser->principal_object->GrantRight(Right => 'ShowTicket', Object => $queue);
$searchuser->principal_object->GrantRight(Right => 'OwnTicket', Object => $queue);


my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->create(Queue => $queue->id,
		Requestor => [ $searchuser->name ],
		Owner => $searchuser,
		Subject => 'saved search test');


# Now start the search madness.
my $curruser = RT::CurrentUser->new($searchuser);
my $format = '\'   <b><a href="/Ticket/Display.html?id=__id__">__id__</a></b>/TITLE:#\',
\'<b><a href="/Ticket/Display.html?id=__id__">__Subject__</a></b>/TITLE:Subject\',
\'__Status__\',
\'__Queuename__\',
\'__Ownername__\',
\'__Priority__\',
\'__NEWLINE__\',
\'\',
\'<small>__Requestors__</small>\',
\'<small>__CreatedRelative__</small>\',
\'<small>__ToldRelative__</small>\',
\'<small>__LastUpdatedRelative__</small>\',
\'<small>__time_left__</small>\'';

my $mysearch = RT::SavedSearch->new($curruser);
($ret, $msg) = $mysearch->Save(Privacy => 'RT::Model::User-' . $searchuser->id,
			       Type => 'Ticket',
			       name => 'owned by me',
			       SearchParams => {'Format' => $format,
						'Query' => "Owner = '" 
						    . $searchuser->name 
						    . "'"});
ok($ret, "mysearch was Created");


my $groupsearch = RT::SavedSearch->new($curruser);
($ret, $msg) = $groupsearch->Save(Privacy => 'RT::Model::Group-' . $ingroup->id,
				  Type => 'Ticket',
				  name => 'search queue',
				  SearchParams => {'Format' => $format,
						   'Query' => "Queue = '"
						       . $queue->name . "'"});
ok($ret, "groupsearch was Created");

my $othersearch = RT::SavedSearch->new($curruser);
($ret, $msg) = $othersearch->Save(Privacy => 'RT::Model::Group-' . $outgroup->id,
				  Type => 'Ticket',
				  name => 'searchuser requested',
				  SearchParams => {'Format' => $format,
						   'Query' => 
						       "Requestor.name LIKE 'search'"});
ok(!$ret, "othersearch NOT Created");
like($msg, qr/Failed to load object for/, "...for the right reason");

$othersearch = RT::SavedSearch->new(current_user => RT->system_user);
($ret, $msg) = $othersearch->Save(Privacy => 'RT::Model::Group-' . $outgroup->id,
				  Type => 'Ticket',
				  name => 'searchuser requested',
				  SearchParams => {'Format' => $format,
						   'Query' => 
						       "Requestor.name LIKE 'search'"});
ok($ret, "othersearch Created by systemuser");

# Now try to load some searches.

# This should work.
my $loadedsearch1 = RT::SavedSearch->new($curruser);
$loadedsearch1->load('RT::Model::User-'.$curruser->id, $mysearch->id);
is($loadedsearch1->id, $mysearch->id, "Loaded mysearch");
like($loadedsearch1->GetParameter('Query'), qr/Owner/, 
     "Retrieved query of mysearch");
# Check through the other accessor methods.
is($loadedsearch1->Privacy, 'RT::Model::User-' . $curruser->id,
   "Privacy of mysearch correct");
is($loadedsearch1->name, 'owned by me', "name of mysearch correct");
is($loadedsearch1->Type, 'Ticket', "Type of mysearch correct");

# See if it can be used to search for tickets.
my $tickets = RT::Model::TicketCollection->new($curruser);
$tickets->from_sql($loadedsearch1->GetParameter('Query'));
is($tickets->count, 1, "Found a ticket");

# This should fail -- wrong object.
# my $loadedsearch2 = RT::SavedSearch->new($curruser);
# $loadedsearch2->load('RT::Model::User-'.$curruser->id, $groupsearch->id);
# isnt($loadedsearch2->id, $othersearch->id, "Didn't load groupsearch as mine");
# ...but this should succeed.
my $loadedsearch3 = RT::SavedSearch->new($curruser);
$loadedsearch3->load('RT::Model::Group-'.$ingroup->id, $groupsearch->id);
is($loadedsearch3->id, $groupsearch->id, "Loaded groupsearch");
like($loadedsearch3->GetParameter('Query'), qr/Queue/,
     "Retrieved query of groupsearch");
# Can it get tickets?
$tickets = RT::Model::TicketCollection->new($curruser);
$tickets->from_sql($loadedsearch3->GetParameter('Query'));
is($tickets->count, 1, "Found a ticket");

# This should fail -- no permission.
my $loadedsearch4 = RT::SavedSearch->new($curruser);
$loadedsearch4->load($othersearch->Privacy, $othersearch->id);
isnt($loadedsearch4->id, $othersearch->id, "Did not load othersearch");

# Try to update an existing search.
$loadedsearch1->Update(	SearchParams => {'Format' => $format,
			'Query' => "Queue = '" . $queue->name . "'" } );
like($loadedsearch1->GetParameter('Query'), qr/Queue/,
     "Updated mysearch parameter");
is($loadedsearch1->Type, 'Ticket', "mysearch is still for tickets");
is($loadedsearch1->Privacy, 'RT::Model::User-'.$curruser->id,
   "mysearch still belongs to searchuser");
like($mysearch->GetParameter('Query'), qr/Queue/, "other mysearch object updated");


## Right ho.  Test the pseudo-collection object.

my $genericsearch = RT::SavedSearch->new($curruser);
$genericsearch->Save(name => 'generic search',
		     Type => 'all',
		     SearchParams => {'Query' => "Queue = 'General'"});

my $ticketsearches = RT::SavedSearches->new($curruser);
$ticketsearches->LimitToPrivacy('RT::Model::User-'.$curruser->id, 'Ticket');
is($ticketsearches->count, 1, "Found searchuser's ticket searches");

my $allsearches = RT::SavedSearches->new($curruser);
$allsearches->LimitToPrivacy('RT::Model::User-'.$curruser->id);
is($allsearches->count, 2, "Found all searchuser's searches");

# Delete a search.
($ret, $msg) = $genericsearch->delete;
ok($ret, "Deleted genericsearch");
$allsearches->LimitToPrivacy('RT::Model::User-'.$curruser->id);
is($allsearches->count, 1, "Found all searchuser's searches after deletion");

