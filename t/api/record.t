
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 22;
use RT;



{

ok (require RT::Record);


}

{

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my $group = RT::Model::Group->new(current_user => RT->system_user);
is($ticket->object_type_str, 'Ticket', "Ticket returns correct typestring");
is($group->object_type_str, 'Group', "Group returns correct typestring");


}

{

my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id, $trans, $msg) = $t1->create(subject => 'DepTest1', Queue => 'general');
ok($id, "Created dep test 1 - $msg");

my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
(my $id2, $trans, my $msg2) = $t2->create(subject => 'DepTest2', Queue => 'general');
ok($id2, "Created dep test 2 - $msg2");
my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
(my $id3, $trans, my $msg3) = $t3->create(subject => 'DepTest3', Queue => 'general', type => 'approval');
ok($id3, "Created dep test 3 - $msg3");
my ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->add_link( type => 'DependsOn', Target => $t2->id));
ok ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->add_link( type => 'DependsOn', Target => $t3->id));

ok ($addid, $addmsg);
my $link = RT::Model::Link->new(current_user => RT->system_user);
(my $rv, $msg) = $link->load($addid);
ok ($rv, $msg);
is ($link->LocalTarget , $t3->id, "Link LocalTarget is correct");
is ($link->LocalBase   , $t1->id, "Link LocalBase   is correct");
ok ($t1->has_unresolved_dependencies, "Ticket ".$t1->id." has unresolved deps");
ok (!$t1->has_unresolved_dependencies( type => 'blah' ), "Ticket ".$t1->id." has no unresolved blahs");
ok ($t1->has_unresolved_dependencies( type => 'approval' ), "Ticket ".$t1->id." has unresolved approvals");
ok (!$t2->has_unresolved_dependencies, "Ticket ".$t2->id." has no unresolved deps");
;

my ($rid, $rmsg)= $t1->resolve();
ok(!$rid, $rmsg);
my ($rid2, $rmsg2) = $t2->resolve();
ok ($rid2, $rmsg2);
($rid, $rmsg)= $t1->resolve();
ok(!$rid, $rmsg);
my ($rid3,$rmsg3) = $t3->resolve;
ok ($rid3,$rmsg3);
($rid, $rmsg)= $t1->resolve();
ok($rid, $rmsg);



}

1;
