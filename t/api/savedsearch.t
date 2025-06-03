use strict;
use warnings;
BEGIN { $ENV{'LANG'} = 'C' }

use RT::Test tests => undef;

use_ok('RT::SavedSearch');
use_ok('RT::SavedSearches');

use Test::Warn;

# Set up some infrastructure.  These calls are tested elsewhere.

my $searchuser = RT::User->new(RT->SystemUser);
my ($ret, $msg) = $searchuser->Create(Name => 'searchuser'.$$,
                    Privileged => 1,
                    EmailAddress => "searchuser\@p$$.example.com",
                    RealName => 'Search user');
ok($ret, "created searchuser: $msg");
$searchuser->PrincipalObj->GrantRight(Right => 'LoadSavedSearch');
$searchuser->PrincipalObj->GrantRight(Right => 'SeeOwnSavedSearch');
$searchuser->PrincipalObj->GrantRight(Right => 'AdminOwnSavedSearch');

# This is the group whose searches searchuser should be able to see.
my $ingroup = RT::Group->new(RT->SystemUser);
$ingroup->CreateUserDefinedGroup(Name => 'searchgroup1'.$$);
$ingroup->AddMember($searchuser->Id);

diag('Check saved search rights');
my @create_objects = RT::SavedSearch->new($searchuser)->ObjectsForCreating;

is( scalar @create_objects, 1, 'Got one Privacy option for saving searches');
is( $create_objects[0]->Id, $searchuser->Id, 'Privacy option is personal saved search');

$searchuser->PrincipalObj->GrantRight(Right => 'AdminGroupSavedSearch',
                                      Object => $ingroup);
$searchuser->PrincipalObj->GrantRight(Right => 'SeeGroupSavedSearch',
                                      Object => $ingroup);

@create_objects = RT::SavedSearch->new($searchuser)->ObjectsForCreating;
is( scalar @create_objects, 2, 'Got two Privacy options for saving searches');
is( $create_objects[1]->Id, $ingroup->Id, 'Second Privacy option is group saved search');

# This is the group whose searches searchuser should not be able to see.
my $outgroup = RT::Group->new(RT->SystemUser);
$outgroup->CreateUserDefinedGroup(Name => 'searchgroup2'.$$);
$outgroup->AddMember(RT->SystemUser->Id);

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Create(Name => 'SearchQueue'.$$);
$searchuser->PrincipalObj->GrantRight(Right => 'SeeQueue', Object => $queue);
$searchuser->PrincipalObj->GrantRight(Right => 'ShowTicket', Object => $queue);
$searchuser->PrincipalObj->GrantRight(Right => 'OwnTicket', Object => $queue);


my $ticket = RT::Ticket->new(RT->SystemUser);
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
( $ret, $msg ) = $mysearch->Create(
    PrincipalId => $searchuser->Id,
    Type        => 'Ticket',
    Name        => 'owned by me',
    Content     => {
        'Format' => $format,
        'Query'  => "Owner = '" . $searchuser->Name . "'",
    }
);

ok($ret, "mysearch was created");


my $groupsearch = RT::SavedSearch->new($curruser);
( $ret, $msg ) = $groupsearch->Create(
    PrincipalId  => $ingroup->Id,
    Type         => 'Ticket',
    Name         => 'search queue',
    Content      => {
        'Format' => $format,
        'Query'  => "Queue = '" . $queue->Name . "'",
    }
);

ok($ret, "groupsearch was created");

my $othersearch = RT::SavedSearch->new($curruser);
( $ret, $msg ) = $othersearch->Create(
    PrincipalId => $outgroup->Id,
    Type        => 'Ticket',
    Name        => 'searchuser requested',
    Content     => {
        'Format' => $format,
        'Query'  => "Requestor.Name LIKE 'search'",
    }
);

ok(!$ret, "othersearch NOT created");
like($msg, qr/Permission Denied/, "...for the right reason");

$othersearch = RT::SavedSearch->new(RT->SystemUser);
( $ret, $msg ) = $othersearch->Create(
    PrincipalId => $outgroup->Id,
    Type        => 'Ticket',
    Name        => 'searchuser requested',
    Content     => {
        'Format' => $format,
        'Query'  => "Requestor.Name LIKE 'search'",
    }
);

