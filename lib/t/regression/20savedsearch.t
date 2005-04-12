use RT;
use Test::More qw/no_plan/;
use RT::User;
use RT::Group;
use RT::Ticket;
use RT::Queue;

use_ok(RT::SavedSearch);
use_ok(RT::SavedSearches);

RT::LoadConfig();
RT::Init();

# Set up some infrastructure.  These calls are tested elsewhere.

my $searchuser = RT::User->new($RT::SystemUser);
my ($ret, $msg) = $searchuser->Create(Name => 'searchuser'.$$,
		    Privileged => 1,
		    EmailAddress => "searchuser\@p$$.example.com",
		    RealName => 'Search user');
ok($ret, "created searchuser: $msg");
$searchuser->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$searchuser->PrincipalObj->GrantRight(Right => 'CreateSavedSearch');
$searchuser->PrincipalObj->GrantRight(Right => 'ModifySelf');

# This is the group whose searches searchuser should be able to see.
my $ingroup = RT::Group->new($RT::SystemUser);
$ingroup->CreateUserDefinedGroup(Name => 'searchgroup1'.$$);
$ingroup->AddMember($searchuser->Id);
$searchuser->PrincipalObj->GrantRight(Right => 'EditSavedSearches',
				      Object => $ingroup);
$searchuser->PrincipalObj->GrantRight(Right => 'ShowSavedSearches',
				      Object => $ingroup);

# This is the group whose searches searchuser should not be able to see.
my $outgroup = RT::Group->new($RT::SystemUser);
$outgroup->CreateUserDefinedGroup(Name => 'searchgroup2'.$$);
$outgroup->AddMember($RT::SystemUser->Id);

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);
$searchuser->PrincipalObj->GrantRight(Right => 'SeeQueue', Object => $queue);
$searchuser->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);
$searchuser->PrincipalObj->GrantRight(Right => 'OwnTicket', Object => $queue);


my $ticket = RT::Ticket->new($RT::SystemUser);
$ticket->Create(Queue => $queue->Id,
		Requestor => [ $searchuser->Name ],
		Owner => $searchuser,
		Subject => 'saved search test');


# Now start the search madness.
my $curruser = RT::CurrentUser->new($searchuser);
my $format = '\'   <b><a href="/Ticket/Display.html?id=__id__">__id__</a></b>/TITLE:#\',
\'<b><a href="/Ticket/Display.html?id=__id__">__Subject__</a></b>/TITLE:Subject\',
\'__Status__\',
\'__QueueName__\',
\'__OwnerName__\',
\'__Priority__\',
\'__NEWLINE__\',
\'\',
\'<small>__Requestors__</small>\',
\'<small>__CreatedRelative__</small>\',
\'<small>__ToldRelative__</small>\',
\'<small>__LastUpdatedRelative__</small>\',
\'<small>__TimeLeft__</small>\'';

my $mysearch = RT::SavedSearch->new($curruser);
$mysearch->Save(Privacy => 'RT::User-' . $searchuser->Id,
		Type => 'Ticket',
		Name => 'owned by me',
		SearchParams => {'Format' => $format,
				 'Query' => "Owner = '" 
				     . $searchuser->Name . "'"});
is($mysearch->Type, 'Ticket', "mysearch was created");


my $groupsearch = RT::SavedSearch->new($curruser);
$groupsearch->Save(Privacy => 'RT::Group-' . $ingroup->Id,
		   Type => 'Ticket',
		   Name => 'search queue',
		   SearchParams => {'Format' => $format,
				    'Query' => "Queue = '"
					. $queue->Name . "'"});
is($groupsearch->Type, 'Ticket', "groupsearch was created");
like($groupsearch->GetParameter('Query'), qr/Queue/, 
     "Retrieved query of groupsearch");

my $othersearch = RT::SavedSearch->new($curruser);
$othersearch->Save(Privacy => 'RT::Group-' . $outgroup->Id,
		   Type => 'Ticket',
		   Name => 'searchuser requested',
		   SearchParams => {'Format' => $format,
				    'Query' => 
					"Requestor.Name LIKE 'search'"});
