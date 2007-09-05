
use strict;
use warnings;
use Test::More; 
plan tests => 105;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok(require RT::Model::User);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

# Make sure we can create a user

my $u1 = RT::Model::User->new($RT::SystemUser);
is(ref($u1), 'RT::Model::User');
my ($id, $msg) = $u1->create(Name => 'CreateTest1'.$$, EmailAddress => $$.'create-test-1@example.com');
ok ($id, "Creating user CreateTest1 - " . $msg );

# Make sure we can't create a second user with the same name
my $u2 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u2->create(Name => 'CreateTest1'.$$, EmailAddress => $$.'create-test-2@example.com');
ok (!$id, $msg);


# Make sure we can't create a second user with the same EmailAddress address
my $u3 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u3->create(Name => 'CreateTest2'.$$, EmailAddress => $$.'create-test-1@example.com');
ok (!$id, $msg);

# Make sure we can create a user with no EmailAddress address
my $u4 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u4->create(Name => 'CreateTest3'.$$);
ok ($id, $msg);

# make sure we can create a second user with no EmailAddress address
my $u5 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u5->create(Name => 'CreateTest4'.$$);
ok ($id, $msg);

# make sure we can create a user with a blank EmailAddress address
my $u6 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u6->create(Name => 'CreateTest6'.$$, EmailAddress => '');
ok ($id, $msg);
# make sure we can create a second user with a blankEmailAddress address
my $u7 = RT::Model::User->new($RT::SystemUser);
($id, $msg) = $u7->create(Name => 'CreateTest7'.$$, EmailAddress => '');
ok ($id, $msg);

# Can we change the email address away from from "";
($id,$msg) = $u7->set_EmailAddress('foo@bar'.$$);
ok ($id, $msg);
# can we change the address back to "";  
($id,$msg) = $u7->set_EmailAddress('');
ok ($id, $msg);
is ($u7->EmailAddress, '');



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;


ok(my $user = RT::Model::User->new($RT::SystemUser));
ok($user->load('root'), "Loaded user 'root'");
ok($user->Privileged, "User 'root' is privileged");
ok(my ($v,$m) = $user->set_Privileged(0));
is ($v ,1, "Set unprivileged suceeded ($m)");

ok(!$user->Privileged, "User 'root' is no longer privileged");
ok(my ($v2,$m2) = $user->set_Privileged(1));
is ($v2 ,1, "Set privileged suceeded ($m2");
ok($user->Privileged, "User 'root' is privileged again");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok(my $u = RT::Model::User->new($RT::SystemUser));
ok($u->load(1), "Loaded the first user");
is($u->PrincipalObj->ObjectId , 1, "user 1 is the first principal");
is($u->PrincipalObj->PrincipalType, 'User' , "Principal 1 is a user, not a group");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $root = RT::Model::User->new($RT::SystemUser);
$root->load('root');
ok($root->id, "Found the root user");
my $rootq = RT::Model::Queue->new($root);
$rootq->load(1);
ok($rootq->id, "Loaded the first queue");

ok ($rootq->CurrentUser->has_right(Right=> 'CreateTicket', Object => $rootq), "Root can create tickets");

my $new_user = RT::Model::User->new($RT::SystemUser);
my ($id, $msg) = $new_user->create(Name => 'ACLTest'.$$);

ok ($id, "Created a new user for acl test $msg");

my $q = RT::Model::Queue->new($new_user);
$q->load(1);
ok($q->id, "Loaded the first queue");


ok (!$q->CurrentUser->has_right(Right => 'CreateTicket', Object => $q), "Some random user doesn't have the right to create tickets");
ok (my ($gval, $gmsg) = $new_user->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $q), "Granted the random user the right to create tickets");
ok ($gval, "Grant succeeded - $gmsg");


