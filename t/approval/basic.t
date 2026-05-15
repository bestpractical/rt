use strict;
use warnings;
use RT::Test tests => undef;

use RT::Test::Email;

my $q = RT::Queue->new(RT->SystemUser);
$q->Load('___Approvals');

my %users;
for my $user_name (qw(minion cfo ceo )) {
    my $user = $users{$user_name} = RT::User->new(RT->SystemUser);
    $user->Create( Name => uc($user_name),
                   Privileged => 1,
                   EmailAddress => $user_name.'@company.com');
    my ($val, $msg);
    ($val, $msg) = $user->PrincipalObj->GrantRight(Object =>$q, Right => $_)
        for qw(ModifyTicket OwnTicket ShowTicket);
}

# XXX: we need to make the first approval ticket open so notification is sent.
my $approvals = 
'===Create-Ticket: for-CFO
Queue: ___Approvals
Type: approval
Owner: CFO
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
Subject: PO approval request for {$Tickets{"TOP"}->Subject}
Refers-To: TOP
Depends-On: for-CFO
Depended-On-By: {$Tickets{"TOP"}->Id}
Content-Type: text/plain
Content: 
Your CFO approved PO ticket {$Tickets{"TOP"}->Id} for minion. you ok with that?
ENDOFCONTENT
';

my $apptemp = RT::Template->new(RT->SystemUser);
$apptemp->Create( Content => $approvals, Name => "PO Approvals", Queue => "0");

ok($apptemp->Id);

$q = RT::Queue->new(RT->SystemUser);
$q->Create(Name => 'PO');
ok ($q->Id, "Created PO queue");

my $scrip = RT::Scrip->new(RT->SystemUser);
my ($sval, $smsg) =$scrip->Create( ScripCondition => 'On Create',
                ScripAction => 'Create Tickets',
                Template => 'PO Approvals',
                Queue => $q->Id,
                Description => 'Create Approval Tickets');
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new(RT->SystemUser);
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
},{ from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/PO for stationary/,
}, { from => qr/RT System/,
    to => 'cfo@company.com',
    subject => qr/New Pending Approval: CFO Approval/,
    body => qr/pending your approval.*Your approval is requested.*Blah/s
};

ok ($tid,$tmsg);

is ($t->ReferredToBy->Count,2, "referred to by the two tickets");

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
    $cfo->Load( $users{cfo} );

    $dependson_cfo->CurrentUser($cfo);
    my $notes = MIME::Entity->build(
        Data => [ 'Resources exist to be consumed.' ]
    );
    RT::I18N::SetMIMEEntityToUTF8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $dependson_cfo->Correspond( MIMEObj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_cfo->SetStatus( Status => 'resolved' );
    ok($ok, "cfo can approve - $msg");

} { from => qr/RT System/,
    to => 'ceo@company.com',
    subject => qr/New Pending Approval: PO approval request for PO/,
    body => qr/pending your approval.*CFO approved.*ok with that\?/s
},{ from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/Ticket Approved:/,
},{ from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CFO.*notes: Resources exist to be consumed/s
};

is ($t->DependsOn->Count, 1, "still depends only on the CEO approval");
is ($t->ReferredToBy->Count,2, "referred to by the two tickets");

is_deeply([ $t->Status, $dependson_cfo->Status, $dependson_ceo->Status ],
          [ 'new', 'resolved', 'open'], 'ticket state after cfo approval');

