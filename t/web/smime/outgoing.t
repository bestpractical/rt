#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test tests => 492;

my $openssl = RT::Test->find_executable('openssl');
plan skip_all => 'openssl executable is required.'
    unless $openssl;

use RT::Action::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

use_ok('RT::Crypt::SMIME');

my $keys = RT::Test::get_abs_relocatable_dir(
    (File::Spec->updir()) x 2,
    qw(data smime keys),
);

my $keyring = RT::Test->new_temp_dir(
    crypt => smime => 'smime_keyring'
);

RT->Config->Set( Crypt =>
    Enable   => 1,
    Incoming => ['SMIME'],
    Outgoing => 'SMIME',
);
RT->Config->Set( GnuPG => Enable => 0 );
RT->Config->Set( SMIME =>
    Enable => 1,
    OutgoingMessagesFormat => 'RFC',
    Passphrase => {
        'sender@example.com' => '123456',
        'root@example.com' => '123456',
    },
    OpenSSL => $openssl,
    Keyring => $keyring,
);
RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::Crypt' );

RT::Test->import_smime_key('sender@example.com');

{
    my $cf = RT::CustomField->new( $RT::SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name       => 'SMIME Key',
        LookupType => RT::User->new( $RT::SystemUser )->CustomFieldLookupType,
        Type       => 'TextSingle',
    );
    ok($ret, "Custom Field created");

    my $OCF = RT::ObjectCustomField->new( $RT::SystemUser );
    $OCF->Create(
        CustomField => $cf->id,
        ObjectId    => 0,
    );
}

my $user_email = 'root@example.com';
{
    my $user = RT::User->new( $RT::SystemUser );
    $user->LoadByEmail( $user_email );
    unless ( $user->id ) {
        $user->Create(
            Name         => $user_email,
            EmailAddress => $user_email,
            Privileged   => 1,
        );
    }
    my ($status, $msg) = $user->AddCustomFieldValue(
        Field => 'SMIME Key',
        Value => RT::Test->file_content([$keys, $user_email .'.crt']),
    );
    ok $status, "set key for the user" or diag "error: $msg";
}

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
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

diag "check in read-only mode that queue's props influence create/update ticket pages" if $ENV{TEST_VERBOSE};
{
    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->goto_create_ticket( $queue );
        $m->form_name('TicketCreate');
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }

    # to avoid encryption/signing during create
    set_queue_crypt_options();

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    my ($id) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => $user_email,
    );
    ok $id, 'ticket created';

    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->goto_ticket( $id );
        $m->follow_link_ok({text => 'Reply'}, '-> reply');
        $m->form_number(3);
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }
}

# create a ticket for each combination
foreach my $queue_set ( @variants ) {
    set_queue_crypt_options( %$queue_set );
    foreach my $ticket_set ( @variants ) {
        create_a_ticket( %$ticket_set );
    }
}

my $tid;
{
    my $ticket = RT::Ticket->new( $RT::SystemUser );
    ($tid) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => $user_email,
    );
    ok $tid, 'ticket created';
}

# again for each combination add a reply message
foreach my $queue_set ( @variants ) {
    set_queue_crypt_options( %$queue_set );
    foreach my $ticket_set ( @variants ) {
        update_ticket( $tid, %$ticket_set );
    }
}


# ------------------------------------------------------------------------------
# now delete all keys from the keyring and put back secret/pub pair for rt-test@
# and only public key for sender@ so we can verify signatures and decrypt
# like we are on another side recieving emails
# ------------------------------------------------------------------------------

unlink $_ foreach glob( $keyring ."/*" );
RT::Test->import_smime_key('sender@example.com', 'public');
RT::Test->import_smime_key($user_email);

$queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => $user_email,
    CommentAddress    => $user_email,
);
ok $queue && $queue->id, 'changed props of the queue';

