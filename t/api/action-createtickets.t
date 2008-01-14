
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 49;
use RT;



{

ok (require RT::ScripAction::CreateTickets);
use_ok('RT::Model::Scrip');
use_ok('RT::Model::Template');
use_ok('RT::Model::ScripAction');
use_ok('RT::Model::ScripCondition');
use_ok('RT::Model::Ticket');

my $approvalsq = RT::Model::Queue->new(current_user => RT->system_user);
$approvalsq->create(name => 'Approvals');
ok ($approvalsq->id, "Created Approvals test queue");


my $approvals = 
'===Create-Ticket: approval
Queue: ___Approvals
Type: approval
AdminCc: {join ("\nAdminCc: ",@admins) }
Depended-On-By: {$Tickets{"TOP"}->id}
Refers-To: TOP 
Subject: Approval for ticket: {$Tickets{"TOP"}->id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the ticket {$Tickets{"TOP"}->id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: two
Subject: Manager approval.
Depended-On-By: approval
Queue: ___Approvals
Content-Type: text/plain
Content: 
Your minion approved ticket {$Tickets{"TOP"}->id}. you ok with that?
ENDOFCONTENT
';

like ($approvals , qr/Content/, "Read in the approvals template");

my $apptemp = RT::Model::Template->new(current_user => RT->system_user);
$apptemp->create( Content => $approvals, name => "Approvals", Queue => "0");

ok ($apptemp->id);

my $q = RT::Model::Queue->new(current_user => RT->system_user);
$q->create(name => 'WorkflowTest');
ok ($q->id, "Created workflow test queue");

my $scrip = RT::Model::Scrip->new(current_user => RT->system_user);
my ($sval, $smsg) =$scrip->create( ScripCondition => 'On Transaction',
                ScripAction => 'Create Tickets',
                Template => 'Approvals',
                Queue => $q->id);
ok ($sval, $smsg);
ok ($scrip->id, "Created the scrip");
ok ($scrip->template_obj->id, "Created the scrip template");
ok ($scrip->ConditionObj->id, "Created the scrip condition");
ok ($scrip->ActionObj->id, "Created the scrip action");

my $t = RT::Model::Ticket->new(current_user => RT->system_user);
my($tid, $ttrans, $tmsg) = $t->create(Subject => "Sample workflow test",
           Owner => "root",
           Queue => $q->id);

ok ($tid,$tmsg);

my $deps = $t->DependsOn;
is ($deps->count, 1, "The ticket we Created depends on one other ticket");
my $dependson= $deps->first->TargetObj;
ok ($dependson->id, "It depends on a real ticket");
unlike ($dependson->Subject, qr/{/, "The subject doesn't have braces in it. that means we're interpreting expressions");
is ($t->ReferredToBy->count,1, "It's only referred to by one other ticket");
is ($t->ReferredToBy->first->base_obj->id,$t->DependsOn->first->TargetObj->id, "The same ticket that depends on it refers to it.");
use RT::ScripAction::CreateTickets;
my $action =  RT::ScripAction::CreateTickets->new( CurrentUser => RT->system_user);;

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
foreach (@{ $action->{'CreateTickets'} }) {
  $got{$_} = $action->{'templates'}->{$_};
}

foreach my $id ( sort keys %expected ) {
    ok(exists($got{"create-$id"}), "template exists for $id");
    is($got{"create-$id"}, $expected{$id}, "template is correct for $id");
}


}

1;
