
# tests relating to searching. Especially around custom fields, and
# corner cases.

use strict;
use warnings;

use RT::Test tests => undef;

# setup the queue

my $q = RT::Queue->new(RT->SystemUser);
my $queue = 'SearchTests-'.$$;
$q->Create(Name => $queue);
ok ($q->id, "Created the queue");


# and setup the CFs
# we believe the Type shouldn't matter.

my $cf = RT::CustomField->new(RT->SystemUser);
$cf->Create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf->id, "Created the SearchTest CF");
my $cflabel = "CustomField-".$cf->id;

my $cf2 = RT::CustomField->new(RT->SystemUser);
$cf2->Create(Name => 'SearchTest2', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf2->id, "Created the SearchTest2 CF");
my $cflabel2 = "CustomField-".$cf2->id;

my $cf3 = RT::CustomField->new(RT->SystemUser);
$cf3->Create(Name => 'SearchTest3', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf3->id, "Created the SearchTest3 CF");
my $cflabel3 = "CustomField-".$cf3->id;


# There was a bug involving a missing join to ObjectCustomFields that
# caused spurious results on negative searches if another custom field
# with the same name existed on a different queue.  Hence, we make
# duplicate CFs on a different queue here
my $dup = RT::Queue->new(RT->SystemUser);
$dup->Create(Name => $queue . "-Copy");
ok ($dup->id, "Created the duplicate queue");
my $dupcf = RT::CustomField->new(RT->SystemUser);
$dupcf->Create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the duplicate SearchTest CF");
$dupcf = RT::CustomField->new(RT->SystemUser);
$dupcf->Create(Name => 'SearchTest2', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the SearchTest2 CF");
$dupcf = RT::CustomField->new(RT->SystemUser);
$dupcf->Create(Name => 'SearchTest3', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the SearchTest3 CF");


# setup some tickets
# we'll need a small pile of them, to test various combinations and nulls.
# there's probably a way to think harder and do this with fewer


my $t1 = RT::Ticket->new(RT->SystemUser);
my ( $id, undef, $msg ) = $t1->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Description => 'This is an urgent database issue',
    Requestor  => ['search1@example.com'],
    $cflabel   => 'foo1',
    $cflabel2  => 'bar1',
    $cflabel3  => 'qux1',
);
ok( $id, $msg );


my $t2 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t2->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest2',
    Description => 'Routine server maintenance required',
    Requestor  => ['search2@example.com'],
#    $cflabel   => 'foo2',
    $cflabel2  => 'bar2',
    $cflabel3  => 'qux2',
);
ok( $id, $msg );

my $t3 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t3->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest3',
    Description => 'Urgent network problem needs attention',
    Requestor  => ['search3@example.com'],
    $cflabel   => 'foo3',
#    $cflabel2  => 'bar3',
    $cflabel3  => 'qux3',
);
ok( $id, $msg );

my $t4 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t4->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest4',
    Requestor  => ['search4@example.com'],
    $cflabel   => 'foo4',
    $cflabel2  => 'bar4',
#    $cflabel3  => 'qux4',
);
ok( $id, $msg );

my $t5 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t5->Create(
    Queue      => $q->id,
#    Subject    => 'SearchTest5',
    Requestor  => ['search5@example.com'],
    $cflabel   => 'foo5',
    $cflabel2  => 'bar5',
    $cflabel3  => 'qux5',
);
ok( $id, $msg );

my $t6 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t6->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest6',
#    Requestor  => ['search6@example.com'],
    $cflabel   => 'foo6',
    $cflabel2  => 'bar6',
    $cflabel3  => 'qux6',
);
ok( $id, $msg );

my $t7 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t7->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest7',
    Requestor  => ['search7@example.com'],
#    $cflabel   => 'foo7',
#    $cflabel2  => 'bar7',
    $cflabel3  => 'qux7',
);
ok( $id, $msg );

