
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Email::Abstract; require Test::Email; 1 }
        or plan skip_all => 'require Email::Abstract and Test::Email';
}

plan tests => 28;

use RT;
use RT::Test;
use RT::Test::Email;

RT->Config->Set( LogToScreen => 'debug' );

my ($baseurl, $m) = RT::Test->started_ok;

my ($user_a, $user_b) = (RT::User->new($RT::SystemUser), RT::User->new($RT::SystemUser));
my ($user_c) = RT::User->new($RT::SystemUser);

$user_a->Create( Name => 'CFO', Privileged => 1, EmailAddress => 'cfo@company.com');
$user_b->Create( Name => 'CEO', Privileged => 1, EmailAddress => 'ceo@company.com');
$user_c->Create( Name => 'minion', Privileged => 1, EmailAddress => 'minion@company.com');

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('___Approvals');

$q->SetDisabled(0);

my ($val, $msg);
($val, $msg) = $user_a->PrincipalObj->GrantRight(Object =>$q, Right => $_)
    for qw(ModifyTicket OwnTicket ShowTicket);
($val, $msg) = $user_b->PrincipalObj->GrantRight(Object =>$q, Right => $_)
    for qw(ModifyTicket OwnTicket ShowTicket);

# XXX: we need to make the first approval ticket open so notification is sent.
my $approvals = 
'===Create-Ticket: for-CFO
Queue: ___Approvals
Type: approval
Owner: CFO
Requestors: {$Tickets{"TOP"}->Requestors}
Refers-To: TOP
Subject: CFO Approval for PO: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the PO ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: for-CEO
Queue: ___Approvals
Type: approval
Owner: CEO
Requestors: {$Tickets{"TOP"}->Requestors}
Subject: PO approval request for {$Tickets{"TOP"}->Subject}
Refers-To: TOP
Depends-On: for-CFO
Depended-On-By: {$Tickets{"TOP"}->Id}
Content-Type: text/plain
Content: 
Your CFO approved PO ticket {$Tickets{"TOP"}->Id} for minion. you ok with that?
ENDOFCONTENT
';

my $apptemp = RT::Template->new($RT::SystemUser);
$apptemp->Create( Content => $approvals, Name => "PO Approvals", Queue => "0");

ok($apptemp->Id);

$q = RT::Queue->new($RT::SystemUser);
$q->Create(Name => 'PO');
ok ($q->Id, "Created PO queue");

my $scrip = RT::Scrip->new($RT::SystemUser);
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'On Create',
                ScripAction => 'Create Tickets',
                Template => 'PO Approvals',
                Queue => $q->Id);
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new($RT::SystemUser);
my ($tid, $ttrans, $tmsg);

mail_ok {
    ($tid, $ttrans, $tmsg) =
        $t->Create(Subject => "PO for stationary",
                   Owner => "root", Requestor => 'minion',
                   Queue => $q->Id);
} { from => qr/PO via RT/,
    to => 'minion@company.com',
    subject => qr/PO for stationary/,
    body => qr/automatically generated in response/
};

ok ($tid,$tmsg);

is ($t->ReferredToBy->Count,2, "referred to by the two tickets");

# open the approval tickets that are ready for approval
mail_ok {
    for my $ticket ($t->AllDependsOn) {
        next if $ticket->Type ne 'approval' && $ticket->Status ne 'new';
        next if $ticket->HasUnresolvedDependencies( Type => 'approval' );
        $ticket->SetStatus('open');
    }
} { from => qr/RT System/,
    to => 'cfo@company.com',
    subject => qr/New Pending Approval: CFO Approval/,
    body => qr/pending your approval/
};

my $deps = $t->DependsOn;
is ($deps->Count, 1, "The ticket we created depends on one other ticket");
my $dependson_ceo= $deps->First->TargetObj;
ok ($dependson_ceo->Id, "It depends on a real ticket");
like($dependson_ceo->Subject, qr/PO approval request.*stationary/);

$deps = $dependson_ceo->DependsOn;
is ($deps->Count, 1, "The ticket we created depends on one other ticket");
my $dependson_cfo = $deps->First->TargetObj;
ok ($dependson_cfo->Id, "It depends on a real ticket");

like($dependson_cfo->Subject, qr/CFO Approval for PO.*stationary/);

is_deeply([ $t->Status, $dependson_cfo->Status, $dependson_ceo->Status ],
          [ 'new', 'open', 'new'], 'tickets in correct state');

mail_ok {
    my $cfo = RT::CurrentUser->new;
    $cfo->Load( $user_a );

    $dependson_cfo->CurrentUser($cfo);
    my ($ok, $msg) = $dependson_cfo->SetStatus( Status => 'resolved' );
    ok($ok, "cfo can approve - $msg");

} { from => qr/RT System/,
    to => 'ceo@company.com',
    subject => qr/New Pending Approval: PO approval request for PO/,
    body => qr/pending your approval/
},{ from => qr/CFO via RT/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CFO/
};

is ($t->DependsOn->Count, 1, "still depends only on the CEO approval");
is ($t->ReferredToBy->Count,2, "referred to by the two tickets");

is_deeply([ $t->Status, $dependson_cfo->Status, $dependson_ceo->Status ],
          [ 'new', 'resolved', 'open'], 'ticket state after cfo approval');
