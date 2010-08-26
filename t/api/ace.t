
use strict;
use warnings;
use RT;
use RT::Test tests => 76;


{

ok(require RT::ACE);


}

{

my $Queue = RT::Queue->new($RT::SystemUser);

is ($Queue->AvailableRights->{'DeleteTicket'} , 'Delete tickets', "Found the delete ticket right");
is ($RT::System->AvailableRights->{'SuperUser'},  'Do anything and everything', "Found the superuser right");



}

{

use_ok('RT::User'); 
my $user_a = RT::User->new($RT::SystemUser);
$user_a->Create( Name => 'DelegationA', Privileged => 1);
ok ($user_a->Id, "Created delegation user a");

my $user_b = RT::User->new($RT::SystemUser);
$user_b->Create( Name => 'DelegationB', Privileged => 1);
ok ($user_b->Id, "Created delegation user b");


use_ok('RT::Queue');
my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name =>'DelegationTest');
ok ($q->Id, "Created a delegation test queue");


#------ First, we test whether a user can delegate a right that's been granted to him personally 
my ($val, $msg) = $user_a->PrincipalObj->GrantRight(Object => $RT::System, Right => 'AdminOwnPersonalGroups');
ok($val, $msg);

($val, $msg) = $user_a->PrincipalObj->GrantRight(Object =>$q, Right => 'OwnTicket');
ok($val, $msg);

ok($user_a->HasRight( Object => $RT::System, Right => 'AdminOwnPersonalGroups')    ,"user a has the right 'AdminOwnPersonalGroups' directly");

my $a_delegates = RT::Group->new($user_a);
$a_delegates->CreatePersonalGroup(Name => 'Delegates');
ok( $a_delegates->Id   ,"user a creates a personal group 'Delegates'");
ok( $a_delegates->AddMember($user_b->PrincipalId)   ,"user a adds user b to personal group 'delegates'");

ok( !$user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b does not have the right to OwnTicket' in queue 'DelegationTest'");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a has the right to 'OwnTicket' in queue 'DelegationTest'");
ok(!$user_a->HasRight( Object => $RT::System, Right => 'DelegateRights')    ,"user a does not have the right 'delegate rights'");


my $own_ticket_ace = RT::ACE->new($user_a);
my $user_a_equiv_group = RT::Group->new($user_a);
$user_a_equiv_group->LoadACLEquivalenceGroup($user_a->PrincipalObj);
ok ($user_a_equiv_group->Id, "Loaded the user A acl equivalence group");
my $user_b_equiv_group = RT::Group->new($user_b);
$user_b_equiv_group->LoadACLEquivalenceGroup($user_b->PrincipalObj);
ok ($user_b_equiv_group->Id, "Loaded the user B acl equivalence group");
$own_ticket_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $user_a_equiv_group->PrincipalId, Object=>$q, RightName => 'OwnTicket');

ok ($own_ticket_ace->Id, "Found the ACE we want to test with for now");


($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok( !$val ,"user a tries and fails to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");


($val, $msg) = $user_a->PrincipalObj->GrantRight( Right => 'DelegateRights');
ok($val, "user a is granted the right to 'delegate rights' - $msg");

ok($user_a->HasRight( Object => $RT::System, Right => 'DelegateRights') ,"user a has the right 'DeletgateRights'");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId) ;