ok ($q->CurrentUser->has_right(Right => 'CreateTicket', Object => $q), "The user can create tickets after we grant him the right");
ok ( ($gval, $gmsg) = $new_user->PrincipalObj->RevokeRight( Right => 'CreateTicket', Object => $q), "revoked the random user the right to create tickets");
ok ($gval, "Revocation succeeded - $gmsg");
ok (!$q->CurrentUser->has_right(Right => 'CreateTicket', Object => $q), "The user can't create tickets anymore");





# Create a ticket in the queue
my $new_tick = RT::Model::Ticket->new($RT::SystemUser);
my ($tickid, $tickmsg) = $new_tick->create(Subject=> 'ACL Test', Queue => 'General');
ok($tickid, "Created ticket: $tickid");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");
# Create a new group
my $group = RT::Model::Group->new($RT::SystemUser);
$group->create_userDefinedGroup(Name => 'ACLTest'.$$);
ok($group->id, "Created a new group Ok");
# Grant a group the right to modify tickets in a queue
ok(my ($gv,$gm) = $group->PrincipalObj->GrantRight( Object => $q, Right => 'ModifyTicket'),"Granted the group the right to modify tickets");
ok($gv,"Grant succeeed - $gm");
# Add the user to the group
ok( my ($aid, $amsg) = $group->AddMember($new_user->PrincipalId), "Added the member to the group");
ok ($aid, "Member added to group: $amsg");
# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick, Right => 'ModifyTicket'), "User can modify the ticket with group membership");


# Remove the user from the group
ok( my ($did, $dmsg) = $group->delete_member($new_user->PrincipalId), "Deleted the member from the group");
ok ($did,"Deleted the group member: $dmsg");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");


my $q_as_system = RT::Model::Queue->new($RT::SystemUser);
$q_as_system->load(1);
ok($q_as_system->id, "Loaded the first queue");

# Create a ticket in the queue
my $new_tick2 = RT::Model::Ticket->new($RT::SystemUser);
(my $tick2id, $tickmsg) = $new_tick2->create(Subject=> 'ACL Test 2', Queue =>$q_as_system->id);
ok($tick2id, "Created ticket: $tick2id");
is($new_tick2->QueueObj->id, $q_as_system->id, "Created a new ticket in queue 1");


# make sure that the user can't do this without subgroup membership
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

# Create a subgroup
my $subgroup = RT::Model::Group->new($RT::SystemUser);
$subgroup->create_userDefinedGroup(Name => 'Subgrouptest'.$$);
ok($subgroup->id, "Created a new group ".$subgroup->id."Ok");
#Add the subgroup as a subgroup of the group
my ($said, $samsg) =  $group->AddMember($subgroup->PrincipalId);
ok ($said, "Added the subgroup as a member of the group");
# Add the user to a subgroup of the group

my ($usaid, $usamsg) =  $subgroup->AddMember($new_user->PrincipalId);
ok($usaid,"Added the user ".$new_user->id."to the subgroup");
# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket with subgroup membership");

#  {{{ Deal with making sure that members of subgroups of a disabled group don't have rights

($id, $msg) =  $group->set_Disabled(1);
ok ($id,$msg);
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket when the group ".$group->id. " is disabled");
 ($id, $msg) =  $group->set_Disabled(0);
ok($id,$msg);
# Test what happens when we disable the group the user is a member of directly

($id, $msg) =  $subgroup->set_Disabled(1);
 ok ($id,$msg);
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket when the group ".$subgroup->id. " is disabled");
 ($id, $msg) =  $subgroup->set_Disabled(0);
 ok ($id,$msg);
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket without group membership");

# }}}


my ($usrid, $usrmsg) =  $subgroup->delete_member($new_user->PrincipalId);
ok($usrid,"removed the user from the group - $usrmsg");
# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

#revoke the right to modify tickets in a queue
ok(($gv,$gm) = $group->PrincipalObj->RevokeRight( Object => $q, Right => 'ModifyTicket'),"Granted the group the right to modify tickets");
ok($gv,"revoke succeeed - $gm");

