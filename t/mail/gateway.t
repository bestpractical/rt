use strict;
use warnings;


use RT::Test config => 'Set( @MailPlugins, "Action::Take", "Action::Resolve");', tests => undef, actual_server => 1;
my ($baseurl, $m) = RT::Test->started_ok;

use RT::Tickets;

use MIME::Entity;
use Digest::MD5 qw(md5_base64);
use LWP::UserAgent;

# TODO: --extension queue

my $url = $m->rt_base_url;

diag "Make sure that when we call the mailgate without URL, it fails";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation

Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, url => undef);
    is ($status >> 8, 1, "The mail gateway exited with a failure");
    ok (!$id, "No ticket id") or diag "by mistake ticket #$id";
    $m->no_warnings_ok;
}

diag "Make sure that when we call the mailgate with wrong URL, it tempfails";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation

Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, url => 'http://this.test.for.non-connection.is.expected.to.generate.an.error');
    is ($status >> 8, 75, "The mail gateway exited with a failure");
    ok (!$id, "No ticket id");
    $m->no_warnings_ok;
}

my $everyone_group;
diag "revoke rights tests depend on";
{
    $everyone_group = RT::Group->new( RT->SystemUser );
    $everyone_group->LoadSystemInternalGroup( 'Everyone' );
    ok ($everyone_group->Id, "Found group 'everyone'");

    foreach( qw(CreateTicket ReplyToTicket CommentOnTicket) ) {
        $everyone_group->PrincipalObj->RevokeRight(Right => $_);
    }
}

diag "Test new ticket creation by root who is privileged and superuser";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation

Blah!
Foob!
EOF

    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    is ($tick->Id, $id, "correct ticket id");
    is ($tick->Subject , 'This is a test of new ticket creation', "Created the ticket");
    $m->no_warnings_ok;
}

diag "Test the 'X-RT-Mail-Extension' field in the header of a ticket";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of the X-RT-Mail-Extension field
Blah!
Foob!
EOF
    local $ENV{'EXTENSION'} = "bad value with\nnewlines\n";
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket #$id");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    is ($tick->Id, $id, "correct ticket id");
    is ($tick->Subject, 'This is a test of the X-RT-Mail-Extension field', "Created the ticket");

    my $transactions = $tick->Transactions;
    $transactions->OrderByCols({ FIELD => 'id', ORDER => 'DESC' });
    $transactions->Limit( FIELD => 'Type', OPERATOR => '!=', VALUE => 'EmailRecord');
    my $txn = $transactions->First;
    isa_ok ($txn, 'RT::Transaction');
    is ($txn->Type, 'Create', "correct type");

    my $attachment = $txn->Attachments->First;
    isa_ok ($attachment, 'RT::Attachment');
    # XXX: We eat all newlines in header, that's not what RFC's suggesting
    is (
        $attachment->GetHeader('X-RT-Mail-Extension'),
        "bad value with newlines",
        'header is in place, without trailing newline char'
    );
    $m->no_warnings_ok;
}

diag "Make sure that not standard --extension is passed";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation

Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, extension => 'some-extension-arg' );
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket #$id");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    is ($tick->Id, $id, "correct ticket id");

    my $transactions = $tick->Transactions;
    $transactions->OrderByCols({ FIELD => 'id', ORDER => 'DESC' });
    $transactions->Limit( FIELD => 'Type', OPERATOR => '!=', VALUE => 'EmailRecord');
    my $txn = $transactions->First;
    isa_ok ($txn, 'RT::Transaction');
    is ($txn->Type, 'Create', "correct type");

    my $attachment = $txn->Attachments->First;
    isa_ok ($attachment, 'RT::Attachment');
    is (
        $attachment->GetHeader('X-RT-Mail-Extension'),
        'some-extension-arg',
        'header is in place'
    );
    $m->no_warnings_ok;
}

diag "Test new ticket creation without --action argument";
{
    my $text = <<EOF;
From: root\@localhost
To: rt\@$RT::rtname
Subject: using mailgate without --action arg

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, extension => 'some-extension-arg' );
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "Created ticket #$id");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    is ($tick->Id, $id, "correct ticket id");
    is ($tick->Subject, 'using mailgate without --action arg', "using mailgate without --action arg");
    $m->no_warnings_ok;
}

