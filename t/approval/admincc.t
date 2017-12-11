
use strict;
use warnings;
use Test::More;

use RT;
use RT::Test tests => "no_declare";
use RT::Test::Email;

RT->Config->Set( LogToSTDERR => 'debug' );
RT->Config->Set( UseTransactionBatch => 1 );
my ($baseurl, $m) = RT::Test->started_ok;

my $q = RT::Queue->new($RT::SystemUser);
$q->Load('___Approvals');
$q->SetDisabled(0);

my %users;
# minion is the requestor, cto is the approval owner, coo and ceo are approval
# adminccs
for my $user_name (qw(minion cto coo ceo )) {
    my $user = $users{$user_name} = RT::User->new($RT::SystemUser);
    $user->Create( Name => uc($user_name),
                   Privileged => 1,
                   EmailAddress => $user_name.'@company.com',
                   Password => 'password',
                   );
    my ($val, $msg);
    ($val, $msg) = $user->PrincipalObj->GrantRight(Object =>$q, Right => $_)
        for qw(ModifyTicket OwnTicket ShowTicket);
}

# XXX: we need to make the first approval ticket open so notification is sent.
my $approvals = 
'===Create-Ticket: for-CTO
Queue: ___Approvals
Type: approval
Owner: CTO
AdminCCs: COO, CEO
DependedOnBy: TOP
Subject: CTO Approval for PO: {$Tickets{"TOP"}->Id} - {$Tickets{"TOP"}->Subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the PO ticket {$Tickets{"TOP"}->Id}: {$Tickets{"TOP"}->Subject}
Blah
Blah
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
                Queue => $q->Id,
                Description => 'Create Approval Tickets');
ok ($sval, $smsg);
ok ($scrip->Id, "Created the scrip");
ok ($scrip->TemplateObj->Id, "Created the scrip template");
ok ($scrip->ConditionObj->Id, "Created the scrip condition");
ok ($scrip->ActionObj->Id, "Created the scrip action");

my $t = RT::Ticket->new($RT::SystemUser);
my ($tid, $ttrans, $tmsg);

mail_ok {
    ( $tid, $ttrans, $tmsg ) = $t->Create(
        Subject   => "PO for stationary",
        Owner     => "root",
        Requestor => 'minion',
        Queue     => $q->Id,
    );
} { from => qr/PO via RT/,
    to => 'minion@company.com',
    subject => qr/PO for stationary/,
    body => qr/automatically generated in response/
},{ from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/PO for stationary/,
},{ from => qr/RT System/,
    to => 'cto@company.com',
    bcc => qr/ceo.*coo|coo.*ceo/i,
    subject => qr/New Pending Approval: CTO Approval/,
    body => qr/pending your approval.*Your approval is requested.*Blah/s
}
;

ok ($tid,$tmsg);

is ($t->DependsOn->Count, 1, "depends on one ticket");
my $t_cto = RT::Ticket->new( $RT::SystemUser );
$t_cto->Load( $t->DependsOn->First->TargetObj->id );

is_deeply(
    [ $t->Status, $t_cto->Status ],
    [ 'new',      'open' ],
    'tickets in correct state'
);

