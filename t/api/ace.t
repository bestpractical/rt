
use strict;
use warnings;

use RT::Test; 
use Test::More tests => 76;

ok(require RT::Model::ACE);

{

my $Queue = RT::Model::Queue->new(current_user => RT->system_user);

is ($Queue->AvailableRights->{'DeleteTicket'} , 'Delete tickets', "Found the delete ticket right");
is (RT::System->AvailableRights->{'SuperUser'},  'Do anything and everything', "Found the superuser right");

}

{

use_ok('RT::Model::User'); 
my $user_a = RT::Model::User->new(current_user => RT->system_user);
$user_a->create( name => 'DelegationA', privileged => 1);
ok ($user_a->id, "Created delegation user a");

my $user_b = RT::Model::User->new(current_user => RT->system_user);
$user_b->create( name => 'DelegationB', privileged => 1);
ok ($user_b->id, "Created delegation user b");


use_ok('RT::Model::Queue');
my $q = RT::Model::Queue->new(current_user => RT->system_user);
$q->create(name =>'DelegationTest');
ok ($q->id, "Created a delegation test queue");

#------ First, we test whether a user can delegate a right that's been granted to him personally 
my ($val, $msg) = $user_a->principal_object->GrantRight(Object => RT->system, Right => 'AdminOwnPersonalGroups');
ok($val, $msg);

($val, $msg) = $user_a->principal_object->GrantRight(Object =>$q, Right => 'OwnTicket');
ok($val, $msg);

ok($user_a->has_right( Object => RT->system, Right => 'AdminOwnPersonalGroups')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

my $a_delegates = RT::Model::Group->new( current_user => $user_a);
$a_delegates->createPersonalGroup(name => 'Delegates');
ok( $a_delegates->id   ,"user a creates a personal group 'Delegates'");
ok( $a_delegates->add_member($user_b->principal_id)   ,"user a adds user b to personal group 'delegates'");

ok( !$user_b->has_right(Right => 'OwnTicket', Object => $q)    ,"user b does not have the right to OwnTicket' in queue 'DelegationTest'");
ok(  $user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"user a has the right to 'OwnTicket' in queue 'DelegationTest'");
ok(!$user_a->has_right( Object => RT->system, Right => 'DelegateRights')    ,"user a does not have the right 'delegate rights'");


my $own_ticket_ace = RT::Model::ACE->new(current_user => $user_a);
my $user_a_equiv_group = RT::Model::Group->new(current_user => $user_a);
$user_a_equiv_group->load_acl_equivalence_group($user_a->principal_object);
ok ($user_a_equiv_group->id, "Loaded the user A acl equivalence group");
my $user_b_equiv_group = RT::Model::Group->new(current_user => $user_b);
$user_b_equiv_group->load_acl_equivalence_group($user_b->principal_object);
ok ($user_b_equiv_group->id, "Loaded the user B acl equivalence group");
$own_ticket_ace->load_by_values( principal_type => 'Group', principal_id => $user_a_equiv_group->principal_id, Object=>$q, right_name => 'OwnTicket');

ok ($own_ticket_ace->id, "Found the ACE we want to test with for now");


($val, $msg) = $own_ticket_ace->Delegate(principal_id => $a_delegates->principal_id)  ;
ok( !$val ,"user a tries and fails to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");


($val, $msg) = $user_a->principal_object->GrantRight( Right => 'DelegateRights');
ok($val, "user a is granted the right to 'delegate rights' - $msg");

ok($user_a->has_right( Object => RT->system, Right => 'DelegateRights') ,"user a has the right 'DeletgateRights'");

($val, $msg) = $own_ticket_ace->Delegate(principal_id => $a_delegates->principal_id) ;

ok( $val    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->has_right(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");
my $delegated_ace = RT::Model::ACE->new(current_user => $user_a);
$delegated_ace->load_by_values ( Object => $q, right_name => 'OwnTicket', principal_type => 'Group',
principal_id => $a_delegates->principal_id, DelegatedBy => $user_a->principal_id, DelegatedFrom => $own_ticket_ace->id);
ok ($delegated_ace->id, "Found the delegated ACE");

ok(    $a_delegates->delete_member($user_b->principal_id)  ,"user a removes b from pg 'delegates'");
ok(  !$user_b->has_right(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");
ok(  $a_delegates->add_member($user_b->principal_id)    ,"user a adds user b to personal group 'delegates'");
ok(   $user_b->has_right(Right => 'OwnTicket', Object=> $q) ,"user b has the right to own tickets in queue 'DelegationTest'");
ok(   $delegated_ace->delete ,"user a revokes pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");
ok( ! $user_b->has_right(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $own_ticket_ace->Delegate(principal_id => $a_delegates->principal_id)  ;
ok(  $val  ,"user a delegates pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest' - $msg");

ok( $user_b->has_right(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->principal_object->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest". $msg);

ok( !$user_a->has_right(Right => 'OwnTicket', Object => $q)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

 ok( !$user_b->has_right(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->principal_object->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, $msg);

 ok( $user_a->has_right(Right => 'OwnTicket', Object => $q)   ,"user a has the right to own tickets in queue 'DelegationTest'");

 ok(  !$user_b->has_right(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# {{{ get back to a known clean state 
($val, $msg) = $user_a->principal_object->RevokeRight( Object => $q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest -". $msg);
ok( !$user_a->has_right(Right => 'OwnTicket', Object => $q)    ,"make sure that user a can't own tickets in queue 'DelegationTest'");
# }}}


# {{{ Set up some groups and membership
my $del1 = RT::Model::Group->new(current_user => RT->system_user);
($val, $msg) = $del1->create_userDefinedGroup(name => 'Del1');
ok( $val   ,"create a group del1 - $msg");

my $del2 = RT::Model::Group->new(current_user => RT->system_user);
($val, $msg) = $del2->create_userDefinedGroup(name => 'Del2');
ok( $val   ,"create a group del2 - $msg");
($val, $msg) = $del1->add_member($del2->principal_id);
ok( $val,"make del2 a member of del1 - $msg");

my $del2a = RT::Model::Group->new(current_user => RT->system_user);
($val, $msg) = $del2a->create_userDefinedGroup(name => 'Del2a');
ok( $val   ,"create a group del2a - $msg");
($val, $msg) = $del2->add_member($del2a->principal_id);  
ok($val    ,"make del2a a member of del2 - $msg");

my $del2b = RT::Model::Group->new(current_user => RT->system_user);
($val, $msg) = $del2b->create_userDefinedGroup(name => 'Del2b');
ok( $val   ,"create a group del2b - $msg");
($val, $msg) = $del2->add_member($del2b->principal_id);  
ok($val    ,"make del2b a member of del2 - $msg");

($val, $msg) = $del2->add_member($user_a->principal_id) ;
ok($val,"make 'user a' a member of del2 - $msg");

($val, $msg) = $del2b->add_member($user_a->principal_id) ;
ok($val,"make 'user a' a member of del2b - $msg");

# }}}

# {{{ Grant a right to a group and make sure that a submember can delegate the right and that it does not get yanked
# when a user is removed as a submember, when they're a submember through another path 
($val, $msg) = $del1->principal_object->GrantRight( Object=> $q, Right => 'OwnTicket');
ok( $val   ,"grant del1  the right to 'OwnTicket' in queue 'DelegationTest' - $msg");

ok(  $user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"make sure that user a can own tickets in queue 'DelegationTest'");

my $group_ace= RT::Model::ACE->new(current_user => $user_a);
$group_ace->load_by_values( principal_type => 'Group', principal_id => $del1->principal_id, Object => $q, right_name => 'OwnTicket');

ok ($group_ace->id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(principal_id => $a_delegates->principal_id);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->has_right(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2b->delete_member($user_a->principal_id);
ok( $val   ,"remove user a from group del2b - $msg");
ok(  $user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"user a has the right to own tickets in queue 'DelegationTest'");
ok( $user_b->has_right(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

# }}}

# {{{ When a  user is removed froom a group by the only path they're in there by, make sure the delegations go away
($val, $msg) = $del2->delete_member($user_a->principal_id);
ok( $val   ,"remove user a from group del2 - $msg");
ok(  !$user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest' ");
ok(  !$user_b->has_right(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest' ");
# }}}

($val, $msg) = $del2->add_member($user_a->principal_id);
ok( $val   ,"make user a a member of group del2 - $msg");

($val, $msg) = $del2->principal_object->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");

my $del2_right = RT::Model::ACE->new(current_user => $user_a);
$del2_right->load_by_values( principal_id => $del2->principal_id, principal_type => 'Group', Object => $q, right_name => 'OwnTicket');
ok ($del2_right->id, "Found the right");

($val, $msg) = $del2_right->Delegate(principal_id => $a_delegates->principal_id);
ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' gotten via del2 to personal group 'delegates' - $msg");

# They have it via del1 and del2
ok( $user_b->has_right(Right => 'OwnTicket', Object => $q)   ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2->principal_object->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "revoke the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");
ok(  $user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"user a does has the right to own tickets in queue 'DelegationTest' via del1");
ok(  !$user_b->has_right(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->principal_object->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");


$group_ace= RT::Model::ACE->new(current_user => $user_a);
$group_ace->load_by_values( principal_type => 'Group', principal_id => $del1->principal_id, Object=>$q, right_name => 'OwnTicket');

ok ($group_ace->id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(principal_id => $a_delegates->principal_id);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");

ok( $user_b->has_right(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->delete_member($user_a->principal_id);
ok( $val   ,"remove user a from group del2 - $msg");

ok(  !$user_a->has_right(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");

ok(  !$user_b->has_right(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");




}

1;
