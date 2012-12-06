
use strict;
use warnings;
use RT;
use RT::Test tests => 54;


{

ok (require RT::Action::CreateTickets);
use_ok('RT::Scrip');
use_ok('RT::Template');
use_ok('RT::ScripAction');
use_ok('RT::ScripCondition');
use_ok('RT::Ticket');


use_ok('RT::CustomField');

my $global_cf = RT::CustomField->new($RT::SystemUser);
my ($id, $msg)=  $global_cf->Create( Name => 'GlobalCF',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field',
                                 Type=> 'SelectSingle');
ok($id, 'Global custom field correctly created');


my $approvalsq = RT::Queue->new(RT->SystemUser);
$approvalsq->Create(Name => 'Approvals');
ok ($approvalsq->Id, "Created Approvals test queue");

my $queue_cf = RT::CustomField->new($RT::SystemUser);
($id) = $queue_cf->Create(
    Name => 'QueueCF',
    Queue => $approvalsq->Id,
    SortOrder => 2,
    Description => 'A testing queue-specific custom field',
    Type => 'SelectSingle',
);
ok($id, 'Queue-specific custom field correctly created');



my $approvals = 
'===Create-Ticket: approval
Queue: Approvals
Type: approval
AdminCc: {join ("\nAdminCc: ",@admins) }
Depended-On-By: {$Tickets{"TOP"}->Id}
Refers-To: TOP 
CustomField-GlobalCF: A Value
CustomField-QueueCF: Another Value
Subject: Approval for ticket: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: two
Subject: Manager approval.
Depended-On-By: approval
Queue: Approvals
Content-Type: text/plain
Content: 
Your minion approved ticket {$Tickets{"TOP"}->Id}. you ok with that?
ENDOFCONTENT
';

like ($approvals , qr/Content/, "Read in the approvals template");

my $apptemp = RT::Template->new(RT->SystemUser);
$apptemp->Create( Content => $approvals, Name => "Approvals", Queue => "0");

ok ($apptemp->Id);

my $q = RT::Queue->new(RT->SystemUser);
$q->Create(Name => 'WorkflowTest');
ok ($q->Id, "Created workflow test queue");

my $scrip = RT::Scrip->new(RT->SystemUser);
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'On Transaction',
                ScripAction => 'Create Tickets',
                Template => 'Approvals',
                Queue => $q->Id);
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new(RT->SystemUser);
my($tid, $ttrans, $tmsg) = $t->Create(Subject => "Sample workflow test",
           Owner => "root",
           Queue => $q->Id);

ok ($tid,$tmsg);

my $deps = $t->DependsOn;
is ($deps->Count, 1, "The ticket we created depends on one other ticket");
my $dependson= $deps->First->TargetObj;
ok ($dependson->Id, "It depends on a real ticket");
is ($dependson->FirstCustomFieldValue('GlobalCF'), 'A Value',
  'global custom field was set');
is ($dependson->FirstCustomFieldValue('QueueCF'), 'Another Value',
  'queue custom field was set');
unlike ($dependson->Subject, qr/\{/, "The subject doesn't have braces in it. that means we're interpreting expressions");
is ($t->ReferredToBy->Count,1, "It's only referred to by one other ticket");
is ($t->ReferredToBy->First->BaseObj->Id,$t->DependsOn->First->TargetObj->Id, "The same ticket that depends on it refers to it.");
use RT::Action::CreateTickets;
my $action =  RT::Action::CreateTickets->new( CurrentUser => RT->SystemUser);

# comma-delimited templates
my $commas = <<"EOF";
id,Queue,Subject,Owner,Content
ticket1,General,"foo, bar",root,blah
ticket2,General,foo bar,root,blah
ticket3,General,foo' bar,root,blah'boo
ticket4,General,foo' bar,,blah'boo
EOF


# Comma delimited templates with missing data
my $sparse_commas = <<"EOF";
id,Queue,Subject,Owner,Requestor
ticket14,General,,,bobby
ticket15,General,,,tommy
ticket16,General,,suzie,tommy
ticket17,General,Foo "bar" baz,suzie,tommy
ticket18,General,'Foo "bar" baz',suzie,tommy
ticket19,General,'Foo bar' baz,suzie,tommy
EOF


# tab-delimited templates
my $tabs = <<"EOF";
id\tQueue\tSubject\tOwner\tContent
ticket10\tGeneral\t"foo' bar"\troot\tblah'
ticket11\tGeneral\tfoo, bar\troot\tblah
ticket12\tGeneral\tfoo' bar\troot\tblah'boo
ticket13\tGeneral\tfoo' bar\t\tblah'boo
EOF

my %expected;

$expected{ticket1} = <<EOF;
Queue: General
Subject: foo, bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket2} = <<EOF;
Queue: General
Subject: foo bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket3} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket4} = <<EOF;
Queue: General
Subject: foo' bar
Owner: 
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket10} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'
ENDOFCONTENT
EOF

$expected{ticket11} = <<EOF;
Queue: General
Subject: foo, bar
Owner: root
Content: blah
ENDOFCONTENT
EOF

$expected{ticket12} = <<EOF;
Queue: General
Subject: foo' bar
Owner: root
Content: blah'boo
ENDOFCONTENT
EOF

$expected{ticket13} = <<EOF;
Queue: General
Subject: foo' bar
Owner: 
Content: blah'boo
ENDOFCONTENT
EOF


$expected{'ticket14'} = <<EOF;
Queue: General
Subject: 
Owner: 
Requestor: bobby
EOF
$expected{'ticket15'} = <<EOF;
Queue: General
Subject: 
Owner: 
Requestor: tommy
EOF
$expected{'ticket16'} = <<EOF;
Queue: General
Subject: 
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket17'} = <<EOF;
Queue: General
Subject: Foo "bar" baz
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket18'} = <<EOF;
Queue: General
Subject: Foo "bar" baz
Owner: suzie
Requestor: tommy
EOF
$expected{'ticket19'} = <<EOF;
Queue: General
Subject: 'Foo bar' baz
Owner: suzie
Requestor: tommy
EOF




$action->Parse(Content =>$commas);
$action->Parse(Content =>$sparse_commas);
$action->Parse(Content => $tabs);

my %got;
foreach (@{ $action->{'create_tickets'} }) {
  $got{$_} = $action->{'templates'}->{$_};
}

foreach my $id ( sort keys %expected ) {
    ok(exists($got{"create-$id"}), "template exists for $id");
    is($got{"create-$id"}, $expected{$id}, "template is correct for $id");
}


}