ok( $val    ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");
my $delegated_ace = RT::ACE->new($user_a);
$delegated_ace->LoadByValues ( Object => $q, RightName => 'OwnTicket', PrincipalType => 'Group',
PrincipalId => $a_delegates->PrincipalId, DelegatedBy => $user_a->PrincipalId, DelegatedFrom => $own_ticket_ace->Id);
ok ($delegated_ace->Id, "Found the delegated ACE");

ok(    $a_delegates->DeleteMember($user_b->PrincipalId)  ,"user a removes b from pg 'delegates'");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");
ok(  $a_delegates->AddMember($user_b->PrincipalId)    ,"user a adds user b to personal group 'delegates'");
ok(   $user_b->HasRight(Right => 'OwnTicket', Object=> $q) ,"user b has the right to own tickets in queue 'DelegationTest'");
ok(   $delegated_ace->Delete ,"user a revokes pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest'");
ok( ! $user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $own_ticket_ace->Delegate(PrincipalId => $a_delegates->PrincipalId)  ;
ok(  $val  ,"user a delegates pg 'delegates' right to 'OwnTickets' in queue 'DelegationTest' - $msg");

ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest". $msg);

ok( !$user_a->HasRight(Right => 'OwnTicket', Object => $q)    ,"user a does not have the right to own tickets in queue 'DelegationTest'");

 ok( !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $user_a->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, $msg);

 ok( $user_a->HasRight(Right => 'OwnTicket', Object => $q)   ,"user a has the right to own tickets in queue 'DelegationTest'");

 ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest'");

# {{{ get back to a known clean state 
($val, $msg) = $user_a->PrincipalObj->RevokeRight( Object => $q, Right => 'OwnTicket');
ok($val, "Revoked user a's right to own tickets in queue 'DelegationTest -". $msg);
ok( !$user_a->HasRight(Right => 'OwnTicket', Object => $q)    ,"make sure that user a can't own tickets in queue 'DelegationTest'");
# }}}


# {{{ Set up some groups and membership
my $del1 = RT::Group->new($RT::SystemUser);
($val, $msg) = $del1->CreateUserDefinedGroup(Name => 'Del1');
ok( $val   ,"create a group del1 - $msg");

my $del2 = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2->CreateUserDefinedGroup(Name => 'Del2');
ok( $val   ,"create a group del2 - $msg");
($val, $msg) = $del1->AddMember($del2->PrincipalId);
ok( $val,"make del2 a member of del1 - $msg");

my $del2a = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2a->CreateUserDefinedGroup(Name => 'Del2a');
ok( $val   ,"create a group del2a - $msg");
($val, $msg) = $del2->AddMember($del2a->PrincipalId);  
ok($val    ,"make del2a a member of del2 - $msg");

my $del2b = RT::Group->new($RT::SystemUser);
($val, $msg) = $del2b->CreateUserDefinedGroup(Name => 'Del2b');
ok( $val   ,"create a group del2b - $msg");
($val, $msg) = $del2->AddMember($del2b->PrincipalId);  
ok($val    ,"make del2b a member of del2 - $msg");

($val, $msg) = $del2->AddMember($user_a->PrincipalId) ;
ok($val,"make 'user a' a member of del2 - $msg");

($val, $msg) = $del2b->AddMember($user_a->PrincipalId) ;
ok($val,"make 'user a' a member of del2b - $msg");

# }}}

# {{{ Grant a right to a group and make sure that a submember can delegate the right and that it does not get yanked
# when a user is removed as a submember, when they're a submember through another path 
($val, $msg) = $del1->PrincipalObj->GrantRight( Object=> $q, Right => 'OwnTicket');
ok( $val   ,"grant del1  the right to 'OwnTicket' in queue 'DelegationTest' - $msg");

ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"make sure that user a can own tickets in queue 'DelegationTest'");

my $group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, Object => $q, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");
ok(  $user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2b->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2b - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a has the right to own tickets in queue 'DelegationTest'");
ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

# }}}

# {{{ When a  user is removed froom a group by the only path they're in there by, make sure the delegations go away
($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");
ok(  !$user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest' ");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)  ,"user b does not have the right to own tickets in queue 'DelegationTest' ");
# }}}

($val, $msg) = $del2->AddMember($user_a->PrincipalId);
ok( $val   ,"make user a a member of group del2 - $msg");

($val, $msg) = $del2->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");

my $del2_right = RT::ACE->new($user_a);
$del2_right->LoadByValues( PrincipalId => $del2->PrincipalId, PrincipalType => 'Group', Object => $q, RightName => 'OwnTicket');
ok ($del2_right->Id, "Found the right");

($val, $msg) = $del2_right->Delegate(PrincipalId => $a_delegates->PrincipalId);
ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' gotten via del2 to personal group 'delegates' - $msg");

# They have it via del1 and del2
ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b has the right to own tickets in queue 'DelegationTest'");


($val, $msg) = $del2->PrincipalObj->RevokeRight(Object=>$q, Right => 'OwnTicket');
ok($val, "revoke the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");
ok(  $user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does has the right to own tickets in queue 'DelegationTest' via del1");
ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->PrincipalObj->GrantRight(Object=>$q, Right => 'OwnTicket');
ok($val, "grant the right 'own tickets' in queue 'DelegationTest' to group del2 - $msg");


$group_ace= RT::ACE->new($user_a);
$group_ace->LoadByValues( PrincipalType => 'Group', PrincipalId => $del1->PrincipalId, Object=>$q, RightName => 'OwnTicket');

ok ($group_ace->Id, "Found the ACE we want to test with for now");

($val, $msg) = $group_ace->Delegate(PrincipalId => $a_delegates->PrincipalId);

ok( $val   ,"user a tries and succeeds to delegate the right 'ownticket' in queue 'DelegationTest' to personal group 'delegates' - $msg");

ok( $user_b->HasRight(Right => 'OwnTicket', Object => $q)    ,"user b has the right to own tickets in queue 'DelegationTest'");

($val, $msg) = $del2->DeleteMember($user_a->PrincipalId);
ok( $val   ,"remove user a from group del2 - $msg");

ok(  !$user_a->HasRight(Right => 'OwnTicket', Object => $q)  ,"user a does not have the right to own tickets in queue 'DelegationTest'");

ok(  !$user_b->HasRight(Right => 'OwnTicket', Object => $q)   ,"user b does not have the right to own tickets in queue 'DelegationTest'");




}

1;