diag "This is a test of new ticket creation as an unknown user";
{
    my $text = <<EOF;
From: doesnotexist\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok (!$id, "no ticket created");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ".$tick->Id);
    isnt ($tick->Subject , 'This is a test of new ticket creation as an unknown user', "failed to create the new ticket from an unprivileged account");

    my $u = RT::User->new(RT->SystemUser);
    $u->Load("doesnotexist\@@{[RT->Config->Get('rtname')]}");
    ok( $u->Id, "user was created by failed ticket submission");

    $m->next_warning_like(qr/Failed attempt to create a ticket by email, from doesnotexist\@\S+.*grant.*CreateTicket right/s);
    $m->next_warning_like(qr/Permission Denied: doesnotexist\@\S+ has no right to create tickets in queue General/);
    $m->no_leftover_warnings_ok;
}

diag "grant everybody with CreateTicket right";
{
    ok( RT::Test->set_rights(
        { Principal => $everyone_group->PrincipalObj,
          Right => [qw(CreateTicket)],
        },
    ), "Granted everybody the right to create tickets");
}

my $ticket_id;
diag "now everybody can create tickets. can a random unkown user create tickets?";
{
    my $text = <<EOF;
From: doesnotexist\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "ticket created");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ".$tick->Id);
    is ($tick->Id, $id, "correct ticket id");
    is ($tick->Subject , 'This is a test of new ticket creation as an unknown user', "failed to create the new ticket from an unprivileged account");

    my $u = RT::User->new( RT->SystemUser );
    $u->Load( "doesnotexist\@@{[RT->Config->Get('rtname')]}" );
    ok ($u->Id, "user does exist and was created by ticket submission");
    $ticket_id = $id;
    $m->no_warnings_ok;
}

diag "can another random reply to a ticket without being granted privs? answer should be no.";
{
    my $text = <<EOF;
From: doesnotexist-2\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: [@{[RT->Config->Get('rtname')]} #$ticket_id] This is a test of a reply as an unknown user

Blah!  (Should not work.)
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok (!$id, "no way to reply to the ticket");

    my $u = RT::User->new(RT->SystemUser);
    $u->Load('doesnotexist-2@'.RT->Config->Get('rtname'));
    ok( $u->Id, "user was created by ticket correspondence submission");
    $m->next_warning_like(qr/Failed attempt to reply to a ticket by email, from doesnotexist-2\@\S+.*grant.*ReplyToTicket right/s);
    $m->next_warning_like(qr/Permission Denied: doesnotexist-2\@\S+ has no right to reply to ticket $ticket_id in queue General/);
    $m->no_leftover_warnings_ok;
}

diag "grant everyone 'ReplyToTicket' right";
{
    ok( RT::Test->set_rights(
        { Principal => $everyone_group->PrincipalObj,
          Right => [qw(CreateTicket ReplyToTicket)],
        },
    ), "Granted everybody the right to reply to tickets" );
}

diag "can another random reply to a ticket after being granted privs? answer should be yes";
{
    my $text = <<EOF;
From: doesnotexist-2\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: [@{[RT->Config->Get('rtname')]} #$ticket_id] This is a test of a reply as an unknown user

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticket_id, "replied to the ticket");

    my $u = RT::User->new(RT->SystemUser);
    $u->Load('doesnotexist-2@'.RT->Config->Get('rtname'));
    ok ($u->Id, "user exists and was created by ticket correspondence submission");
    $m->no_warnings_ok;
}

diag "add a reply to the ticket using '--extension ticket' feature";
{
    my $text = <<EOF;
From: doesnotexist-2\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of a reply as an unknown user

Blah!
Foob!
EOF
    local $ENV{'EXTENSION'} = $ticket_id;
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, extension => 'ticket');
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticket_id, "replied to the ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ".$tick->Id);
    is ($tick->Id, $id, "correct ticket id");

    my $transactions = $tick->Transactions;
    $transactions->OrderByCols({ FIELD => 'id', ORDER => 'DESC' });
    $transactions->Limit( FIELD => 'Type', OPERATOR => '!=', VALUE => 'EmailRecord');
    my $txn = $transactions->First;
    isa_ok ($txn, 'RT::Transaction');
    is ($txn->Type, 'Correspond', "correct type");

    my $attachment = $txn->Attachments->First;
    isa_ok ($attachment, 'RT::Attachment');
    is ($attachment->GetHeader('X-RT-Mail-Extension'), $id, 'header is in place');
    $m->no_warnings_ok;
}

