
# tests relating to searching. Especially around custom fields, and
# corner cases.

use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;

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
is($tix->Count, 1, "null cf and null cf"); 

# tests with the same CF listed twice

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.{SearchTest} = 'foo1'");
is($tix->Count, 1, "is cf.{name} format");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3'");
is($tix->Count, 2, "is cf1 or is cf1");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest IS NULL");
is($tix->Count, 3, "is cf1 or null cf1");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("(CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3') AND (CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2')");
is($tix->Count, 1, "(is cf1 or is cf1) and (is cf2 or is cf2)");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("(Queue LIKE '$queue') AND (CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3') AND (CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2')");
is($tix->Count, 1, "(queue LIKE) and (is cf1 or is cf1) and (is cf2 or is cf2)");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3' OR CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2'");
is($tix->Count, 3, "is cf1 or is cf1 or is cf2 or is cf2");

# tests with lower cased NULL
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Requestor.Name IS null');
is($tix->Count, 1, "t6 doesn't have a Requestor");
like($tix->BuildSelectCountQuery, qr/\bNULL\b/, "Contains upper-case NULL");
unlike($tix->BuildSelectCountQuery, qr/\bnull\b/, "Lacks lower-case NULL");


# tests for searching by queue lifecycle
$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle="default"');
is($tix->Count,7,"We found all 7 tickets in a queue with the default lifecycle");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle ="approvals" OR Lifecycle="default"');
is($tix->Count,7,"We found 7 tickets in a queue with a lifecycle of default or approvals");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle ="approvals" AND Lifecycle="default"');
is($tix->Count,0,"We found 0 tickets in a queue with a lifecycle of default AND approvals...(because that's impossible");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Queue="'.$queue.'" AND Lifecycle="default"');
is($tix->Count,7,"We found 7 tickets in $queue with a lifecycle of default");


$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle !="approvals"');
is($tix->Count,7,"We found 7 tickets in a queue with a lifecycle other than approvals");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle!="default"');
is($tix->Count,0,"We found 0 tickets in a queue with a lifecycle other than default");

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL('Lifecycle="approvals"');
is($tix->Count,0,"We found 0 tickets in a queue with the approvals lifecycle");


done_testing;