# we have tickets. start searching
my $tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue'");
is($tix->Count, 7, "found all the tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;


# very simple searches. both CF and normal

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest = 'foo1'");
is($tix->Count, 1, "matched identical subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue LIKE '$queue' AND CF.SearchTest = 'foo1'");
is($tix->Count, 1, "matched identical subject and LIKE Queue")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'foo1'");
is($tix->Count, 1, "matched LIKE subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue LIKE '$queue' AND CF.SearchTest LIKE 'foo1'");
is($tix->Count, 1, "matched LIKE queue and LIKE subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest = 'foo'");
is($tix->Count, 0, "IS a regexp match")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'foo'");
is($tix->Count, 5, "matched LIKE subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;


$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest IS NULL");
is($tix->Count, 2, "IS null CF")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors LIKE 'search1'");
is($tix->Count, 1, "LIKE requestor")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors = 'search1\@example.com'");
is($tix->Count, 1, "IS requestor")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors LIKE 'search'");
is($tix->Count, 6, "LIKE requestor")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors IS NULL");
is($tix->Count, 1, "Search for no requestor")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Subject = 'SearchTest1'");
is($tix->Count, 1, "IS subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Subject LIKE 'SearchTest1'");
is($tix->Count, 1, "LIKE subject")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Subject = ''");
is($tix->Count, 1, "found one ticket")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Subject LIKE 'SearchTest'");
is($tix->Count, 6, "found two ticket")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Subject LIKE 'qwerty'");
is($tix->Count, 0, "found zero ticket")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Description LIKE 'urgent'");
is($tix->Count, 2, "Description LIKE 'urgent' finds two tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Description LIKE 'database'");
is($tix->Count, 1, "Description LIKE 'database' finds one ticket")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Description LIKE 'server'");
is($tix->Count, 1, "Description LIKE 'server' finds one ticket")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Description LIKE 'nonexistent'");
is($tix->Count, 0, "Description LIKE 'nonexistent' finds zero tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test __CurrentUser__ special value
my $alice = RT::Test->load_or_create_user(
    Name         => 'alice',
    EmailAddress => 'alice@example.com',
    Privileged   => 1,
);
ok($alice->id, 'Created user alice');

ok( RT::Test->add_rights(
        {   Principal => 'Privileged',
            Right     => [qw(ShowTicket OwnTicket CreateTicket ModifyTicket CommentOnTicket)],
            Object    => $q,
        }
    ),
    'Add ticket rights for alice'
);

my $current_alice = RT::CurrentUser->new( RT->SystemUser );
$current_alice->Load( $alice->Id );

# Create tickets owned by alice
my $t_alice_owned = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_alice_owned->Create(
    Queue   => $q->id,
    Subject => 'Ticket owned by alice',
    Owner   => $alice->id,
);
ok( $id, "Created ticket owned by alice" );

# Create ticket created by alice (but owned by Nobody)
my $t_alice_created = RT::Ticket->new($current_alice);
( $id, undef, $msg ) = $t_alice_created->Create(
    Queue   => $q->id,
    Subject => 'Ticket created by alice',
);
ok( $id, "Created ticket created by alice" );

# Create ticket updated by alice
my $t_alice_updated = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_alice_updated->Create(
    Queue   => $q->id,
    Subject => 'Ticket updated by alice',
);
ok( $id, "Created ticket to be updated by alice" );
my $alice_ticket = RT::Ticket->new($current_alice);
$alice_ticket->Load($t_alice_updated->id);
my ($ok, $txn_msg) = $alice_ticket->Comment(Content => 'Alice commenting');
ok($ok, "Alice commented on ticket") or diag("Error: $txn_msg");

# Test Owner.id = '__CurrentUser__'
$tix = RT::Tickets->new($current_alice);
$tix->FromSQL("Queue = '$queue' AND Owner.id = '__CurrentUser__'");
is($tix->Count, 1, "Owner.id = '__CurrentUser__' finds tickets owned by current user (alice)")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;
is($tix->First->id, $t_alice_owned->id, "Found the ticket owned by alice");

# Test Creator = '__CurrentUser__'
$tix = RT::Tickets->new($current_alice);
$tix->FromSQL("Queue = '$queue' AND Creator = '__CurrentUser__'");
is($tix->Count, 1, "Creator = '__CurrentUser__' finds tickets created by current user (alice)")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;
is($tix->First->id, $t_alice_created->id, "Found the ticket created by alice");

# Test LastUpdatedBy = '__CurrentUser__'
$tix = RT::Tickets->new($current_alice);
$tix->FromSQL("Queue = '$queue' AND LastUpdatedBy = '__CurrentUser__'");
is($tix->Count, 2, "LastUpdatedBy = '__CurrentUser__' finds tickets last updated by alice")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;


# Test TimeWorked, TimeEstimated, TimeLeft fields
my $t_time1 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_time1->Create(
    Queue         => $q->id,
    Subject       => 'Ticket with 2 hours worked',
    TimeWorked    => 120,    # 2 hours
    TimeEstimated => 180,    # 3 hours
    TimeLeft      => 60,     # 1 hour
);
ok( $id, "Created ticket with TimeWorked=120, TimeEstimated=180, TimeLeft=60" );

my $t_time2 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_time2->Create(
    Queue         => $q->id,
    Subject       => 'Ticket with 1 hour worked',
    TimeWorked    => 60,     # 1 hour
    TimeEstimated => 60,     # 1 hour
    TimeLeft      => 0,      # no time left
);
ok( $id, "Created ticket with TimeWorked=60, TimeEstimated=60, TimeLeft=0" );

my $t_time3 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_time3->Create(
    Queue         => $q->id,
    Subject       => 'Ticket with no time worked',
    TimeWorked    => 0,
    # TimeEstimated not set (NULL)
    TimeLeft      => 240,    # 4 hours
);
ok( $id, "Created ticket with TimeWorked=0, no TimeEstimated, TimeLeft=240" );

my $t_time4 = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_time4->Create(
    Queue         => $q->id,
    Subject       => 'Ticket over estimate',
    TimeWorked    => 240,    # 4 hours
    TimeEstimated => 120,    # 2 hours
    TimeLeft      => 0,      # over estimate
);
ok( $id, "Created ticket with TimeWorked=240, TimeEstimated=120, TimeLeft=0" );

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeWorked > 120");
is($tix->Count, 1, "TimeWorked > 120 finds tickets with more than 2 hours worked")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;
is($tix->First->id, $t_time4->id, "Found ticket with 240 minutes worked");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeWorked = 0");
# Most tickets have TimeWorked = 0 by default (original 7 + 3 alice tickets + t_time3)
ok($tix->Count >= 1, "TimeWorked = 0 finds tickets with no time worked")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeWorked >= 60 AND TimeWorked <= 120");
is($tix->Count, 2, "TimeWorked >= 60 AND TimeWorked <= 120 finds tickets with 1-2 hours")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeEstimated = 60");
is($tix->Count, 1, "TimeEstimated = 60 finds tickets with specific estimate")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;
is($tix->First->id, $t_time2->id, "Found ticket with 60 minutes estimated");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeEstimated >= 120");
is($tix->Count, 2, "TimeEstimated >= 120 finds tickets with estimates of 2+ hours")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeLeft > 0");
is($tix->Count, 2, "TimeLeft > 0 finds tickets with time remaining")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND TimeLeft = 0");
# Most tickets have TimeLeft = 0 by default (original 7 + 3 alice tickets + t_time2 + t_time4)
ok($tix->Count >= 2, "TimeLeft = 0 finds tickets with no time left")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;


# Test relative date keywords
my $date_today = RT::Date->new(RT->SystemUser);
$date_today->SetToNow;

my $date_yesterday = RT::Date->new(RT->SystemUser);
$date_yesterday->SetToNow;
$date_yesterday->AddDays(-1);

my $date_tomorrow = RT::Date->new(RT->SystemUser);
$date_tomorrow->SetToNow;
$date_tomorrow->AddDays(1);

my $date_week_ago = RT::Date->new(RT->SystemUser);
$date_week_ago->SetToNow;
$date_week_ago->AddDays(-7);

# Create ticket with Created date yesterday
my $t_date_yesterday = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_date_yesterday->Create(
    Queue   => $q->id,
    Subject => 'Ticket created yesterday',
);
ok( $id, "Created ticket for date testing" );
$t_date_yesterday->__Set( Field => 'Created', Value => $date_yesterday->ISO );

# Create ticket with Due date tomorrow
my $t_due_tomorrow = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_due_tomorrow->Create(
    Queue   => $q->id,
    Subject => 'Ticket due tomorrow',
    Due     => $date_tomorrow->ISO,
);
ok( $id, "Created ticket with Due date tomorrow" );

# Create ticket with Created date 1 week ago
my $t_week_ago = RT::Ticket->new(RT->SystemUser);
( $id, undef, $msg ) = $t_week_ago->Create(
    Queue   => $q->id,
    Subject => 'Ticket from last week',
);
ok( $id, "Created ticket from last week" );
$t_week_ago->__Set( Field => 'Created', Value => $date_week_ago->ISO );

# Test Created > 'yesterday' (should find tickets created today and in future)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Created > 'yesterday'");
ok($tix->Count >= 1, "Created > 'yesterday' finds recently created tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test Created < 'today' (should find tickets created before today)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Created < 'today'");
ok($tix->Count >= 2, "Created < 'today' finds tickets created in the past")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test Created > '1 week ago' (should find tickets from last week onwards)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Created > '1 week ago'");
ok($tix->Count >= 1, "Created > '1 week ago' finds tickets from last week onwards")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test Created > '7 days ago' (alternative syntax for 1 week ago)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Created > '7 days ago'");
ok($tix->Count >= 1, "Created > '7 days ago' finds recent tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test Due < 'tomorrow' (should find tickets due today or earlier)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Due > '0' AND Due < 'tomorrow'");
ok($tix->Count >= 0, "Due < 'tomorrow' finds tickets due before tomorrow")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

# Test Due = 'tomorrow' (should find ticket with Due date tomorrow)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Due = 'tomorrow'");
is($tix->Count, 1, "Due = 'tomorrow' finds ticket due tomorrow")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;
is($tix->First->id, $t_due_tomorrow->id, "Found the correct ticket due tomorrow");

# Test Resolved IS NULL (unresolved tickets)
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND Resolved IS NULL");
ok($tix->Count >= 1, "Resolved IS NULL finds unresolved tickets")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;


# various combinations

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar1'");
is($tix->Count, 1, "LIKE cf and LIKE cf");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' AND CF.SearchTest2 = 'bar1'");
is($tix->Count, 1, "is cf and is cf");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo' AND CF.SearchTest2 LIKE 'bar1'");
is($tix->Count, 0, "is cf and like cf");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar' AND CF.SearchTest3 LIKE 'qux'");
is($tix->Count, 3, "like cf and like cf and like cf");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar' AND CF.SearchTest3 LIKE 'qux6'");
is($tix->Count, 1, "like cf and like cf and is cf");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest LIKE 'foo' AND Subject LIKE 'SearchTest'");
is($tix->Count, 4, "like cf and like subject");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest IS NULL AND CF.SearchTest2 = 'bar2'");
is($tix->Count, 1, "null cf and is cf");


$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest IS NULL AND CF.SearchTest2 IS NULL");
is($tix->Count, 11, "null cf and null cf"); # t7 + 3 alice + 4 time + 3 date tickets 

# tests with the same CF listed twice

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.{SearchTest} = 'foo1'");
is($tix->Count, 1, "is cf.{name} format");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3'");
is($tix->Count, 2, "is cf1 or is cf1");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest IS NULL");
is($tix->Count, 13, "is cf1 or null cf1"); # t1 (has foo1) + t2, t5, t7 + 3 alice + 4 time + 3 date tickets (all NULL)

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("(CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3') AND (CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2')");
is($tix->Count, 1, "(is cf1 or is cf1) and (is cf2 or is cf2)");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("(Queue LIKE '$queue') AND (CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3') AND (CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2')");
is($tix->Count, 1, "(queue LIKE) and (is cf1 or is cf1) and (is cf2 or is cf2)");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3' OR CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2'");
is($tix->Count, 3, "is cf1 or is cf1 or is cf2 or is cf2");

# tests with disabled CF
$cf->SetDisabled(1);
ok($cf->Disabled, 'cf1 is disabled');

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1'");
is($tix->Count, 0, "disabled cf1 with name");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF." . $cf->id . " = 'foo1'");
is($tix->Count, 0, "disabled cf1 with id");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest != 'foo1'");
is($tix->Count, 17, "disabled cf1 with name and negative operator"); # All 17 tickets in queue

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF." . $cf->id . " != 'foo1'");
is($tix->Count, 17, "disabled cf1 with id and negative operator"); # All 17 tickets in queue

$cf->SetDisabled(0);
ok(!$cf->Disabled, 'cf1 is enabled');

# tests with lower cased NULL
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Requestor.Name IS null');
is($tix->Count, 11, "t6, alice tickets, time tickets, and date tickets don't have a Requestor"); # t6 + 3 alice + 4 time + 3 date tickets
like($tix->BuildSelectCountQuery, qr/\bNULL\b/, "Contains upper-case NULL");
unlike($tix->BuildSelectCountQuery, qr/\bnull\b/, "Lacks lower-case NULL");


# tests for searching by queue lifecycle
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle="default"');
is($tix->Count,17,"We found all 17 tickets in a queue with the default lifecycle"); # 7 original + 3 alice + 4 time + 3 date tickets

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle ="approvals" OR Lifecycle="default"');
is($tix->Count,17,"We found 17 tickets in a queue with a lifecycle of default or approvals"); # 7 original + 3 alice + 4 time + 3 date tickets

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle ="approvals" AND Lifecycle="default"');
is($tix->Count,0,"We found 0 tickets in a queue with a lifecycle of default AND approvals...(because that's impossible");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Queue="'.$queue.'" AND Lifecycle="default"');
is($tix->Count,17,"We found 17 tickets in $queue with a lifecycle of default"); # 7 original + 3 alice + 4 time + 3 date tickets


$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle !="approvals"');
is($tix->Count,17,"We found 17 tickets in a queue with a lifecycle other than approvals"); # 7 original + 3 alice + 4 time + 3 date tickets

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle!="default"');
is($tix->Count,0,"We found 0 tickets in a queue with a lifecycle other than default");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle="approvals"');
is($tix->Count,0,"We found 0 tickets in a queue with the approvals lifecycle");

# tests for Created date
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Created = "2018-10-05"');
is($tix->Count, 0, "We found 0 tickets created in 2018-10-05");

ok($t1->__Set(Field => 'Created', Value => '2018-10-05 06:10:00'), 'Updated t1 Created to 2018-10-05 06:10:00');

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Created = "2018-10-05"');
is($tix->Count, 1, "We found 1 ticket created in 2018-10-05 with system user");

my $user = RT::CurrentUser->new(RT->SystemUser);
ok($user->Load('root'),                          'Loaded root');
ok($user->UserObj->SetTimezone('Asia/Shanghai'), 'Updated root timezone to +08:00');

$tix = RT::Tickets->new($user);
$tix->FromSQL('Created = "2018-10-05"');
is($tix->Count, 1, "We found 1 ticket created in 2018-10-05 with user in +08:00 timezone");
is($tix->First->Id, $t1->Id, 'We found the expected ticket');

$tix = RT::Tickets->new($user);
$tix->FromSQL('Created >= "2018-10-05" and Created < "2018-10-06"');
is($tix->Count, 1, "We found 1 ticket created on 2018-10-05 with user in +08:00 timezone using >= and <");
is($tix->First->Id, $t1->Id, 'We found the expected ticket');

# It's 2018-10-05 00:00 in timezone +08:00
ok($t1->__Set(Field => 'Created', Value => '2018-10-04 16:00:00'), 'Updated t1 Created to 2018-10-04 16:00:00');

$tix = RT::Tickets->new($user);
$tix->FromSQL('Created = "2018-10-05"');
is($tix->Count, 1, "We found 1 ticket created in 2018-10-05 with user in +08:00 timezone");
is($tix->First->Id, $t1->Id, 'Found expected ticket ' . $t1->Id);

$tix = RT::Tickets->new($user);
$tix->FromSQL('Created >= "2018-10-05" and Created < "2018-10-06"');
is($tix->Count, 1, "We found 1 ticket created on 2018-10-05 with user in +08:00 timezone using >= and <");
is($tix->First->Id, $t1->Id, 'Found expected ticket ' . $t1->Id);

$tix = RT::Tickets->new($user);
$tix->FromSQL('Created > "2018-10-05" and Created < "2018-10-06"');
is($tix->Count, 0, "We found 0 tickets created on 2018-10-05 but not at 00:00:00 with user in +08:00 timezone");

done_testing;