mail_ok {
    my $ceo = RT::CurrentUser->new;
    $ceo->Load( $users{ceo} );

    $dependson_ceo->CurrentUser($ceo);
    my $notes = MIME::Entity->build(
        Data => [ 'And consumed they will be.' ]
    );
    RT::I18N::SetMIMEEntityToUTF8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $dependson_ceo->Correspond( MIMEObj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_ceo->SetStatus( Status => 'resolved' );
    ok($ok, "ceo can approve - $msg");

} { from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CEO.*Its Owner may now start to act on it.*notes: And consumed they will be/s,
},{ from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CEO.*Its Owner may now start to act on it.*notes: And consumed they will be/s,
},{ from => qr/CEO via RT/,
     to => 'root@localhost',
     subject => qr/Ticket Approved/,
     body => qr/The ticket has been approved, you may now start to act on it/,
};


is_deeply([ $t->Status, $dependson_cfo->Status, $dependson_ceo->Status ],
          [ 'new', 'resolved', 'resolved'], 'ticket state after ceo approval');

$dependson_cfo->_Set(
    Field => 'Status',
    Value => 'open');

$dependson_ceo->_Set(
    Field => 'Status',
    Value => 'new');

mail_ok {
    my $cfo = RT::CurrentUser->new;
    $cfo->Load( $users{cfo} );

    $dependson_cfo->CurrentUser($cfo);
    my $notes = MIME::Entity->build(
        Data => [ 'sorry, out of resources.' ]
    );
    RT::I18N::SetMIMEEntityToUTF8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $dependson_cfo->Correspond( MIMEObj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_cfo->SetStatus( Status => 'rejected' );
    ok($ok, "cfo can approve - $msg");

} { from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/Ticket Rejected: PO for stationary/,
    body => qr/rejected by CFO.*out of resources/s,
},{ from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Rejected: PO for stationary/,
    body => qr/rejected by CFO.*out of resources/s,
};

$t->Load($t->id);$dependson_ceo->Load($dependson_ceo->id);
is_deeply([ $t->Status, $dependson_cfo->Status, $dependson_ceo->Status ],
          [ 'rejected', 'rejected', 'deleted'], 'ticket state after cfo rejection');

diag "Test ShowEmailRecord link URL in dependent ticket history on Approvals/Display.html";
{
    # Create another PO ticket — the existing scrip fires and creates a fresh,
    # non-deleted approval ticket that has the PO ticket as a type=ticket dependent.
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($tid) = $ticket->Create(
        Queue     => $q->Id,
        Subject   => 'Ticket needing approval',
        Requestor => 'requestor@example.com',
    );
    ok( $tid, "Created ticket id=$tid" );

    # The PO ticket depends directly on the CEO approval ticket
    my $approval = $ticket->DependsOn->First->TargetObj;
    ok( $approval && $approval->Id, "Found approval ticket id=" . ( $approval ? $approval->Id : 'n/a' ) );

    # Verify the original ticket has EmailRecord transactions
    # (created when RT sends outgoing notifications)
    my $email_txns = $ticket->Transactions;
    $email_txns->Limit( FIELD => 'Type', VALUE => 'EmailRecord' );
    ok( $email_txns->Count, "Original ticket has EmailRecord transactions" );

    # Discard outgoing notification emails generated by the Create above
    # so RT::Test::Email's END block doesn't see uncaught mail
    RT::Test->clean_caught_mails;

    # Test via Mechanize — start web server
    my ( $baseurl, $m ) = RT::Test->started_ok;
    ok $m->login, 'logged in as root';

    # Navigate to the approval ticket's display page.
    # Pass ShowHistory=always so history renders inline — Mechanize does not run JavaScript.
    $m->get_ok( "$baseurl/Approvals/Display.html?id=" . $approval->Id . "&ShowHistory=always" );

    # The original ticket (type=ticket) is shown as a dependent of the approval ticket.
    # Its history contains EmailRecord transactions. The "show email contents" link
    # must use an absolute /Ticket/ path. Without the fix, PathPrefix defaults to ''
    # and the HTML contains relative hrefs like href="ShowEmailRecord.html?..." which
    # the browser resolves against the current /Approvals/ page — a broken path.
    $m->content_contains(
        '/Ticket/ShowEmailRecord.html',
        'ShowEmailRecord link in dependent ticket history uses /Ticket/ path'
    );
    $m->content_lacks(
        '"ShowEmailRecord.html',
        'ShowEmailRecord link in dependent ticket history is not a relative path'
    );
    $m->content_contains(
        '/Ticket/Attachment/',
        'Attachment links in dependent ticket history use /Ticket/ path'
    );
    $m->content_lacks(
        '"Attachment/',
        'Attachment links in dependent ticket history are not relative paths'
    );
}

done_testing;
