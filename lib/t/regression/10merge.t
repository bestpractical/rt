#!/usr/bin/perl 

use warnings;
use strict;


#
# This test script validates that when merging two tickets, the comments from both tickets
# are integrated into the new ticket

use Test::More tests => 13;
use RT;
RT::LoadConfig;
RT::Init;

use_ok('RT::Ticket');
use_ok('RT::Queue');

my $queue = RT::Queue->new($RT::SystemUser);
my ($id,$msg) = $queue->Create(Name => 'MergeTest-'.rand(25));
ok ($id,$msg);

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($tid,$transid, $t1msg) =$t1->Create ( Queue => $queue->Name, Subject => 'Merge test. orig');
ok ($tid, $t1msg);
($id, $msg) = $t1->Comment(Content => 'This is a Comment on the original');
ok($id,$msg);

my $txns = $t1->Transactions;
my $Comments = 0;
while (my $txn = $txns->Next) {
$Comments++ if ($txn->Type eq 'Comment');
}
is($Comments,1, "our first ticket has only one Comment");

my $t2 = RT::Ticket->new($RT::SystemUser);
my ($t2id,$t2transid, $t2msg) =$t2->Create ( Queue => $queue->Name, Subject => 'Merge test. duplicate');
ok ($t2id, $t2msg);



($id, $msg) = $t2->Comment(Content => 'This is a commet on the duplicate');
ok($id,$msg);


$txns = $t2->Transactions;
 $Comments = 0;
while (my $txn = $txns->Next) {
    $Comments++ if ($txn->Type eq 'Comment');
}
is($Comments,1, "our second ticket has only one Comment");

($id, $msg) = $t1->Comment(Content => 'This is a second  Comment on the original');
ok($id,$msg);

$txns = $t1->Transactions;
$Comments = 0;
while (my $txn = $txns->Next) {
    $Comments++ if ($txn->Type eq 'Comment');
}
is($Comments,2, "our first ticket now has two Comments");

($id,$msg) = $t2->MergeInto($t1->id);

ok($id,$msg);
$txns = $t1->Transactions;
$Comments = 0;
while (my $txn = $txns->Next) {
    $Comments++ if ($txn->Type eq 'Comment');
}
is($Comments,3, "our first ticket now has three Comments - we merged safely");

