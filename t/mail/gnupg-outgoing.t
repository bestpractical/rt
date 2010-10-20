#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'GnuPG required.'
    unless eval { require GnuPG::Interface; 1 };
plan skip_all => 'gpg executable is required.'
    unless RT::Test->find_executable('gpg');
plan tests => 390;

use RT::Test::GnuPG;
use RT::Action::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

use_ok('RT::Crypt::GnuPG');

RT->Config->Set( GnuPG =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
);

RT->Config->Set( GnuPGOptions =>
    homedir => scalar tempdir( CLEANUP => 1 ),
    passphrase => 'rt-test',
    'no-permission-warning' => undef,
    'trust-model' => 'always',
);
RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @variants = (
    {},
    { Sign => 1 },
    { Encrypt => 1 },
    { Sign => 1, Encrypt => 1 },
);

# collect emails
my %mail = (
    plain            => [],
    signed           => [],
    encrypted        => [],
    signed_encrypted => [],
);

# create a ticket for each combination
foreach my $queue_set ( @variants ) {
    set_queue_crypt_options( $queue, %$queue_set );
    foreach my $ticket_set ( @variants ) {
        create_a_ticket( $queue, \%mail, $m, %$ticket_set );
    }
}

my $tid;
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ($tid) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => 'rt-test@example.com',
    );
    ok $tid, 'ticket created';
}

# again for each combination add a reply message
foreach my $queue_set ( @variants ) {
    set_queue_crypt_options( $queue, %$queue_set );
    foreach my $ticket_set ( @variants ) {
        update_ticket( $tid, \%mail, $m, %$ticket_set );
    }
}


# ------------------------------------------------------------------------------
# now delete all keys from the keyring and put back secret/pub pair for rt-test@
# and only public key for rt-recipient@ so we can verify signatures and decrypt
# like we are on another side recieve emails
# ------------------------------------------------------------------------------

unlink $_ foreach glob( RT->Config->Get('GnuPGOptions')->{'homedir'} ."/*" );
RT::Test->import_gnupg_key('rt-recipient@example.com', 'public');
RT::Test->import_gnupg_key('rt-test@example.com');

$queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-test@example.com',
    CommentAddress    => 'rt-test@example.com',
);
ok $queue && $queue->id, 'changed props of the queue';

foreach my $mail ( map cleanup_headers($_), @{ $mail{'plain'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    ok !$msg->GetHeader('X-RT-Privacy'), "RT's outgoing mail has no crypto";
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
        "RT's outgoing mail looks not encrypted";
    ok !$msg->GetHeader('X-RT-Incoming-Signature'),
        "RT's outgoing mail looks not signed";

    like $msg->Content, qr/Some content/, "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'signed'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
        "RT's outgoing mail looks not encrypted";
    like $msg->GetHeader('X-RT-Incoming-Signature'),
        qr/<rt-recipient\@example.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->Content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'encrypted'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
        "RT's outgoing mail looks encrypted";
    ok !$msg->GetHeader('X-RT-Incoming-Signature'),
        "RT's outgoing mail looks not signed";

    like $attachments[0]->Content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'signed_encrypted'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
        "RT's outgoing mail looks encrypted";
    like $msg->GetHeader('X-RT-Incoming-Signature'),
        qr/<rt-recipient\@example.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->Content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}
