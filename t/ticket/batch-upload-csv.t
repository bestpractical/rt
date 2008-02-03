#!/usr/bin/perl -w
use strict; use warnings;

use RT::Test; use Test::More tests => 12;
use_ok('RT');


use_ok('RT::ScripAction::CreateTickets');

my $QUEUE = 'uploadtest-'.$$;

my $queue_obj = RT::Model::Queue->new(current_user => RT->system_user);
$queue_obj->create(name => $QUEUE);

my $cf = RT::Model::CustomField->new(current_user => RT->system_user);
my ($val,$msg)  = $cf->create(name => 'Work Package-'.$$, type => 'Freeform', lookup_type => RT::Model::Ticket->custom_field_lookup_type, MaxValues => 1);
ok($cf->id);
ok($val,$msg);
($val, $msg) = $cf->add_to_object($queue_obj);
ok($val,$msg);
ok($queue_obj->ticket_custom_fields()->count, "We have a custom field, at least");


my $data = <<EOF;
id,Queue,subject,Status,Requestor,@{[$cf->name]}
create-1,$QUEUE,hi,new,root,2.0
create-2,$QUEUE,hello,new,root,3.0
EOF

my $action = RT::ScripAction::CreateTickets->new(current_user => RT::CurrentUser->new(name => 'root'));
ok ($action->current_user->id , "We have a current user");
 
$action->parse(content => $data);
my @results = $action->create_by_template();

my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
$tix->from_sql ("Queue = '". $QUEUE."'");
$tix->order_by( column => 'id', order => 'ASC' );
is($tix->count, 2, '2 tickets');

my $first = $tix->first();

is($first->subject(), 'hi'); 
is($first->first_custom_field_value($cf->id), '2.0');

my $second = $tix->next;
is($second->subject(), 'hello'); 
is($second->first_custom_field_value($cf->id), '3.0');
1;
