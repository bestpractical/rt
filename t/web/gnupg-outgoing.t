#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More tests => 492;
use RT::Test;
use RT::ScripAction::SendEmail;
use File::Temp qw(tempdir);

RT::Test->set_mail_catcher;

RT->config->set( LogToScreen => 'debug' );
RT->config->set( LogStackTraces => 'error' );

use_ok('RT::Crypt::GnuPG');

RT->config->set( GnuPG =>
    enable => 1,
    outgoing_messages_format => 'RFC',
);

RT->config->set( GnuPGOptions =>
    homedir => scalar tempdir( CLEANUP => 1 ),
    passphrase => 'rt-test',
    'no-permission-warning' => undef,
    'trust-model' => 'always',
);
RT->config->set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

my $queue = RT::Test->load_or_create_queue(
    name              => 'Regression',
    correspond_address => 'rt-recipient@example.com',
    comment_address    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

RT::Test->set_rights(
    principal => 'Everyone',
    right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @variants = (
    {},
    { sign => 1 },
    { encrypt => 1 },
    { sign => 1, encrypt => 1 },
);

# collect emails
my %mail = (
    plain            => [],
    signed           => [],
    encrypted        => [],
    signed_encrypted => [],
);

diag "check in read-only mode that queue's props influence create/update ticket pages";
{
    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->goto_create_ticket( $queue );
        $m->form_name('TicketCreate');
        if ( $variant->{'encrypt'} ) {
            ok $m->value('encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'sign'} ) {
            ok $m->value('sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('sign', 2), "sign tick box is unchecked";
        }
    }

    # to avoid encryption/signing during create
    set_queue_crypt_options();

    my $ticket = RT::Model::Ticket->new( current_user =>RT->system_user );
    my ($id) = $ticket->create(
        subject   => 'test',
        queue     => $queue->id,
        requestor => 'rt-test@example.com',
    );
    ok $id, 'ticket created';

    foreach my $variant ( @variants ) {
        set_queue_crypt_options( %$variant );
        $m->goto_ticket( $id );
        $m->follow_link_ok({text => 'Reply'}, '-> reply');
        $m->form_number(3);
        if ( $variant->{'encrypt'} ) {
            ok $m->value('encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'sign'} ) {
            ok $m->value('sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('sign', 2), "sign tick box is unchecked";
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
    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    ($tid) = $ticket->create(
        subject   => 'test',
        queue     => $queue->id,
        requestor => 'rt-test@example.com',
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
# and only public key for rt-recipient@ so we can verify signatures and decrypt
# like we are on another side recieve emails
# ------------------------------------------------------------------------------

unlink $_ foreach glob( RT->config->get('GnuPGOptions')->{'homedir'} ."/*" );
RT::Test->import_gnupg_key('rt-recipient@example.com', 'public');
RT::Test->import_gnupg_key('rt-test@example.com');

$queue = RT::Test->load_or_create_queue(
    name              => 'Regression',
    correspond_address => 'rt-test@example.com',
    comment_address    => 'rt-test@example.com',
);
ok $queue && $queue->id, 'changed props of the queue';

foreach my $mail ( map cleanup_headers($_), @{ $mail{'plain'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Model::Ticket->new(current_user => RT->system_user );
    $tick->load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->transactions->first;
    my ($msg, @attachments) = @{$txn->attachments->items_array_ref};

    ok !$msg->get_header('X-RT-Privacy'), "RT's outgoing mail has no crypto";
    is $msg->get_header('X-RT-Incoming-Encryption'), 'Not encrypted',
        "RT's outgoing mail looks not encrypted";
    ok !$msg->get_header('X-RT-Incoming-Signature'),
        "RT's outgoing mail looks not signed";

    like $msg->content, qr/Some content/, "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'signed'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Model::Ticket->new(current_user => RT->system_user );
    $tick->load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->transactions->first;
    my ($msg, @attachments) = @{$txn->attachments->items_array_ref};

    is $msg->get_header('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->get_header('X-RT-Incoming-Encryption'), 'Not encrypted',
        "RT's outgoing mail looks not encrypted";
    like $msg->get_header('X-RT-Incoming-Signature'),
        qr/<rt-recipient\@example.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'encrypted'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Model::Ticket->new(current_user => RT->system_user );
    $tick->load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->transactions->first;
    my ($msg, @attachments) = @{$txn->attachments->items_array_ref};

    is $msg->get_header('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->get_header('X-RT-Incoming-Encryption'), 'Success',
        "RT's outgoing mail looks encrypted";
    ok !$msg->get_header('X-RT-Incoming-Signature'),
        "RT's outgoing mail looks not signed";

    like $attachments[0]->content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

foreach my $mail ( map cleanup_headers($_), @{ $mail{'signed_encrypted'} } ) {
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Model::Ticket->new(current_user => RT->system_user );
    $tick->load( $id );
    ok ($tick->id, "loaded ticket #$id");

    my $txn = $tick->transactions->first;
    my ($msg, @attachments) = @{$txn->attachments->items_array_ref};

    is $msg->get_header('X-RT-Privacy'), 'PGP',
        "RT's outgoing mail has crypto";
    is $msg->get_header('X-RT-Incoming-Encryption'), 'Success',
        "RT's outgoing mail looks encrypted";
    like $msg->get_header('X-RT-Incoming-Signature'),
        qr/<rt-recipient\@example.com>/,
        "RT's outgoing mail looks signed";

    like $attachments[0]->content, qr/Some content/,
        "RT's mail includes copy of ticket text";
}

sub create_a_ticket {
    my %args = (@_);

    # cleanup mail catcher's storage
    RT::Test->fetch_caught_mails;

    $m->goto_create_ticket( $queue );
    $m->form_name('TicketCreate');
    $m->field( subject    => 'test' );
    $m->field( requestors => 'rt-test@example.com' );
    $m->field( content    => 'Some content' );

    foreach ( qw(sign encrypt) ) {
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

    # cleanup mail catcher's storage
    RT::Test->fetch_caught_mails;

    ok $m->goto_ticket( $tid ), "UI -> ticket #$tid";
    $m->follow_link_ok( { text => 'Reply' }, 'ticket -> reply' );
    $m->form_number(3);
    $m->field( update_content => 'Some content' );

    foreach ( qw(sign encrypt) ) {
        if ( $args{ $_ } ) {
            $m->tick( $_ => 1 );
        } else {
            $m->untick( $_ => 1 );
        }
    }

    $m->click('SubmitTicket');
    is $m->status, 200, "request successful";
    $m->content_like(qr/Message recorded/, 'Message recorded') or diag $m->content;

    $m->get_ok('/'); # ensure that the mail has been processed

    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails( \%args, @mail );
}

sub check_text_emails {
    my %args = %{ shift @_ };
    my @mail = @_;

    ok scalar @mail, "got some mail";
    for my $mail (@mail) {
        if ( $args{'encrypt'} ) {
            unlike $mail, qr/Some content/, "outgoing email was encrypted";
        } else {
            like $mail, qr/Some content/, "outgoing email was not encrypted";
        } 
        if ( $args{'sign'} && $args{'encrypt'} ) {
            like $mail, qr/BEGIN PGP MESSAGE/, 'outgoing email was signed';
        } elsif ( $args{'sign'} ) {
            like $mail, qr/SIGNATURE/, 'outgoing email was signed';
        } else {
            unlike $mail, qr/SIGNATURE/, 'outgoing email was not signed';
        }
    }
    if ( $args{'sign'} && $args{'encrypt'} ) {
        push @{ $mail{'signed_encrypted'} }, @mail;
    } elsif ( $args{'sign'} ) {
        push @{ $mail{'signed'} }, @mail;
    } elsif ( $args{'encrypt'} ) {
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
    $m->get_ok("/Admin/Queues/Modify.html?id=". $queue->id);
    $m->form_with_fields('sign', 'encrypt');
    foreach my $opt ('sign', 'encrypt') {
        if ( $args{$opt} ) {
            $m->tick($opt => 1);
        } else {
            $m->untick($opt => 1);
        }
    }
    $m->submit;
}