# {{{ Test the user's right to modify a ticket as a _queue_ admincc for a right granted at the _queue_ level

# Grant queue admin cc the right to modify ticket in the queue 
ok(my ($qv,$qm) = $q_as_system->AdminCc->PrincipalObj->GrantRight( Object => $q_as_system, Right => 'ModifyTicket'),"Granted the queue adminccs the right to modify tickets");
ok($qv, "Granted the right successfully - $qm");

# Add the user as a queue admincc
ok (my ($add_id, $add_msg) = $q_as_system->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
# Remove the user from the role  group
ok (my ($del_id, $del_msg) = $q_as_system->deleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");

# }}}

# {{{ Test the user's right to modify a ticket as a _ticket_ admincc with the right granted at the _queue_ level

# Add the user as a ticket admincc
ok (my( $uadd_id, $uadd_msg) = $new_tick2->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");

# Remove the user from the role  group
ok (( $del_id, $del_msg) = $new_tick2->deleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");


# Revoke the right to modify ticket in the queue 
ok(my ($rqv,$rqm) = $q_as_system->AdminCc->PrincipalObj->RevokeRight( Object => $q_as_system, Right => 'ModifyTicket'),"Revokeed the queue adminccs the right to modify tickets");
ok($rqv, "Revoked the right successfully - $rqm");

# }}}



# {{{ Test the user's right to modify a ticket as a _queue_ admincc for a right granted at the _system_ level

# Before we start Make sure the user does not have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without it being granted");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue without it being granted");

# Grant queue admin cc the right to modify ticket in the queue 
ok(($qv,$qm) = $q_as_system->AdminCc->PrincipalObj->GrantRight( Object => $RT::System, Right => 'ModifyTicket'),"Granted the queue adminccs the right to modify tickets");
ok($qv, "Granted the right successfully - $qm");

# Make sure the user can't modify the ticket before they're added as a watcher
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without being an admincc");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue without being an admincc");

# Add the user as a queue admincc
ok (($add_id, $add_msg) = $q_as_system->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
ok ($new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can modify tickets in the queue as an admincc");
# Remove the user from the role  group
ok (($del_id, $del_msg) = $q_as_system->deleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without group membership");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can't modify tickets in the queue without group membership");

# }}}

# {{{ Test the user's right to modify a ticket as a _ticket_ admincc with the right granted at the _queue_ level

ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can not modify the ticket without being an admincc");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj without being an admincc");


# Add the user as a ticket admincc
ok ( ($uadd_id, $uadd_msg) = $new_tick2->AddWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Added the new user as a queue admincc");
ok ($add_id, "the user is now a queue admincc - $add_msg");

# Make sure the user does have the right to modify tickets in the queue
ok ($new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can modify the ticket as an admincc");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj being only a ticket admincc");

# Remove the user from the role  group
ok ( ($del_id, $del_msg) = $new_tick2->deleteWatcher(Type => 'AdminCc', PrincipalId => $new_user->PrincipalId)  , "Deleted the new user as a queue admincc");

# Make sure the user doesn't have the right to modify tickets in the queue
ok (!$new_user->has_right( Object => $new_tick2, Right => 'ModifyTicket'), "User can't modify the ticket without being an admincc");
ok (!$new_user->has_right( Object => $new_tick2->QueueObj, Right => 'ModifyTicket'), "User can not modify tickets in the queue obj without being an admincc");


# Revoke the right to modify ticket in the queue 
ok(($rqv,$rqm) = $q_as_system->AdminCc->PrincipalObj->RevokeRight( Object => $RT::System, Right => 'ModifyTicket'),"Revokeed the queue adminccs the right to modify tickets");
ok($rqv, "Revoked the right successfully - $rqm");

# }}}




# Grant "privileged users" the system right to create users
# Create a privileged user.
# have that user create another user
# Revoke the right for privileged users to create users
# have the privileged user try to create another user and fail the ACL check


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
