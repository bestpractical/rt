#!/usr/bin/perl

use strict;
use warnings;

use RT::Test; use Test::More  tests => '17';

use RT;



# validate that when merging two tickets, the comments from both tickets
# are integrated into the new ticket
{
    my $queue = RT::Model::Queue->new(RT->SystemUser);
    my ($id,$msg) = $queue->create(Name => 'MergeTest-'.rand(25));
    ok ($id,$msg);

    my $t1 = RT::Model::Ticket->new(RT->SystemUser);
    my ($tid,$transid, $t1msg) =$t1->create ( Queue => $queue->Name, Subject => 'Merge test. orig');
    ok ($tid, $t1msg);
    ($id, $msg) = $t1->Comment(Content => 'This is a Comment on the original');
    ok($id,$msg);

    my $txns = $t1->Transactions;
    my $Comments = 0;
    while (my $txn = $txns->next) {
    $Comments++ if ($txn->Type eq 'Comment');
    }
    is($Comments,1, "our first ticket has only one Comment");

    my $t2 = RT::Model::Ticket->new(RT->SystemUser);
    my ($t2id,$t2transid, $t2msg) =$t2->create ( Queue => $queue->Name, Subject => 'Merge test. duplicate');
    ok ($t2id, $t2msg);



    ($id, $msg) = $t2->Comment(Content => 'This is a commet on the duplicate');
    ok($id,$msg);


    $txns = $t2->Transactions;
     $Comments = 0;
    while (my $txn = $txns->next) {
        $Comments++ if ($txn->Type eq 'Comment');
    }
    is($Comments,1, "our second ticket has only one Comment");

    ($id, $msg) = $t1->Comment(Content => 'This is a second  Comment on the original');
    ok($id,$msg);

    $txns = $t1->Transactions;
    $Comments = 0;
    while (my $txn = $txns->next) {
        $Comments++ if ($txn->Type eq 'Comment');
    }
    is($Comments,2, "our first ticket now has two Comments");

    ($id,$msg) = $t2->MergeInto($t1->id);
    ok($id,$msg);
    $txns = $t1->Transactions;
    $Comments = 0;
    while (my $txn = $txns->next) {
        $Comments++ if ($txn->Type eq 'Comment');
    }
    is($Comments,3, "our first ticket now has three Comments - we merged safely");
}

# when you try to merge duplicate links on postgres, eveyrything goes to hell due to referential integrity constraints.
{
    my $t = RT::Model::Ticket->new(RT->SystemUser);
    $t->create(Subject => 'Main', Queue => 'general');

    ok ($t->id);
    my $t2 = RT::Model::Ticket->new(RT->SystemUser);
    $t2->create(Subject => 'Second', Queue => 'general');
    ok ($t2->id);

    my $t3 = RT::Model::Ticket->new(RT->SystemUser);
    $t3->create(Subject => 'Third', Queue => 'general');

    ok ($t3->id);

    my ($id,$val);
    ($id,$val) = $t->AddLink(Type => 'DependsOn', Target => $t3->id);
    ok($id,$val);
    ($id,$val) = $t2->AddLink(Type => 'DependsOn', Target => $t3->id);
    ok($id,$val);

    ($id,$val) = $t->MergeInto($t2->id);
    ok($id,$val);
}