is($othersearch->Id, 0, "othersearch NOT created");

$othersearch = RT::SavedSearch->new($RT::SystemUser);
$othersearch->Save(Privacy => 'RT::Group-' . $outgroup->Id,
		   Type => 'Ticket',
		   Name => 'searchuser requested',
		   SearchParams => {'Format' => $format,
				    'Query' => 
					"Requestor.Name LIKE 'search'"});
is($othersearch->Type, 'Ticket', "othersearch created by systemuser");
like($othersearch->GetParameter('Query'), qr/Requestor/, 
     "Retrieved query of othersearch");

# Now try to load some searches.

# This should work.
my $loadedsearch1 = RT::SavedSearch->new($curruser);
$loadedsearch1->Load('RT::User-'.$curruser->Id, $mysearch->Id);
is($loadedsearch1->Id, $mysearch->Id, "Loaded mysearch");
like($loadedsearch1->GetParameter('Query'), qr/Owner/, 
     "Retrieved query of mysearch");
# Check through the other accessor methods.
is($loadedsearch1->Privacy, 'RT::User-' . $curruser->Id,
   "Privacy of mysearch correct");
is($loadedsearch1->Name, 'owned by me', "Name of mysearch correct");
is($loadedsearch1->Type, 'Ticket', "Type of mysearch correct");

# See if it can be used to search for tickets.
my $tickets = RT::Tickets->new($curruser);
$tickets->FromSQL($loadedsearch1->GetParameter('Query'));
is($tickets->Count, 1, "Found a ticket");

# This should fail -- wrong object.
# my $loadedsearch2 = RT::SavedSearch->new($curruser);
# $loadedsearch2->Load('RT::User-'.$curruser->Id, $groupsearch->Id);
# isnt($loadedsearch2->Id, $othersearch->Id, "Didn't load groupsearch as mine");
# ...but this should succeed.
my $loadedsearch3 = RT::SavedSearch->new($curruser);
$loadedsearch3->Load('RT::Group-'.$ingroup->Id, $groupsearch->Id);
is($loadedsearch3->Id, $groupsearch->Id, "Loaded groupsearch");
like($loadedsearch3->GetParameter('Query'), qr/Queue/,
     "Retrieved query of groupsearch");
# Can it get tickets?
$tickets = RT::Tickets->new($curruser);
$tickets->FromSQL($loadedsearch3->GetParameter('Query'));
is($tickets->Count, 1, "Found a ticket");

# This should fail -- no permission.
my $loadedsearch4 = RT::SavedSearch->new($curruser);
$loadedsearch4->Load($othersearch->Privacy, $othersearch->Id);
isnt($loadedsearch4->Id, $othersearch->Id, "Did not load othersearch");

# Try to update an existing search.
$loadedsearch1->Update({'Format' => $format,
			'Query' => "Queue = '" . $queue->Name . "'" });
like($loadedsearch1->GetParameter('Query'), qr/Queue/,
     "Updated mysearch parameter");
is($loadedsearch1->Type, 'Ticket', "mysearch is still for tickets");
is($loadedsearch1->Privacy, 'RT::User-'.$curruser->Id,
   "mysearch still belongs to searchuser");
like($mysearch->GetParameter('Query'), qr/Queue/, "other mysearch object updated");


## Right ho.  Test the pseudo-collection object.

my $genericsearch = RT::SavedSearch->new($curruser);
$genericsearch->Save(Name => 'generic search',
		     Type => 'all',
		     SearchParams => {'Query' => "Queue = 'General'"});

my $ticketsearches = RT::SavedSearches->new($curruser);
$ticketsearches->LimitToPrivacy('RT::User-'.$curruser->Id, 'Ticket');
is($ticketsearches->Count, 1, "Found searchuser's ticket searches");

my $allsearches = RT::SavedSearches->new($curruser);
$allsearches->LimitToPrivacy('RT::User-'.$curruser->Id);
is($allsearches->Count, 2, "Found all searchuser's searches");
