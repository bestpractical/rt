#!/opt/perl/bin/perl -w

# tests relating to searching. Especially around custom fields with long values
# (> 255 chars)

use strict;
use warnings;

use Test::More tests => 10;
use RT::Test;

# setup the queue

my $q = RT::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.$$;
$q->create(Name => $queue);
ok ($q->id, "Created the queue");


# setup the CF
my $cf = RT::CustomField->new($RT::SystemUser);
$cf->create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $q->id);
ok($cf->id, "Created the SearchTest CF");
my $cflabel = "CustomField-".$cf->id;

# setup some tickets
my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ( $id, undef $msg ) = $t1->create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Requestor  => ['search@example.com'],
    $cflabel   => 'foo',
);
ok( $id, $msg );


my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
( $id, undef, $msg ) = $t2->create(
    Queue      => $q->id,
    Subject    => 'SearchTest2',
    Requestor  => ['searchlong@example.com'],
    $cflabel   => 'bar' x 150,
);
ok( $id, $msg );

my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
( $id, undef, $msg ) = $t3->create(
    Queue      => $q->id,
    Subject    => 'SearchTest3',
    Requestor  => ['searchlong@example.com'],
    $cflabel   => 'bar',
);
ok( $id, $msg );

# we have tickets. start searching
my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'foo'");
is($tix->Count, 1, "matched short string foo")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'bar'");
is($tix->Count, 2, "matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->FromSQL("Queue = '$queue' AND ( CF.SearchTest LIKE 'foo' OR CF.SearchTest LIKE 'bar' )");
is($tix->Count, 3, "matched short string foo or long+short string bar")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest NOT LIKE 'foo' AND CF.SearchTest LIKE 'bar'");
is($tix->Count, 2, "not matched short string foo and matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'foo' AND CF.SearchTest NOT LIKE 'bar'");
is($tix->Count, 1, "matched short string foo and not matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->BuildSelectCountQuery;