diag "can another random comment on a ticket without being granted privs? answer should be no";
{
    my $text = <<EOF;
From: doesnotexist-3\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: [@{[RT->Config->Get('rtname')]} #$ticket_id] This is a test of a comment as an unknown user

Blah!  (Should not work.)
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, action => 'comment');
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok (!$id, "no way to comment on the ticket");

    my $u = RT::User->new(RT->SystemUser);
    $u->Load('doesnotexist-3@'.RT->Config->Get('rtname'));
    ok( $u->Id, "user was created by ticket comment submission");
    $m->next_warning_like(qr/Permission Denied: doesnotexist-3\@\S+ has no right to comment on ticket $ticket_id in queue General/);
    $m->no_leftover_warnings_ok;
}


diag "grant everyone 'CommentOnTicket' right";
{
    ok( RT::Test->set_rights(
        { Principal => $everyone_group->PrincipalObj,
          Right => [qw(CreateTicket ReplyToTicket CommentOnTicket)],
        },
    ), "Granted everybody the right to comment on tickets");
}

diag "can another random reply to a ticket after being granted privs? answer should be yes";
{
    my $text = <<EOF;
From: doesnotexist-3\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: [@{[RT->Config->Get('rtname')]} #$ticket_id] This is a test of a comment as an unknown user

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, action => 'comment');
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticket_id, "replied to the ticket");

    my $u = RT::User->new(RT->SystemUser);
    $u->Load('doesnotexist-3@'.RT->Config->Get('rtname'));
    ok ($u->Id, " user exists and was created by ticket comment submission");
    $m->no_warnings_ok;
}

diag "add comment to the ticket using '--extension action' feature";
{
    my $text = <<EOF;
From: doesnotexist-3\@@{[RT->Config->Get('rtname')]}
To: rt\@@{[RT->Config->Get('rtname')]}
Subject: [@{[RT->Config->Get('rtname')]} #$ticket_id] This is a test of a comment via '--extension action'

Blah!
Foob!
EOF
    local $ENV{'EXTENSION'} = 'comment';
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text, extension => 'action');
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($id, $ticket_id, "added comment to the ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ".$tick->Id);
    is ($tick->Id, $id, "correct ticket id");

    my $transactions = $tick->Transactions;
    $transactions->OrderByCols({ FIELD => 'id', ORDER => 'DESC' });
    $transactions->Limit(
        FIELD => 'Type',
        OPERATOR => 'NOT ENDSWITH',
        VALUE => 'EmailRecord',
        ENTRYAGGREGATOR => 'AND',
    );
    my $txn = $transactions->First;
    isa_ok ($txn, 'RT::Transaction');
    is ($txn->Type, 'Comment', "correct type");

    my $attachment = $txn->Attachments->First;
    isa_ok ($attachment, 'RT::Attachment');
    is ($attachment->GetHeader('X-RT-Mail-Extension'), 'comment', 'header is in place');
    $m->no_warnings_ok;
}

