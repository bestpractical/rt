#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More qw/no_plan/;
use_ok('RT');
RT::LoadConfig();
RT::Init();

my $q = RT::Queue->new($RT::SystemUser);
my $queue = 'SearchTests-'.rand(200);
$q->Create(Name => $queue);
ok ($q->id, "Created the queue");

my $cf = RT::CustomField->new($RT::SystemUser);
$cf->Create(Name => 'SearchTest', Type => 'Freeform', MaxValues => 0, Queue => $q->id);

ok($cf->id, "Created the custom field");

my $cflabel = "CustomField-".$cf->id;

my $t1 = RT::Ticket->new($RT::SystemUser);
my ( $id, undef $msg ) = $t1->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest1',
    Requestor => ['search2@example.com'],
    $cflabel   => 'one'
);
ok( $id, $msg );

my $t2 = RT::Ticket->new($RT::SystemUser);
( $id, undef, $msg ) = $t2->Create(
    Queue      => $q->id,
    Subject    => 'SearchTest2',
    Requestor => ['search1@example.com'],
    $cflabel   => 'two'
);
ok( $id, $msg );

my $tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue'");

is($tix->Count, 2, "found two tickets");

$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest = 'one'");
is($tix->Count, 1, "found one ticket");


$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest = 'two'");
is($tix->Count, 1, "found one ticket");

$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND CF.SearchTest LIKE 'o'");
is($tix->Count, 2, "found two tickets");




$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors LIKE 'search1'");
is($tix->Count, 1, "found one ticket");


$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors LIKE 'search2'");
is($tix->Count, 1, "found one ticket");

$tix = RT::Tickets->new($RT::SystemUser);
$tix->FromSQL("Queue = '$queue' AND Requestors LIKE 'search'");
is($tix->Count, 2, "found two tickets");