foreach my $mail ( map cleanup_headers($_), @{ $mail{'plain'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( $RT::SystemUser );
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

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'SMIME',
        "RT's outgoing mail has crypto" or exit 0;
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
        "RT's outgoing mail looks not encrypted";
    like $msg->GetHeader('X-RT-Incoming-Signature'),
        qr/<sender\@example\.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->Content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'encrypted'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'SMIME',
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

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is $msg->GetHeader('X-RT-Privacy'), 'SMIME',
        "RT's outgoing mail has crypto";
    is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
        "RT's outgoing mail looks encrypted";
    like $msg->GetHeader('X-RT-Incoming-Signature'),
        qr/<sender\@example.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->Content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

sub create_a_ticket {
    my %args = (@_);

    RT::Test->clean_caught_mails;

    describe_options('creating a ticket: ', %args);

    $m->goto_create_ticket( $queue );
    $m->form_name('TicketCreate');
    $m->field( Subject    => 'test' );
    $m->field( Requestors => $user_email );
    $m->field( Content    => 'Some content' );

    foreach ( qw(Sign Encrypt) ) {
        if ( $args{ $_ } ) {
            $m->tick( $_ => 1 );
        } else {
            $m->untick( $_ => 1 );
        }
    }

    $m->submit;
    is $m->status, 200, "request successful";

    unlike($m->content, qr/unable to sign outgoing email messages/);

    $m->get_ok('/'); # ensure that the mail has been processed

    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails( \%args, @mail );
}

sub update_ticket {
    my $tid = shift;
    my %args = (@_);

    RT::Test->clean_caught_mails;

    describe_options('updating ticket #'. $tid .': ', %args);

    ok $m->goto_ticket( $tid ), "UI -> ticket #$tid";
    $m->follow_link_ok( { text => 'Reply' }, 'ticket -> reply' );
    $m->form_number(3);
    $m->field( UpdateContent => 'Some content' );

    foreach ( qw(Sign Encrypt) ) {
        if ( $args{ $_ } ) {
            $m->tick( $_ => 1 );
        } else {
            $m->untick( $_ => 1 );
        }
    }

    $m->click('SubmitTicket');
    is $m->status, 200, "request successful";
    $m->content_like(qr/Message recorded/, 'Message recorded');# or diag $m->content;

    $m->get_ok('/'); # ensure that the mail has been processed

    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails( \%args, @mail );
}

sub check_text_emails {
    my %args = %{ shift @_ };
    my @mail = @_;

    describe_options('testing that we got at least one mail: ', %args);

    ok scalar @mail, "got some mail";
    for my $mail (@mail) {
        if ( $args{'Encrypt'} ) {
            unlike $mail, qr/Some content/, "outgoing email was encrypted";
        } else {
            like $mail, qr/Some content/, "outgoing email was not encrypted";
        }

        if ( $args{'Encrypt'} ) {
            like $mail, qr/application\/x-pkcs7-mime/, 'outgoing email was processed';
        } elsif ( $args{'Sign'} ) {
            like $mail, qr/x-pkcs7-signature/, 'outgoing email was processed';
        } else {
            unlike $mail, qr/smime/, 'outgoing email was not processed';
        }
    }
    if ( $args{'Sign'} && $args{'Encrypt'} ) {
        push @{ $mail{'signed_encrypted'} }, @mail;
    } elsif ( $args{'Sign'} ) {
        push @{ $mail{'signed'} }, @mail;
    } elsif ( $args{'Encrypt'} ) {
        push @{ $mail{'encrypted'} }, @mail;
    } else {
        push @{ $mail{'plain'} }, @mail;
    }
}

sub cleanup_headers {
    my $mail = shift;
    # strip id from subject to create new ticket
    $mail =~ s/^(Subject:)\s*\[.*?\s+#\d+\]\s*/$1 /m;
    # strip several headers
    foreach my $field ( qw(Message-ID X-RT-Original-Encoding RT-Originator RT-Ticket X-RT-Loop-Prevention) ) {
        $mail =~ s/^$field:.*?\n(?! |\t)//gmsi;
    }
    return $mail;
}

sub set_queue_crypt_options {
    my %args = @_;

    describe_options('setting queue options: ', %args);

    $m->get_ok("/Admin/Queues/Modify.html?id=". $queue->id);
    $m->form_with_fields('Sign', 'Encrypt');
    foreach my $opt ('Sign', 'Encrypt') {
        if ( $args{$opt} ) {
            $m->tick($opt => 1);
        } else {
            $m->untick($opt => 1);
        }
    }
    $m->submit;
}

sub describe_options {
    return unless $ENV{'TEST_VERBOSE'};

    my $msg = shift;
    my %args = @_;
    if ( $args{'Encrypt'} && $args{'Sign'} ) {
        $msg .= 'encrypt and sign';
    }
    elsif ( $args{'Sign'} ) {
        $msg .= 'sign';
    }
    elsif ( $args{'Encrypt'} ) {
        $msg .= 'encrypt';
    }
    else {
        $msg .= 'no encrypt and no sign';
    }
    diag $msg;
}