diag "Testing preservation of binary attachments";
{
    # Get a binary blob (Best Practical logo) 
    my $LOGO_FILE = $RT::StaticPath .'/images/bpslogo.png';

    # Create a mime entity with an attachment
    my $entity = MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'binary attachment test',
        Data    => ['This is a test of a binary attachment'],
    );

    $entity->attach(
        Path     => $LOGO_FILE,
        Type     => 'image/png',
        Encoding => 'base64',
    );
    # Create a ticket with a binary attachment
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($entity);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "created ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ".$tick->Id);
    is ($tick->Id, $id, "correct ticket id");
    is ($tick->Subject , 'binary attachment test', "Created the ticket - ".$tick->Id);

    my $file = `cat $LOGO_FILE`;
    ok ($file, "Read in the logo image");
    diag "for the raw file the md5 hex is ". Digest::MD5::md5_hex($file);

    # Verify that the binary attachment is valid in the database
    my $attachments = RT::Attachments->new(RT->SystemUser);
    $attachments->Limit(FIELD => 'ContentType', VALUE => 'image/png');
    my $txn_alias = $attachments->Join(
        ALIAS1 => 'main',
        FIELD1 => 'TransactionId',
        TABLE2 => 'Transactions',
        FIELD2 => 'id',
    );
    $attachments->Limit( ALIAS => $txn_alias, FIELD => 'ObjectType', VALUE => 'RT::Ticket' );
    $attachments->Limit( ALIAS => $txn_alias, FIELD => 'ObjectId', VALUE => $id );
    is ($attachments->Count, 1, 'Found only one png attached to the ticket');
    my $attachment = $attachments->First;
    ok ($attachment->Id, 'loaded attachment object');
    my $acontent = $attachment->Content;

    diag "coming from the database, md5 hex is ".Digest::MD5::md5_hex($acontent);
    is ($acontent, $file, 'The attachment isn\'t screwed up in the database.');

    # Grab the binary attachment via the web ui
    my $ua = new LWP::UserAgent;
    my $full_url = "$url/Ticket/Attachment/". $attachment->TransactionId
        ."/". $attachment->id. "/bpslogo.png?&user=root&pass=password";
    my $r = $ua->get( $full_url );

    # Verify that the downloaded attachment is the same as what we uploaded.
    is ($file, $r->content, 'The attachment isn\'t screwed up in download');

    $m->no_warnings_ok;
}

diag "Simple I18N testing";
{
    my $text = <<EOF;
From: root\@localhost
To: rtemail\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of I18N ticket creation
Content-Type: text/plain; charset="utf-8"

2 accented lines
\303\242\303\252\303\256\303\264\303\273
\303\241\303\251\303\255\303\263\303\272
bye
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "created ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ". $tick->Id);
    is ($tick->Id, $id, "correct ticket");
    is ($tick->Subject , 'This is a test of I18N ticket creation', "Created the ticket - ". $tick->Subject);

    my $unistring = Encode::decode("UTF-8","\303\241\303\251\303\255\303\263\303\272");
    is (
        $tick->Transactions->First->Content,
        $tick->Transactions->First->Attachments->First->Content,
        "Content is ". $tick->Transactions->First->Attachments->First->Content
    );
    ok (
        $tick->Transactions->First->Content =~ /$unistring/i,
        $tick->Id." appears to be unicode ". $tick->Transactions->First->Attachments->First->Id
    );

    $m->no_warnings_ok;
}

diag "supposedly I18N fails on the second message sent in.";
{
    my $text = <<EOF;
From: root\@localhost
To: rtemail\@@{[RT->Config->Get('rtname')]}
Subject: This is a test of I18N ticket creation
Content-Type: text/plain; charset="utf-8"

2 accented lines
\303\242\303\252\303\256\303\264\303\273
\303\241\303\251\303\255\303\263\303\272
bye
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "created ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ". $tick->Id);
    is ($tick->Id, $id, "correct ticket");
    is ($tick->Subject , 'This is a test of I18N ticket creation', "Created the ticket");

    my $unistring = Encode::decode("UTF-8","\303\241\303\251\303\255\303\263\303\272");

    ok (
        $tick->Transactions->First->Content =~ $unistring,
        "It appears to be unicode - ". $tick->Transactions->First->Content
    );

    $m->no_warnings_ok;
}

diag "make sure we check that UTF-8 is really UTF-8";
{
    my $text = <<EOF;
From: root\@localhost
To: rtemail\@@{[RT->Config->Get('rtname')]}
Subject: This is test wrong utf-8 chars
Content-Type: text/plain; charset="utf-8"

utf-8: informaci\303\263n confidencial
latin1: informaci\363n confidencial

bye
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "created ticket");

    my $tick = RT::Test->last_ticket;
    is ($tick->Id, $id, "correct ticket");

    my $content = Encode::encode("UTF-8",$tick->Transactions->First->Content);

    like $content, qr{informaci\303\263n confidencial};
    like $content, qr{informaci\357\277\275n confidencial};

    $m->no_warnings_ok;
}

