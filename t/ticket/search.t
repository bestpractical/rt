#!/opt/perl/bin/perl -w

# tests relating to searching. Especially around custom fields, and
# corner cases.

use strict;
use warnings;

use Test::More tests => 43;
use RT::Test;

# setup the queue

my $q = RT::Model::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.$$;
$q->create(Name => $queue);
ok ($q->id, "Created the queue");


# and setup the CFs
# we believe the Type shouldn't matter.

my $cf = RT::Model::CustomField->new($RT::SystemUser);
$cf->create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf->id, "Created the SearchTest CF");
my $cflabel = "CustomField-".$cf->id;

my $cf2 = RT::Model::CustomField->new($RT::SystemUser);
$cf2->create(Name => 'SearchTest2', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf2->id, "Created the SearchTest2 CF");
my $cflabel2 = "CustomField-".$cf2->id;

my $cf3 = RT::Model::CustomField->new($RT::SystemUser);
$cf3->create(Name => 'SearchTest3', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf3->id, "Created the SearchTest3 CF");
my $cflabel3 = "CustomField-".$cf3->id;


# There was a bug involving a missing join to ObjectCustomFields that
# caused spurious results on negative searches if another custom field
# with the same name existed on a different queue.  Hence, we make
# duplicate CFs on a different queue here
my $dup = RT::Model::Queue->new($RT::SystemUser);
$dup->create(Name => $queue . "-Copy");
ok ($dup->id, "Created the duplicate queue");
my $dupcf = RT::Model::CustomField->new($RT::SystemUser);
$dupcf->create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the duplicate SearchTest CF");
$dupcf = RT::Model::CustomField->new($RT::SystemUser);
$dupcf->create(Name => 'SearchTest2', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the SearchTest2 CF");
$dupcf = RT::Model::CustomField->new($RT::SystemUser);
$dupcf->create(Name => 'SearchTest3', Type => 'Freeform', MaxValues => 0, Queue => $dup->id);
ok($dupcf->id, "Created the SearchTest3 CF");


# setup some tickets
# we'll need a small pile of them, to test various combinations and nulls.
# there's probably a way to think harder and do this with fewer


my $t1 = RT::Model::Ticket->new($RT::SystemUser);
my ( $id, undef $msg ) = $t1->create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Requestor  => ['search1@example.com'],
    $cflabel   => 'foo1',
    $cflabel2  => 'bar1',
    $cflabel3  => 'qux1',
);
ok( $id, $msg );


my $t2 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t2->create(
    Queue      => $q->id,
    Subject    => 'SearchTest2',
    Requestor  => ['search2@example.com'],
#    $cflabel   => 'foo2',
    $cflabel2  => 'bar2',
    $cflabel3  => 'qux2',
);
ok( $id, $msg );

my $t3 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t3->create(
    Queue      => $q->id,
    Subject    => 'SearchTest3',
    Requestor  => ['search3@example.com'],
    $cflabel   => 'foo3',
#    $cflabel2  => 'bar3',
    $cflabel3  => 'qux3',
);
ok( $id, $msg );

my $t4 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t4->create(
    Queue      => $q->id,
    Subject    => 'SearchTest4',
    Requestor  => ['search4@example.com'],
    $cflabel   => 'foo4',
    $cflabel2  => 'bar4',
#    $cflabel3  => 'qux4',
);
ok( $id, $msg );

my $t5 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t5->create(
    Queue      => $q->id,
#    Subject    => 'SearchTest5',
    Requestor  => ['search5@example.com'],
    $cflabel   => 'foo5',
    $cflabel2  => 'bar5',
    $cflabel3  => 'qux5',
);
ok( $id, $msg );

my $t6 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t6->create(
    Queue      => $q->id,
    Subject    => 'SearchTest6',
#    Requestor  => ['search6@example.com'],
    $cflabel   => 'foo6',
    $cflabel2  => 'bar6',
    $cflabel3  => 'qux6',
);
ok( $id, $msg );

my $t7 = RT::Model::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t7->create(
    Queue      => $q->id,
    Subject    => 'SearchTest7',
    Requestor  => ['search7@example.com'],
#    $cflabel   => 'foo7',
#    $cflabel2  => 'bar7',
    $cflabel3  => 'qux7',
);
ok( $id, $msg );

# we have tickets. start searching
my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue'");
is($tix->count, 7, "found all the tickets");


# very simple searches. both CF and normal

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest = 'foo1'");
is($tix->count, 1, "matched identical subject");


$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest LIKE 'foo1'");
is($tix->count, 1, "matched LIKE subject");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest = 'foo'");
is($tix->count, 0, "IS a regexp match");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest LIKE 'foo'");
is($tix->count, 5, "matched LIKE subject");


$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest IS NULL");
is($tix->count, 2, "IS null CF");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Requestors LIKE 'search1'");
is($tix->count, 1, "LIKE requestor");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Requestors = 'search1\@example.com'");
is($tix->count, 1, "IS requestor");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Requestors LIKE 'search'");
is($tix->count, 6, "LIKE requestor");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Requestors IS NULL");
is($tix->count, 1, "Search for no requestor");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Subject = 'SearchTest1'");
is($tix->count, 1, "IS subject");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Subject LIKE 'SearchTest1'");
is($tix->count, 1, "LIKE subject");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Subject = ''");
is($tix->count, 1, "found one ticket");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Subject LIKE 'SearchTest'");
is($tix->count, 6, "found two ticket");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND Subject LIKE 'qwerty'");
is($tix->count, 0, "found zero ticket");




# various combinations

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar1'");
is($tix->count, 1, "LIKE cf and LIKE cf");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest = 'foo1' AND CF.SearchTest2 = 'bar1'");
is($tix->count, 1, "is cf and is cf");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest = 'foo' AND CF.SearchTest2 LIKE 'bar1'");
is($tix->count, 0, "is cf and like cf");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar' AND CF.SearchTest3 LIKE 'qux'");
is($tix->count, 3, "like cf and like cf and like cf");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest LIKE 'foo' AND CF.SearchTest2 LIKE 'bar' AND CF.SearchTest3 LIKE 'qux6'");
is($tix->count, 1, "like cf and like cf and is cf");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest LIKE 'foo' AND Subject LIKE 'SearchTest'");
is($tix->count, 4, "like cf and like subject");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest IS NULL AND CF.SearchTest2 = 'bar2'");
is($tix->count, 1, "null cf and is cf");


$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest IS NULL AND CF.SearchTest2 IS NULL");
is($tix->count, 1, "null cf and null cf"); 

# tests with the same CF listed twice

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.{SearchTest} = 'foo1'");
is($tix->count, 1, "is cf.{name} format");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3'");
is($tix->count, 2, "is cf1 or is cf1");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest = 'foo1' OR CF.SearchTest IS NULL");
is($tix->count, 3, "is cf1 or null cf1");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("(CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3') AND (CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2')");
is($tix->count, 1, "(is cf1 or is cf1) and (is cf2 or is cf2)");

$tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql("CF.SearchTest = 'foo1' OR CF.SearchTest = 'foo3' OR CF.SearchTest2 = 'bar1' OR CF.SearchTest2 = 'bar2'");
is($tix->count, 3, "is cf1 or is cf1 or is cf2 or is cf2");

