
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 88;
use Data::Dumper;
use RT;



{

use_ok ('RT::Model::Queue');
ok(my $testqueue = RT::Model::Queue->new(current_user => RT->system_user));
ok($testqueue->create( name => 'ticket tests'));
isnt($testqueue->id , 0);
use_ok('RT::Model::CustomField');
ok(my $testcf = RT::Model::CustomField->new(current_user => RT->system_user));
my ($ret, $cmsg) = $testcf->create( name => 'selectmulti',
                    Queue => $testqueue->id,
                               type => 'SelectMultiple');
ok($ret,"Created the custom field - ".$cmsg);
($ret,$cmsg) = $testcf->add_value ( name => 'Value1',
                        SortOrder => '1',
                        Description => 'A testing value');

ok($ret, "Added a value - ".$cmsg);

ok($testcf->add_value ( name => 'Value2',
                        SortOrder => '2',
                        Description => 'Another testing value'));
ok($testcf->add_value ( name => 'Value3',
                        SortOrder => '3',
                        Description => 'Yet Another testing value'));
                       
is($testcf->values->count , 3);

use_ok('RT::Model::Ticket');

my $u = RT::Model::User->new(current_user => RT->system_user);
$u->load("root");
ok ($u->id, "Found the root user");
ok(my $t = RT::Model::Ticket->new(current_user => RT->system_user));
ok(my ($id, $msg) = $t->create( Queue => $testqueue->id,
               Subject => 'Testing',
               Owner => $u->id
              ));
isnt($id , 0);
is ($t->owner_obj->id , $u->id, "Root is the ticket owner");
ok(my ($cfv, $cfm) =$t->add_custom_field_value(Field => $testcf->id,
                           Value => 'Value1'));
isnt($cfv , 0, "Custom field creation didn't return an error: $cfm");
is($t->custom_field_values($testcf->id)->count , 1);
ok($t->custom_field_values($testcf->id)->first &&
    $t->custom_field_values($testcf->id)->first->content eq 'Value1', $t->custom_field_values($testcf->id)->first->content . " (should be 'Value1')");;

ok(my ($cfdv, $cfdm) = $t->delete_custom_field_value(Field => $testcf->id,
                        Value => 'Value1'));
isnt ($cfdv , 0, "Deleted a custom field value: $cfdm");
is($t->custom_field_values($testcf->id)->count , 0);

ok(my $t2 = RT::Model::Ticket->new(current_user => RT->system_user));
ok($t2->load($id));
is($t2->subject, 'Testing');
is($t2->queue_obj->id, $testqueue->id);
is($t2->owner_obj->id, $u->id);

my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id3, $msg3) = $t3->create( Queue => $testqueue->id,
                                Subject => 'Testing',
                                Owner => $u->id);
my ($cfv1, $cfm1) = $t->add_custom_field_value(Field => $testcf->id,
 Value => 'Value1');