diag "check that mailgate doesn't suffer from empty Reply-To:";
{
    my $text = <<EOF;
From: root\@localhost
Reply-To: 
To: rtemail\@@{[RT->Config->Get('rtname')]}
Subject: test
Content-Type: text/plain; charset="utf-8"

test
EOF
    my ($status, $id) = RT::Test->send_via_mailgate_and_http($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "created ticket");

    my $tick = RT::Test->last_ticket;
    isa_ok ($tick, 'RT::Ticket');
    ok ($tick->Id, "found ticket ". $tick->Id);
    is ($tick->Id, $id, "correct ticket");

    like $tick->RequestorAddresses, qr/root\@localhost/, 'correct requestor';

    $m->no_warnings_ok;
}


my ($val,$msg) = $everyone_group->PrincipalObj->RevokeRight(Right => 'CreateTicket');
ok ($val, $msg);

# create new queue to be shure we don't mess with rights
use RT::Queue;
my $queue = RT::Queue->new(RT->SystemUser);
my ($qid) = $queue->Create( Name => 'ext-mailgate');
ok( $qid, 'queue created for ext-mailgate tests' );


# create ticket that is owned by nobody
use RT::Ticket;
my $tick = RT::Ticket->new(RT->SystemUser);
my ($id) = $tick->Create( Queue => 'ext-mailgate', Subject => 'test');
ok( $id, 'new ticket created' );
is( $tick->Owner, RT->Nobody->Id, 'owner of the new ticket is nobody' );