ok($ret, "othersearch created by systemuser");

diag('Test loading SavedSearches');
my $loadedsearch1 = RT::SavedSearch->new($curruser);
$loadedsearch1->Load($mysearch->Id);
is($loadedsearch1->Id, $mysearch->Id, "Loaded mysearch");
like($loadedsearch1->Content->{Query}, qr/Owner/, 
     "Retrieved query of mysearch");
# Check through the other accessor methods.
is($loadedsearch1->PrincipalId, $curruser->Id, "Privacy of mysearch correct");
is($loadedsearch1->Name, 'owned by me', "Name of mysearch correct");
is($loadedsearch1->Type, 'Ticket', "Type of mysearch correct");
like($loadedsearch1->GetOption('Query'), qr/Owner/,
     "Retrieved option Query");

my ($set_ok, $set_msg) = $loadedsearch1->SetOption('Test', 'Value');
ok( $set_ok, 'Set Test option');
is($loadedsearch1->GetOption('Test'), 'Value', "Got Test option");
my ($delete_ok, $delete_msg) = $loadedsearch1->DeleteOption('Test');
ok( $delete_ok, $delete_msg);
is($loadedsearch1->GetOption('Test'), undef, "Test option is deleted");

# See if it can be used to search for tickets.
my $tickets = RT::Tickets->new($curruser);
$tickets->FromSQL($loadedsearch1->Content->{Query});
is($tickets->Count, 1, "Found a ticket");

# This should fail -- wrong object.
# my $loadedsearch2 = RT::SavedSearch->new($curruser);
# $loadedsearch2->Load('RT::User-'.$curruser->Id, $groupsearch->Id);
# isnt($loadedsearch2->Id, $othersearch->Id, "Didn't load groupsearch as mine");
# ...but this should succeed.
my $loadedsearch3 = RT::SavedSearch->new($curruser);
$loadedsearch3->Load($groupsearch->Id);
is($loadedsearch3->Id, $groupsearch->Id, "Loaded groupsearch");
like($loadedsearch3->Content->{Query}, qr/Queue/,
     "Retrieved query of groupsearch");
# Can it get tickets?
$tickets = RT::Tickets->new($curruser);
$tickets->FromSQL($loadedsearch3->Content->{Query});
is($tickets->Count, 1, "Found a ticket");

# This should fail -- no permission.
my $loadedsearch4 = RT::SavedSearch->new($curruser);
$loadedsearch4->Load($othersearch->Id);
isnt($loadedsearch4->Name, $othersearch->Name, "Can not access othersearch");

# Try to update an existing search.
$loadedsearch1->SetContent( {'Format' => $format,
                        'Query' => "Queue = '" . $queue->Name . "'" } );
like($loadedsearch1->Content->{Query}, qr/Queue/, "Updated mysearch parameter");
is($loadedsearch1->Type, 'Ticket', "mysearch is still for tickets");
is($loadedsearch1->PrincipalId, $curruser->Id, "mysearch still belongs to searchuser");
like($mysearch->Content->{Query}, qr/Queue/, "other mysearch object updated");


## Right ho.  Test the pseudo-collection object.

my $genericsearch = RT::SavedSearch->new($curruser);
$genericsearch->Create(Name => 'generic search',
                     Type => 'all',
                     Content => {'Query' => "Queue = 'General'"});

my $ticketsearches = RT::SavedSearches->new($curruser);
$ticketsearches->Limit(FIELD => 'PrincipalId', VALUE => $curruser->Id);
$ticketsearches->Limit(FIELD => 'Type', VALUE => 'Ticket');
is($ticketsearches->Count, 1, "Found searchuser's ticket searches");

my $allsearches = RT::SavedSearches->new($curruser);
$allsearches->Limit(FIELD => 'PrincipalId', VALUE => $curruser->Id);
is($allsearches->Count, 2, "Found all searchuser's searches");

# Delete a search.
($ret, $msg) = $genericsearch->Delete;
ok($ret, "Deleted genericsearch");
$allsearches->Limit(FIELD => 'PrincipalId', VALUE => $curruser->Id);
is($allsearches->Count, 1, "Found all searchuser's searches after deletion");

done_testing();
