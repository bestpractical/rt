use strict;
use warnings;

use RT::Test tests => 12;
use_ok('RT');

use_ok('RT::Action::CreateTickets');

my $QUEUE = 'uploadtest-'.$$;

my $queue_obj = RT::Queue->new(RT->SystemUser);
$queue_obj->Create(Name => $QUEUE);

my $cf = RT::CustomField->new(RT->SystemUser);
my ($val,$msg)  = $cf->Create(Name => 'Work Package-'.$$, Type => 'Freeform', LookupType => RT::Ticket->CustomFieldLookupType, MaxValues => 1);
ok($cf->id);
ok($val,$msg);
($val, $msg) = $cf->AddToObject($queue_obj);
ok($val,$msg);
ok($queue_obj->TicketCustomFields()->Count, "We have a custom field, at least");


my $data = <<EOF;
id,Queue,Subject,Status,Requestor,@{[$cf->Name]}
create-1,$QUEUE,hi,new,root,2.0
create-2,$QUEUE,hello,new,root,3.0
EOF

my $action = RT::Action::CreateTickets->new(CurrentUser => RT::CurrentUser->new('root'));
ok ($action->CurrentUser->id , "WE have a current user");
 
$action->Parse(Content => $data);
my @results = $action->CreateByTemplate();

my $tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL ("Queue = '". $QUEUE."'");
$tix->OrderBy( FIELD => 'id', ORDER => 'ASC' );
is($tix->Count, 2, '2 tickets');

my $first = $tix->First();

is($first->Subject(), 'hi'); 
is($first->FirstCustomFieldValue($cf->id), '2.0');

my $second = $tix->Next;
is($second->Subject(), 'hello'); 
is($second->FirstCustomFieldValue($cf->id), '3.0');