isnt($cfv1 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
my ($cfv2, $cfm2) = $t3->add_custom_field_value(Field => $testcf->id,
 Value => 'Value2');
isnt($cfv2 , 0, "Adding a custom field to ticket 2 is successful: $cfm");
my ($cfv3, $cfm3) = $t->add_custom_field_value(Field => $testcf->id,
 Value => 'Value3');
isnt($cfv3 , 0, "Adding a custom field to ticket 1 is successful: $cfm");
is($t->custom_field_values($testcf->id)->count , 2,
   "This ticket has 2 custom field values");
is($t3->custom_field_values($testcf->id)->count , 1,
   "This ticket has 1 custom field value");



ok(require RT::Model::Ticket, "Loading the RT::Model::Ticket library");

}
{
my $t = RT::Model::Ticket->new(current_user => RT->system_user);

ok( $t->create(Queue => 'General', Due => '2002-05-21 00:00:00', ReferredToBy => 'http://www.cpan.org', RefersTo => 'http://fsck.com', Subject => 'This is a subject'), "Ticket Created");

ok ( my $id = $t->id, "Got ticket id");
like ($t->refers_to->first->Target , qr/fsck.com/, "Got refers to");
like ($t->referred_to_by->first->Base , qr/cpan.org/, "Got referredtoby");
is ($t->resolved_obj->unix, 0, "It hasn't been resolved - ". $t->resolved_obj->Unix);


my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my $msg;
($id, $msg) = $ticket->create(Subject => "Foo",
                Owner => RT->nobody->id,
                Status => 'open',
                Requestor => ['jesse@example.com'],
                Queue => '1'
                );
ok ($id, "Ticket $id was Created");
ok(my $group = RT::Model::Group->new(current_user => RT->system_user));
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Requestor'));
ok ($group->id, "Found the requestors object for this ticket");

ok(my $jesse = RT::Model::User->new(current_user => RT->system_user), "Creating a jesse rt::user");
$jesse->load_by_email('jesse@example.com');
ok($jesse->id,  "Found the jesse rt user");


ok ($ticket->is_watcher(Type => 'Requestor', principal_id => $jesse->principal_id), "The ticket actually has jesse at fsck.com as a requestor");
ok (my ($add_id, $add_msg) = $ticket->add_watcher(Type => 'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok ($add_id, "Add succeeded: ($add_msg)");
ok(my $bob = RT::Model::User->new(current_user => RT->system_user), "Creating a bob rt::user");
$bob->load_by_email('bob@fsck.com');
ok($bob->id,  "Found the bob rt user");
ok ($ticket->is_watcher(Type => 'Requestor', principal_id => $bob->principal_id), "The ticket actually has bob at fsck.com as a requestor");;
ok ( ($add_id, $add_msg) = $ticket->delete_watcher(Type =>'Requestor', Email => 'bob@fsck.com'), "Added bob at fsck.com as a requestor");
ok (!$ticket->is_watcher(Type => 'Requestor', principal_id => $bob->principal_id), "The ticket no longer has bob at fsck.com as a requestor");;


$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Cc'));
ok ($group->id, "Found the cc object for this ticket");
$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'AdminCc'));
ok ($group->id, "Found the AdminCc object for this ticket");
$group = RT::Model::Group->new(current_user => RT->system_user);
ok($group->load_ticket_role_group(Ticket => $id, Type=> 'Owner'));
ok ($group->id, "Found the Owner object for this ticket");
ok($group->has_member(RT->nobody->user_object->principal_object), "the owner group has the member 'RT_System'");



$t = RT::Model::Ticket->new(current_user => RT->system_user);
ok($t->create(Queue => 'general', Subject => 'SquelchTest'));

is(scalar $t->squelch_mail_to, 0, "The ticket has no squelched recipients");

my @returned = $t->squelch_mail_to('nobody@example.com');

is($#returned, 0, "The ticket has one squelched recipients");

my @names = $t->attributes->names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");
@returned = $t->squelch_mail_to('nobody@example.com');


is($#returned, 0, "The ticket has one squelched recipients");

@names = $t->attributes->names;
is(shift @names, 'SquelchMailTo', "The attribute we have is SquelchMailTo");

my $ret;
($ret, $msg) = $t->unsquelch_mail_to('nobody@example.com');
ok($ret, "Removed nobody as a squelched recipient - ".$msg);
@returned = $t->squelch_mail_to();
is($#returned, -1, "The ticket has no squelched recipients". join(',',@returned));




my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
$t1->create ( Subject => 'Merge test 1', Queue => 'general', Requestor => 'merge1@example.com');
my $t1id = $t1->id;
my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
$t2->create ( Subject => 'Merge test 2', Queue => 'general', Requestor => 'merge2@example.com');
my $t2id = $t2->id;
my $val;
($msg, $val) = $t1->merge_into($t2->id);
ok ($msg,$val);
$t1 = RT::Model::Ticket->new(current_user => RT->system_user);
is ($t1->id, undef, "ok. we've got a blank ticket1");
$t1->load($t1id);

is ($t1->id, $t2->id);

is ($t1->requestors->members_obj->count, 2);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{

my $root = RT::Model::User->new(current_user => RT->system_user);
$root->load('root');
ok ($root->id, "Loaded the root user");
my $t = RT::Model::Ticket->new(current_user => RT->system_user);
$t->load(1);
my ($val,$msg) = $t->steal;
ok($val,$msg);
is ($t->owner_obj->id, RT->system_user->id , "system_user owns the ticket");
 ($val,$msg) =$t->set_owner('root');
ok($val,$msg);
is ($t->owner_obj->name, 'root' , "Root owns the ticket");
my $txns = RT::Model::TransactionCollection->new(current_user => RT->system_user);
$txns->order_by(column => 'id', order => 'DESC');
$txns->limit(column => 'object_id', value => '1');
$txns->limit(column => 'object_type', value => 'RT::Model::Ticket');
$txns->limit(column => 'type', operator => '!=',  value => 'EmailRecord');

my $give  = $txns->first;
is($give->type, 'Give');


is($give-> new_value , $root->id , "Stolen from root");
is($give->old_value , RT->system_user->id , "Stolen by the systemuser");


}

{

my $tt = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id, $tid, $msg)= $tt->create(Queue => 'general',
            Subject => 'test');
ok($id, $msg);
is($tt->Status, 'new', "New ticket is Created as new");

($id, $msg) = $tt->set_status('open');
ok($id, $msg);
like($msg, qr/open/i, "Status message is correct");
($id, $msg) = $tt->set_status('resolved');
ok($id, $msg);
like($msg, qr/resolved/i, "Status message is correct");
($id, $msg) = $tt->set_status('resolved');
ok(!$id,$msg);



}

1;