mail_ok {
    my $cto = RT::CurrentUser->new;
    $cto->Load( $users{cto} );

    $t_cto->CurrentUser($cto);
    my $notes = MIME::Entity->build(
        Data => [ 'Resources exist to be consumed.' ]
    );
    RT::I18N::SetMIMEEntityToUTF8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $t_cto->Correspond( MIMEObj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $t_cto->SetStatus( Status => 'resolved' );
    ok($ok, "cto can approve - $msg");
    } 
{
    from => qr/CTO/,
    bcc => qr/ceo.*coo|coo.*ceo/i,
    body => qr/Resources exist to be consumed/,
},
{
    from => qr/RT System/,
    to => 'root@localhost',
    subject => qr/Ticket Approved:/,
},
{
    from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CTO.*notes: Resources exist to be consumed/s
},
{
    from => qr/CTO/,
    to => 'root@localhost',
    subject => qr/Ticket Approved:/,
    body => qr/The ticket has been approved, you may now start to act on it/,
};

is_deeply(
    [ $t->Status, $t_cto->Status ],
    [ 'new', 'resolved' ],
    'ticket state after coo approval'
);

for my $admin (qw/coo ceo/) {
    $t_cto->_Set(
        Field => 'Status',
        Value => 'open',
    );

    RT::Test->clean_caught_mails;

    mail_ok {
        my $user = RT::CurrentUser->new;
        $user->Load( $users{$admin} );

        $t_cto->CurrentUser($user);
        my $notes =
          MIME::Entity->build( Data => ['Resources exist to be consumed.'] );
        RT::I18N::SetMIMEEntityToUTF8($notes);   # convert text parts into utf-8

        my ( $notesval, $notesmsg ) = $t_cto->Correspond( MIMEObj => $notes );
        ok( $notesval, $notesmsg );

        my ( $ok, $msg ) = $t_cto->SetStatus( Status => 'resolved' );
        ok( $ok, "cto can approve - $msg" );
    }
    {
        from => qr/\U$admin/,
        bcc  => $admin eq 'coo' ? qr/ceo/i : qr/coo/,
        body => qr/Resources exist to be consumed/,
    },
      {
         from => qr/RT System/,
         to => 'root@localhost',
         subject => qr/Ticket Approved:/,
         body    => qr/approved by \U$admin\E.*notes: Resources exist to be consumed/s
      },
      {
        from    => qr/RT System/,
        to      => 'minion@company.com',
        subject => qr/Ticket Approved:/,
        body    => qr/approved by \U$admin\E.*notes: Resources exist to be consumed/s
      },
      {
        from    => qr/\U$admin/,
        to      => 'root@localhost',
        subject => qr/Ticket Approved:/,
        body =>
          qr/The ticket has been approved, you may now start to act on it/,
      };
}

# now we test the web
my $approval_link = $baseurl . '/Approvals/';

$t = RT::Ticket->new($RT::SystemUser);
( $tid, $ttrans, $tmsg ) = $t->Create(
    Subject   => "first approval",
    Owner     => "root",
    Requestor => 'minion',
    Queue     => $q->Id,
);
ok( $tid, $tmsg );

my $first_ticket = RT::Ticket->new( $RT::SystemUser );
$first_ticket->Load( $tid );
my $first_approval = $first_ticket->DependsOn->First->TargetObj;

$t = RT::Ticket->new($RT::SystemUser);
( $tid, $ttrans, $tmsg ) = $t->Create(
    Subject   => "second approval",
    Owner     => "root",
    Requestor => 'minion',
    Queue     => $q->Id,
);

my $second_ticket = RT::Ticket->new( $RT::SystemUser );
$second_ticket->Load( $tid );
my $second_approval = $second_ticket->DependsOn->First->TargetObj;


ok( $m->login( 'cto', 'password' ), 'logged in as coo' );

my $m_coo = RT::Test::Web->new;
ok( $m_coo->login( 'coo', 'password' ), 'logged in as coo' );

my $m_ceo = RT::Test::Web->new;
ok( $m_ceo->login( 'ceo', 'password' ), 'logged in as coo' );


$m->get_ok( $approval_link );
$m_coo->get_ok( $approval_link );
$m_ceo->get_ok( $approval_link );

$m->content_contains('first approval',  'cto: see both approvals' );
$m->content_contains('second approval', 'cto: see both approvals' );

$m_coo->content_contains('first approval',  'coo: see both approvals');
$m_coo->content_contains('second approval', 'coo: see both approvals');

$m_ceo->content_contains('first approval',  'ceo: see both approvals');
$m_ceo->content_contains('second approval', 'ceo: see both approvals');

# now let's approve the first one via cto
$m->submit_form(
    form_name   => 'Approvals',
    fields      => { 'Approval-' . $first_approval->id . '-Action' => 'approve', },
);

$m->content_lacks( 'first approval', 'cto: first approval is gone' );
$m->content_contains( 'second approval', 'cto: second approval is still here' );
$m_coo->get_ok( $approval_link );
$m_ceo->get_ok( $approval_link );
$m_coo->content_lacks( 'first approval', 'coo: first approval is gone' );
$m_coo->content_contains( 'second approval', 'coo: second approval is still here' );
$m_ceo->content_lacks( 'first approval', 'ceo: first approval is gone' );
$m_ceo->content_contains( 'second approval', 'ceo: second approval is still here' );

$m_coo->submit_form(
    form_name => 'Approvals',
    fields      => { 'Approval-' . $second_approval->id . '-Action' => 'approve', },
);

$m->get_ok( $approval_link );
$m_ceo->get_ok( $approval_link );

$m->content_lacks( 'second approval', 'cto: second approval is gone too' );
$m_coo->content_lacks( 'second approval', 'coo: second approval is gone too' );
$m_ceo->content_lacks( 'second approval', 'ceo: second approval is gone too' );

RT::Test->clean_caught_mails;

done_testing;
