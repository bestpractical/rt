#!/opt/perl/bin/perl -w

# tests relating to searching. Especially around custom fields with long values
# (> 255 chars)

use strict;
use warnings;
use RT::Test;

use Test::More tests => 10;

# setup the queue

my $q = RT::Model::Queue->new(current_user => RT->system_user);
my $queue = 'SearchTests-'.$$;
$q->create(name => $queue);
ok ($q->id, "Created the queue");


# setup the CF
my $cf = RT::Model::CustomField->new( current_user => RT->system_user );
$cf->create(name => 'SearchTest', type => 'Freeform', max_values => 0, queue => $q->id);
ok($cf->id, "Created the SearchTest CF");
my $cflabel = "custom_field-".$cf->id;

# setup some tickets
my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ( $id, undef $msg ) = $t1->create(
    queue      => $q->id,
    subject    => 'SearchTest1',
    requestor  => ['search@example.com'],
    $cflabel   => 'foo',
);
ok( $id, $msg );


my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
( $id, undef, $msg ) = $t2->create(
    queue      => $q->id,
    subject    => 'SearchTest2',
    requestor  => ['searchlong@example.com'],
    $cflabel   => 'bar' x 150,
);
ok( $id, $msg );

my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
( $id, undef, $msg ) = $t3->create(
    queue      => $q->id,
    subject    => 'SearchTest3',
    requestor  => ['searchlong@example.com'],
    $cflabel   => 'bar',
);
ok( $id, $msg );

# we have tickets. start searching
my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest LIKE 'foo'");
is($tix->count, 1, "matched short string foo")
    or diag "wrong results from SQL:\n". $tix->build_select_count_query;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest LIKE 'bar'");
is($tix->count, 2, "matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->build_select_count_query;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql("Queue = '$queue' AND ( CF.SearchTest LIKE 'foo' OR CF.SearchTest LIKE 'bar' )");
is($tix->count, 3, "matched short string foo or long+short string bar")
    or diag "wrong results from SQL:\n". $tix->build_select_count_query;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest NOT LIKE 'foo' AND CF.SearchTest LIKE 'bar'");
is($tix->count, 2, "not matched short string foo and matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->build_select_count_query;

$tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql("Queue = '$queue' AND CF.SearchTest LIKE 'foo' AND CF.SearchTest NOT LIKE 'bar'");
is($tix->count, 1, "matched short string foo and not matched long+short string bar")
    or diag "wrong results from SQL:\n". $tix->build_select_count_query;

