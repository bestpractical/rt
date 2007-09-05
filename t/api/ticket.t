
use strict;
use warnings;
use Test::More; 
plan tests => 88;
use Data::Dumper;
use RT;
use RT::Test;


{

use_ok ('RT::Model::Queue');
ok(my $testqueue = RT::Model::Queue->new($RT::SystemUser));
ok($testqueue->create( Name => 'ticket tests'));
isnt($testqueue->id , 0);
use_ok('RT::Model::CustomField');
ok(my $testcf = RT::Model::CustomField->new($RT::SystemUser));
my ($ret, $cmsg) = $testcf->create( Name => 'selectmulti',
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
                       
is($testcf->Values->count , 3);

use_ok('RT::Model::Ticket');

my $u = RT::Model::User->new($RT::SystemUser);
$u->load("root");
ok ($u->id, "Found the root user");
ok(my $t = RT::Model::Ticket->new($RT::SystemUser));
ok(my ($id, $msg) = $t->create( Queue => $testqueue->id,
               Subject => 'Testing',
               Owner => $u->id
              ));
isnt($id , 0);
is ($t->OwnerObj->id , $u->id, "Root is the ticket owner");
ok(my ($cfv, $cfm) =$t->AddCustomFieldValue(Field => $testcf->id,
                           Value => 'Value1'));
isnt($cfv , 0, "Custom field creation didn't return an error: $cfm");
is($t->CustomFieldValues($testcf->id)->count , 1);
ok($t->CustomFieldValues($testcf->id)->first &&
    $t->CustomFieldValues($testcf->id)->first->Content eq 'Value1', $t->CustomFieldValues($testcf->id)->first->Content . " (should be 'Value1')");;

ok(my ($cfdv, $cfdm) = $t->delete_custom_field_value(Field => $testcf->id,
                        Value => 'Value1'));
isnt ($cfdv , 0, "Deleted a custom field value: $cfdm");
is($t->CustomFieldValues($testcf->id)->count , 0);

ok(my $t2 = RT::Model::Ticket->new($RT::SystemUser));
ok($t2->load($id));
is($t2->Subject, 'Testing');
is($t2->QueueObj->id, $testqueue->id);
is($t2->OwnerObj->id, $u->id);

my $t3 = RT::Model::Ticket->new($RT::SystemUser);
my ($id3, $msg3) = $t3->create( Queue => $testqueue->id,
                                Subject => 'Testing',
                                Owner => $u->id);
my ($cfv1, $cfm1) = $t->AddCustomFieldValue(Field => $testcf->id,
 Value => 'Value1');
isnt($cfv1 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
my ($cfv2, $cfm2) = $t3->AddCustomFieldValue(Field => $testcf->id,
 Value => 'Value2');
isnt($cfv2 , 0, "Adding a custom field to ticket 2 is successful: $cfm");
my ($cfv3, $cfm3) = $t->AddCustomFieldValue(Field => $testcf->id,
 Value => 'Value3');
isnt($cfv3 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
is($t->CustomFieldValues($testcf->id)->count , 2,
   "This ticket has 2 custom field values");
is($t3->CustomFieldValues($testcf->id)->count , 1,
   "This ticket has 1 custom field value");



ok(require RT::Model::Ticket, "Loading the RT::Model::Ticket library");

}
{
my $t = RT::Model::Ticket->new($RT::SystemUser);

ok( $t->create(Queue => 'General', Due => '2002-05-21 00:00:00', ReferredToBy => 'http://www.cpan.org', RefersTo => 'http://fsck.com', Subject => 'This is a subject'), "Ticket Created");

ok ( my $id = $t->id, "Got ticket id");
like ($t->RefersTo->first->Target , qr/fsck.com/, "Got refers to");
like ($t->ReferredToBy->first->Base , qr/cpan.org/, "Got referredtoby");
is ($t->ResolvedObj->Unix, 0, "It hasn't been resolved - ". $t->ResolvedObj->Unix);


my $ticket = RT::Model::Ticket->new($RT::SystemUser);
my ($id, $msg) = $ticket->create(Subject => "Foo",
                Owner => $RT::Nobody->id,
                Status => 'open',
                Requestor => ['jesse@example.com'],
                Queue => '1'
                );
ok ($id, "Ticket $id was Created");
ok(my $group = RT::Model::Group->new($RT::SystemUser));
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Requestor'));
ok ($group->id, "Found the requestors object for this ticket");

ok(my $jesse = RT::Model::User->new($RT::SystemUser), "Creating a jesse rt::user");
$jesse->load_by_email('jesse@example.com');
ok($jesse->id,  "Found the jesse rt user");


ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $jesse->PrincipalId), "The ticket actually has jesse at fsck.com as a requestor");
ok (my ($add_id, $add_msg) = $ticket->AddWatcher(Type => 'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::Model::User->new($RT::SystemUser), "Creating a bob rt::user");
$bob->load_by_email('bob@fsck.com');
ok($bob->id,  "Found the bob rt user");
ok ($ticket->IsWatcher(Type => 'Requestor', PrincipalId => $bob->PrincipalId), "The ticket actually has bob at fsck.com as a requestor");;
ok ( ($add_id, $add_msg) = $ticket->deleteWatcher(Type =>'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$ticket->IsWatcher(Type => 'Requestor', Principal => $bob->PrincipalId), "The ticket no longer has bob at fsck.com as a requestor");;


$group = RT::Model::Group->new($RT::SystemUser);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Cc'));
ok ($group->id, "Found the cc object for this ticket");
$group = RT::Model::Group->new($RT::SystemUser);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'AdminCc'));
ok ($group->id, "Found the AdminCc object for this ticket");
$group = RT::Model::Group->new($RT::SystemUser);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Owner'));
ok ($group->id, "Found the Owner object for this ticket");
ok($group->has_member($RT::Nobody->UserObj->PrincipalObj), "the owner group has the member 'RT_System'");



my $t = RT::Model::Ticket->new($RT::SystemUser);
ok($t->create(Queue => 'general', Subject => 'SquelchTest'));

is(scalar $t->SquelchMailTo, 0, "The ticket has no squelched recipients");

my @returned = $t->SquelchMailTo('nobody@example.com');

is($#returned, 0, "The ticket has one squelched recipients");

my @names = $t->attributes->Names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");
@returned = $t->SquelchMailTo('nobody@example.com');


is($#returned, 0, "The ticket has one squelched recipients");

@names = $t->attributes->Names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");


my ($ret, $msg) = $t->UnsquelchMailTo('nobody@example.com');
ok($ret, "Removed nobody as a squelched recipient - ".$msg);
@returned = $t->SquelchMailTo();
is($#returned, -1, "The ticket has no squelched recipients". join(',',@returned));




my $t1 = RT::Model::Ticket->new($RT::SystemUser);
$t1->create ( Subject => 'Merge test 1', Queue => 'general', Requestor => 'merge1@example.com');
my $t1id = $t1->id;
my $t2 = RT::Model::Ticket->new($RT::SystemUser);
$t2->create ( Subject => 'Merge test 2', Queue => 'general', Requestor => 'merge2@example.com');
my $t2id = $t2->id;
my ($msg, $val) = $t1->MergeInto($t2->id);
ok ($msg,$val);
$t1 = RT::Model::Ticket->new($RT::SystemUser);
is ($t1->id, undef, "ok. we've got a blank ticket1");
$t1->load($t1id);

is ($t1->id, $t2->id);

is ($t1->Requestors->MembersObj->count, 2);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $root = RT::Model::User->new($RT::SystemUser);
$root->load('root');
ok ($root->id, "Loaded the root user");
my $t = RT::Model::Ticket->new($RT::SystemUser);
$t->load(1);
my ($val,$msg) = $t->Steal;
ok($val,$msg);
is ($t->OwnerObj->id, $RT::SystemUser->id , "SystemUser owns the ticket");
 ($val,$msg) =$t->set_Owner('root');
ok($val,$msg);
is ($t->OwnerObj->Name, 'root' , "Root owns the ticket");
my $txns = RT::Model::Transactions->new($RT::SystemUser);
$txns->order_by(column => 'id', order => 'DESC');
$txns->limit(column => 'ObjectId', value => '1');
$txns->limit(column => 'ObjectType', value => 'RT::Model::Ticket');
$txns->limit(column => 'Type', operator => '!=',  value => 'EmailRecord');

my $give  = $txns->first;
is($give->Type, 'Give');


is($give-> NewValue , $root->id , "Stolen from root");
is($give->OldValue , $RT::SystemUser->id , "Stolen by the systemuser");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $tt = RT::Model::Ticket->new($RT::SystemUser);
my ($id, $tid, $msg)= $tt->create(Queue => 'general',
            Subject => 'test');
ok($id, $msg);
is($tt->Status, 'new', "New ticket is Created as new");

($id, $msg) = $tt->set_Status('open');
ok($id, $msg);
like($msg, qr/open/i, "Status message is correct");
($id, $msg) = $tt->set_Status('resolved');
ok($id, $msg);
like($msg, qr/resolved/i, "Status message is correct");
($id, $msg) = $tt->set_Status('resolved');
ok(!$id,$msg);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
