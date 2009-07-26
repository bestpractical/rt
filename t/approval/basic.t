
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Email::Abstract; require Test::Email; 1 }
        or plan skip_all => 'require Email::Abstract and Test::Email';
}

plan tests => 32;

use RT::Test;
use RT::Test::Email;

RT->config->set( use_transaction_batch => 1 );

my $q = RT::Model::Queue->new( current_user => RT->system_user );
$q->load('___Approvals');
$q->set_disabled(0);

my %users;
for my $user_name (qw(minion cfo ceo )) {
    my $user = $users{$user_name} = RT::Model::User->new( current_user => RT->system_user );
    $user->create( name => uc($user_name),
                   privileged => 1,
                   email => $user_name.'@company.com');
    my ($val, $msg);
    ($val, $msg) = $user->principal->grant_right(object =>$q, right => $_)
        for qw(ModifyTicket OwnTicket ShowTicket);
}

# XXX: we need to make the first approval ticket open so notification is sent.
my $approvals = 
'===Create-Ticket: for-CFO
Queue: ___Approvals
Type: approval
Owner: CFO
Refers-To: TOP
Subject: CFO Approval for PO: {$Tickets{"TOP"}->id} - {$Tickets{"TOP"}->subject}
Due: {time + 86400}
Content-Type: text/plain
Content: Your approval is requested for the PO ticket {$Tickets{"TOP"}->id}: {$Tickets{"TOP"}->subject}
Blah
Blah
ENDOFCONTENT
===Create-Ticket: for-CEO
Queue: ___Approvals
Type: approval
Owner: CEO
Subject: PO approval request for {$Tickets{"TOP"}->subject}
Refers-To: TOP
Depends-On: for-CFO
Depended-On-By: {$Tickets{"TOP"}->id}
Content-Type: text/plain
Content: 
Your CFO approved PO ticket {$Tickets{"TOP"}->id} for minion. you ok with that?
ENDOFCONTENT
';

my $apptemp = RT::Model::Template->new(current_user => RT->system_user);
$apptemp->create( content => $approvals, name => "PO Approvals", queue => "0");

ok($apptemp->id);

$q = RT::Model::Queue->new(current_user => RT->system_user);
$q->create(name => 'PO');
ok ($q->id, "Created PO queue");

my $rule = RT::Lorzy->create_scripish(
    'On Create',
    'Create Tickets',
    'PO Approvals',
    'Create approval tickets',
    $q->id,
);
diag $rule->condition_code;
my $t = RT::Model::Ticket->new(current_user => RT->system_user);
my ($tid, $ttrans, $tmsg);

mail_ok {
    ($tid, $ttrans, $tmsg) =
        $t->create(subject => "PO for stationary",
                   owner => "root", requestor => $users{minion}->email,
                   queue => $q->id);
} { from => qr/PO via RT/,
    to => 'minion@company.com',
    subject => qr/PO for stationary/,
    body => qr/automatically generated in response/
},{ from => qr/RT System/,
    to => 'cfo@company.com',
    subject => qr/New Pending Approval: CFO Approval/,
    body => qr/pending your approval.*Your approval is requested.*Blah/s
};

ok ($tid,$tmsg);

is ($t->referred_to_by->count,2, "referred to by the two tickets");

my $deps = $t->depends_on;
is ($deps->count, 1, "The ticket we created depends on one other ticket");
my $dependson_ceo= $deps->first->target_obj;
ok ($dependson_ceo->id, "It depends on a real ticket");
like($dependson_ceo->subject, qr/PO approval request.*stationary/);

$deps = $dependson_ceo->depends_on;
is ($deps->count, 1, "The ticket we created depends on one other ticket");
my $dependson_cfo = $deps->first->target_obj;
ok ($dependson_cfo->id, "It depends on a real ticket");

like($dependson_cfo->subject, qr/CFO Approval for PO.*stationary/);

is_deeply([ $t->status, $dependson_cfo->status, $dependson_ceo->status ],
          [ 'new', 'open', 'new'], 'tickets in correct state');

mail_ok {
    my $cfo = RT::CurrentUser->new(id => $users{cfo}->id);

    $dependson_cfo->current_user($cfo);
    my $notes = MIME::Entity->build(
        Data => [ 'Resources exist to be consumed.' ]
    );
    RT::I18N::set_mime_entity_to_utf8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $dependson_cfo->correspond( mime_obj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_cfo->set_status( status => 'resolved' );
    ok($ok, "cfo can approve - $msg");

} { from => qr/RT System/,
    to => 'ceo@company.com',
    subject => qr/New Pending Approval: PO approval request for PO/,
    body => qr/pending your approval.*CFO approved.*ok with that\?/s
},{ from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CFO.*notes: Resources exist to be consumed/s
};

is ($t->depends_on->count, 1, "still depends only on the CEO approval");
is ($t->referred_to_by->count,2, "referred to by the two tickets");

is_deeply([ $t->status, $dependson_cfo->status, $dependson_ceo->status ],
          [ 'new', 'resolved', 'open'], 'ticket state after cfo approval');

mail_ok {
    my $ceo = RT::CurrentUser->new(id => $users{ceo}->id);

    $dependson_ceo->current_user($ceo);
    my $notes = MIME::Entity->build(
        Data => [ 'And consumed they will be.' ]
    );
    RT::I18N::set_mime_entity_to_utf8($notes); # convert text parts into utf-8

    my ( $notesval, $notesmsg ) = $dependson_ceo->correspond( mime_obj => $notes );
    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_ceo->set_status( status => 'resolved' );
    ok($ok, "ceo can approve - $msg");

} { from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Approved:/,
    body => qr/approved by CEO.*Its Owner may now start to act on it.*notes: And consumed they will be/s,
}, { from => qr'CEO via RT',
     to => 'root@localhost',
     subject => qr/Ticket Approved/,
     body => qr/The ticket has been approved, you may now start to act on it/,
};


is_deeply([ $t->status, $dependson_cfo->status, $dependson_ceo->status ],
          [ 'new', 'resolved', 'resolved'], 'ticket state after ceo approval');

$dependson_cfo->_set(
    column => 'status',
    value => 'open');

$dependson_ceo->_set(
    column => 'status',
    value => 'new');

mail_ok {
    my $cfo = RT::CurrentUser->new(id => $users{cfo}->id);

    $dependson_cfo->current_user($cfo);
    my $notes = MIME::Entity->build(
        Data => [ 'sorry, out of resources.' ]
    );
    RT::I18N::set_mime_entity_to_utf8($notes); # convert text parts into utf-8

#    my ( $notesval, $notesmsg ) = $dependson_cfo->Correspond( mime_obj => $notes );
#    ok($notesval, $notesmsg);

    my ($ok, $msg) = $dependson_cfo->set_status( status => 'rejected' );
    ok($ok, "cfo can approve - $msg");

} { from => qr/RT System/,
    to => 'minion@company.com',
    subject => qr/Ticket Rejected: PO for stationary/,
    body => qr/rejected by CFO/
};

$t->load($t->id);$dependson_ceo->load($dependson_ceo->id);
is_deeply([ $t->status, $dependson_cfo->status, $dependson_ceo->status ],
          [ 'rejected', 'rejected', 'deleted'], 'ticket state after cfo rejection');
