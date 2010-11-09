
use strict;
use warnings;
use RT;
use RT::Test tests => 87;


{

use_ok ('RT::Queue');
ok(my $testqueue = RT::Queue->new(RT->SystemUser));
ok($testqueue->Create( Name => 'ticket tests'));
isnt($testqueue->Id , 0);
use_ok('RT::CustomField');
ok(my $testcf = RT::CustomField->new(RT->SystemUser));
my ($ret, $cmsg) = $testcf->Create( Name => 'selectmulti',
                    Queue => $testqueue->id,
                               Type => 'SelectMultiple');
ok($ret,"Created the custom field - ".$cmsg);
($ret,$cmsg) = $testcf->AddValue ( Name => 'Value1',
                        SortOrder => '1',
                        Description => 'A testing value');

ok($ret, "Added a value - ".$cmsg);

ok($testcf->AddValue ( Name => 'Value2',
                        SortOrder => '2',
                        Description => 'Another testing value'));
ok($testcf->AddValue ( Name => 'Value3',
                        SortOrder => '3',
                        Description => 'Yet Another testing value'));
                       
is($testcf->Values->Count , 3);

use_ok('RT::Ticket');

my $u = RT::User->new(RT->SystemUser);
$u->Load("root");
ok ($u->Id, "Found the root user");
ok(my $t = RT::Ticket->new(RT->SystemUser));
ok(my ($id, $msg) = $t->Create( Queue => $testqueue->Id,
               Subject => 'Testing',
               Owner => $u->Id
              ));
isnt($id , 0);
is ($t->OwnerObj->Id , $u->Id, "Root is the ticket owner");
ok(my ($cfv, $cfm) =$t->AddCustomFieldValue(Field => $testcf->Id,
                           Value => 'Value1'));
isnt($cfv , 0, "Custom field creation didn't return an error: $cfm");
is($t->CustomFieldValues($testcf->Id)->Count , 1);
ok($t->CustomFieldValues($testcf->Id)->First &&
    $t->CustomFieldValues($testcf->Id)->First->Content eq 'Value1');

ok(my ($cfdv, $cfdm) = $t->DeleteCustomFieldValue(Field => $testcf->Id,
                        Value => 'Value1'));
isnt ($cfdv , 0, "Deleted a custom field value: $cfdm");
is($t->CustomFieldValues($testcf->Id)->Count , 0);

ok(my $t2 = RT::Ticket->new(RT->SystemUser));
ok($t2->Load($id));
is($t2->Subject, 'Testing');
is($t2->QueueObj->Id, $testqueue->id);
is($t2->OwnerObj->Id, $u->Id);

my $t3 = RT::Ticket->new(RT->SystemUser);
my ($id3, $msg3) = $t3->Create( Queue => $testqueue->Id,
                                Subject => 'Testing',
                                Owner => $u->Id);
my ($cfv1, $cfm1) = $t->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value1');
isnt($cfv1 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
my ($cfv2, $cfm2) = $t3->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value2');
isnt($cfv2 , 0, "Adding a custom field to ticket 2 is successful: $cfm");
my ($cfv3, $cfm3) = $t->AddCustomFieldValue(Field => $testcf->Id,
 Value => 'Value3');
isnt($cfv3 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
is($t->CustomFieldValues($testcf->Id)->Count , 2,
   "This ticket has 2 custom field values");
is($t3->CustomFieldValues($testcf->Id)->Count , 1,
   "This ticket has 1 custom field value");


}

{


ok(require RT::Ticket, "Loading the RT::Ticket library");


}

{

my $t = RT::Ticket->new(RT->SystemUser);

ok( $t->Create(Queue => 'General', Due => '2002-05-21 00:00:00', ReferredToBy => 'http://www.cpan.org', RefersTo => 'http://fsck.com', Subject => 'This is a subject'), "Ticket Created");

ok ( my $id = $t->Id, "Got ticket id");
like ($t->RefersTo->First->Target , qr/fsck.com/, "Got refers to");
like ($t->ReferredToBy->First->Base , qr/cpan.org/, "Got referredtoby");
is ($t->ResolvedObj->Unix, 0, "It hasn't been resolved - ". $t->ResolvedObj->Unix);


}

{

my $ticket = RT::Ticket->new(RT->SystemUser);
my ($id, $msg) = $ticket->Create(Subject => "Foo",
                Owner => RT->SystemUser->Id,
                Status => 'open',
                Requestor => ['jesse@example.com'],
                Queue => '1'
                );
ok ($id, "Ticket $id was created");
ok(my $group = RT::Group->new(RT->SystemUser));
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Requestor'));
ok ($group->Id, "Found the requestors object for this ticket");

ok(my $jesse = RT::User->new(RT->SystemUser), "Creating a jesse rt::user");
$jesse->LoadByEmail('jesse@example.com');
ok($jesse->Id,  "Found the jesse rt user");


ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $jesse->PrincipalId), "The ticket actually has jesse at fsck.com as a requestor");
ok (my ($add_id, $add_msg) = $ticket->AddWatcher(Type => 'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::User->new(RT->SystemUser), "Creating a bob rt::user");
$bob->LoadByEmail('bob@fsck.com');
ok($bob->Id,  "Found the bob rt user");
ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $bob->PrincipalId), "The ticket actually has bob at fsck.com as a requestor");
ok ( ($add_id, $add_msg) = $ticket->DeleteWatcher(Type =>'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$ticket->IsWatcher(Type => 'Requestor', PrincipalId => $bob->PrincipalId), "The ticket no longer has bob at fsck.com as a requestor");


$group = RT::Group->new(RT->SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Cc'));
ok ($group->Id, "Found the cc object for this ticket");
$group = RT::Group->new(RT->SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'AdminCc'));
ok ($group->Id, "Found the AdminCc object for this ticket");
$group = RT::Group->new(RT->SystemUser);
ok($group->LoadTicketRoleGroup(Ticket => $id, Type=> 'Owner'));
ok ($group->Id, "Found the Owner object for this ticket");
ok($group->HasMember(RT->SystemUser->UserObj->PrincipalObj), "the owner group has the member 'RT_System'");


}

{

my $t = RT::Ticket->new(RT->SystemUser);
ok($t->Create(Queue => 'general', Subject => 'SquelchTest', SquelchMailTo => 'nobody@example.com'));

my @returned = $t->SquelchMailTo();
is($#returned, 0, "The ticket has one squelched recipients");

my ($ret, $msg) = $t->UnsquelchMailTo('nobody@example.com');
ok($ret, "Removed nobody as a squelched recipient - ".$msg);
@returned = $t->SquelchMailTo();
is($#returned, -1, "The ticket has no squelched recipients". join(',',@returned));



@returned = $t->SquelchMailTo('nobody@example.com');
is($#returned, 0, "The ticket has one squelched recipients");

my @names = $t->Attributes->Names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");
@returned = $t->SquelchMailTo('nobody@example.com');


is($#returned, 0, "The ticket has one squelched recipients");

@names = $t->Attributes->Names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");


($ret, $msg) = $t->UnsquelchMailTo('nobody@example.com');
ok($ret, "Removed nobody as a squelched recipient - ".$msg);
@returned = $t->SquelchMailTo();
is($#returned, -1, "The ticket has no squelched recipients". join(',',@returned));



}

{

my $t1 = RT::Ticket->new(RT->SystemUser);
$t1->Create ( Subject => 'Merge test 1', Queue => 'general', Requestor => 'merge1@example.com');
my $t1id = $t1->id;
my $t2 = RT::Ticket->new(RT->SystemUser);
$t2->Create ( Subject => 'Merge test 2', Queue => 'general', Requestor => 'merge2@example.com');
my $t2id = $t2->id;
my ($msg, $val) = $t1->MergeInto($t2->id);
ok ($msg,$val);
$t1 = RT::Ticket->new(RT->SystemUser);
is ($t1->id, undef, "ok. we've got a blank ticket1");
$t1->Load($t1id);

is ($t1->id, $t2->id);

is ($t1->Requestors->MembersObj->Count, 2);



}

{

my $root = RT::User->new(RT->SystemUser);
$root->Load('root');
ok ($root->Id, "Loaded the root user");
my $t = RT::Ticket->new(RT->SystemUser);
$t->Load(1);
$t->SetOwner('root');
is ($t->OwnerObj->Name, 'root' , "Root owns the ticket");
$t->Steal();
is ($t->OwnerObj->id, RT->SystemUser->id , "SystemUser owns the ticket");
my $txns = RT::Transactions->new(RT->SystemUser);
$txns->OrderBy(FIELD => 'id', ORDER => 'DESC');
$txns->Limit(FIELD => 'ObjectId', VALUE => '1');
$txns->Limit(FIELD => 'ObjectType', VALUE => 'RT::Ticket');
$txns->Limit(FIELD => 'Type', OPERATOR => '!=',  VALUE => 'EmailRecord');

my $steal  = $txns->First;
is($steal->OldValue , $root->Id , "Stolen from root");
is($steal->NewValue , RT->SystemUser->Id , "Stolen by the systemuser");


}

{

my $tt = RT::Ticket->new(RT->SystemUser);
my ($id, $tid, $msg)= $tt->Create(Queue => 'general',
            Subject => 'test');
ok($id, $msg);
is($tt->Status, 'new', "New ticket is created as new");

($id, $msg) = $tt->SetStatus('open');
ok($id, $msg);
like($msg, qr/open/i, "Status message is correct");
($id, $msg) = $tt->SetStatus('resolved');
ok($id, $msg);
like($msg, qr/resolved/i, "Status message is correct");
($id, $msg) = $tt->SetStatus('resolved');
ok(!$id,$msg);



}

