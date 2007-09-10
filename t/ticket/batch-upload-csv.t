#!/usr/bin/perl -w
use strict; use warnings;

use Test::More tests => 12;
use_ok('RT');
use RT::Test;

use_ok('RT::ScripAction::CreateTickets');

my $QUEUE = 'uploadtest-'.$$;

my $queue_obj = RT::Model::Queue->new($RT::SystemUser);
$queue_obj->create(Name => $QUEUE);

my $cf = RT::Model::CustomField->new($RT::SystemUser);
my ($val,$msg)  = $cf->create(Name => 'Work Package-'.$$, Type => 'Freeform', LookupType => RT::Model::Ticket->CustomFieldLookupType, MaxValues => 1);
ok($cf->id);
ok($val,$msg);
($val, $msg) = $cf->AddToObject($queue_obj);
ok($val,$msg);
ok($queue_obj->TicketCustomFields()->count, "We have a custom field, at least");


my $data = <<EOF;
id,Queue,Subject,Status,Requestor,@{[$cf->Name]}
create-1,$QUEUE,hi,new,root,2.0
create-2,$QUEUE,hello,new,root,3.0
EOF

my $action = RT::ScripAction::CreateTickets->new(CurrentUser => RT::CurrentUser->new('root'));
ok ($action->current_user->id , "WE have a current user");
 
$action->Parse(Content => $data);
my @results = $action->createByTemplate();

my $tix = RT::Model::TicketCollection->new($RT::SystemUser);
$tix->from_sql ("Queue = '". $QUEUE."'");
$tix->order_by( column => 'id', order => 'ASC' );
is($tix->count, 2, '2 tickets');

my $first = $tix->first();

is($first->Subject(), 'hi'); 
is($first->first_custom_field_value($cf->id), '2.0');

my $second = $tix->next;
is($second->Subject(), 'hello'); 
is($second->first_custom_field_value($cf->id), '3.0');
1;