$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action take"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: root\@localhost
Subject: [@{[RT->Config->Get('rtname')]} \#$id] test

EOF
close (MAIL);
is ($? >> 8, 0, "The mail gateway exited normally");

DBIx::SearchBuilder::Record::Cachable->FlushCache;

$tick = RT::Ticket->new(RT->SystemUser);
$tick->Load( $id );
is( $tick->Id, $id, 'load correct ticket');
is( $tick->OwnerObj->EmailAddress, 'root@localhost', 'successfuly take ticket via email');

# check that there is no text transactions writen (create + 2 for take)
is( $tick->Transactions->Count, 3, 'no superfluous transactions');

my $status;
($status, $msg) = $tick->SetOwner( RT->Nobody->Id, 'Force' );
ok( $status, 'successfuly changed owner: '. ($msg||'') );
is( $tick->Owner, RT->Nobody->Id, 'set owner back to nobody');

$m->no_warnings_ok;


$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action take-correspond"), "Opened the mailgate - $@");
print MAIL <<EOF;
From: root\@localhost
Subject: [@{[RT->Config->Get('rtname')]} \#$id] correspondence

test
EOF
close (MAIL);
is ($? >> 8, 0, "The mail gateway exited normally");

DBIx::SearchBuilder::Record::Cachable->FlushCache;

$tick = RT::Ticket->new(RT->SystemUser);
$tick->Load( $id );
is( $tick->Id, $id, "load correct ticket #$id");
is( $tick->OwnerObj->EmailAddress, 'root@localhost', 'successfuly take ticket via email');
my $txns = $tick->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Correspond');
$txns->OrderBy( FIELD => 'id', ORDER => 'DESC' );
# +2 from owner to nobody, +1 because of auto open, +2 from take, +1 from correspond
is( $tick->Transactions->Count, 9, 'no superfluous transactions');
is( $txns->First->Subject, "[$RT::rtname \#$id] correspondence", 'successfuly add correspond within take via email' );

$m->no_warnings_ok;


$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action resolve"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: root\@localhost
Subject: [@{[RT->Config->Get('rtname')]} \#$id] test

EOF
close (MAIL);
is ($? >> 8, 0, "The mail gateway exited normally");

DBIx::SearchBuilder::Record::Cachable->FlushCache;

$tick = RT::Ticket->new(RT->SystemUser);
$tick->Load( $id );
is( $tick->Id, $id, 'load correct ticket');
is( $tick->Status, 'resolved', 'successfuly resolved ticket via email');
# +1 from resolve
is( $tick->Transactions->Count, 10, 'no superfluous transactions');

use RT::User;
my $user = RT::User->new( RT->SystemUser );
my ($uid) = $user->Create( Name => 'ext-mailgate',
                           EmailAddress => 'ext-mailgate@localhost',
                           Privileged => 1,
                           Password => 'qwe123',
                         );
ok( $uid, 'user created for ext-mailgate tests' );
ok( !$user->HasRight( Right => 'OwnTicket', Object => $queue ), "User can't own ticket" );

$tick = RT::Ticket->new(RT->SystemUser);
($id) = $tick->Create( Queue => $qid, Subject => 'test' );
ok( $id, 'create new ticket' );

my $rtname = RT->Config->Get('rtname');

$m->no_warnings_ok;

$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action take"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: ext-mailgate\@localhost
Subject: [$rtname \#$id] test

EOF
close (MAIL);
is ( $? >> 8, 0, "mailgate exited normally" );
DBIx::SearchBuilder::Record::Cachable->FlushCache;

cmp_ok( $tick->Owner, '!=', $user->id, "we didn't change owner" );

($status, $msg) = $user->PrincipalObj->GrantRight( Object => $queue, Right => 'ReplyToTicket' );
ok( $status, "successfuly granted right: $msg" );
my $ace_id = $status;
ok( $user->HasRight( Right => 'ReplyToTicket', Object => $tick ), "User can reply to ticket" );

$m->next_warning_like(qr/ext-mailgate\@localhost has no right to own ticket $id in queue ext-mailgate/);
$m->no_leftover_warnings_ok;

$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action correspond-take"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: ext-mailgate\@localhost
Subject: [$rtname \#$id] test

correspond-take
EOF
close (MAIL);
is ( $? >> 8, 0, "mailgate exited normally" );
DBIx::SearchBuilder::Record::Cachable->FlushCache;

cmp_ok( $tick->Owner, '!=', $user->id, "we didn't change owner" );
is( $tick->Transactions->Count, 3, "one transactions added" );

$m->next_warning_like(qr/That user may not own tickets in that queue/);
$m->no_leftover_warnings_ok;

$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action take-correspond"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: ext-mailgate\@localhost
Subject: [$rtname \#$id] test

correspond-take
EOF
close (MAIL);
is ( $? >> 8, 0, "mailgate exited normally" );
DBIx::SearchBuilder::Record::Cachable->FlushCache;

cmp_ok( $tick->Owner, '!=', $user->id, "we didn't change owner" );
is( $tick->Transactions->Count, 3, "no transactions added, user can't take ticket first" );

$m->next_warning_like(qr/ext-mailgate\@localhost has no right to own ticket $id in queue ext-mailgate/);
$m->no_leftover_warnings_ok;

# revoke ReplyToTicket right
use RT::ACE;
my $ace = RT::ACE->new(RT->SystemUser);
$ace->Load( $ace_id );
$ace->Delete;
my $acl = RT::ACL->new(RT->SystemUser);
$acl->Limit( FIELD => 'RightName', VALUE => 'ReplyToTicket' );
$acl->LimitToObject( $RT::System );
while( my $ace = $acl->Next ) {
    $ace->Delete;
}

ok( !$user->HasRight( Right => 'ReplyToTicket', Object => $tick ), "User can't reply to ticket any more" );


my $group = $queue->RoleGroup( 'Owner' );
ok( $group->Id, "load queue owners role group" );
$ace = RT::ACE->new( RT->SystemUser );
($ace_id, $msg) = $group->PrincipalObj->GrantRight( Right => 'ReplyToTicket', Object => $queue );
ok( $ace_id, "Granted queue owners role group with ReplyToTicket right" );

($status, $msg) = $user->PrincipalObj->GrantRight( Object => $queue, Right => 'OwnTicket' );
ok( $status, "successfuly granted right: $msg" );
($status, $msg) = $user->PrincipalObj->GrantRight( Object => $queue, Right => 'TakeTicket' );
ok( $status, "successfuly granted right: $msg" );

$! = 0;
ok(open(MAIL, '|-', "$RT::BinPath/rt-mailgate --url $url --queue ext-mailgate --action take-correspond"), "Opened the mailgate - $!");
print MAIL <<EOF;
From: ext-mailgate\@localhost
Subject: [$rtname \#$id] test

take-correspond with reply right granted to owner role
EOF
close (MAIL);
is ( $? >> 8, 0, "mailgate exited normally" );
DBIx::SearchBuilder::Record::Cachable->FlushCache;

$tick->Load( $id );
is( $tick->Owner, $user->id, "we changed owner" );
ok( $user->HasRight( Right => 'ReplyToTicket', Object => $tick ), "owner can reply to ticket" );
# +2 from take, +1 from correspond
is( $tick->Transactions->Count, 6, "transactions added" );

done_testing;
