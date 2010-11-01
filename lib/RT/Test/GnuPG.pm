package RT::Test::GnuPG;
use strict;
use Test::More;
use base qw(RT::Test);
use File::Temp qw(tempdir);
use RT::Crypt::GnuPG;

our @EXPORT =
  qw(create_a_ticket update_ticket cleanup_headers set_queue_crypt_options 
          check_text_emails send_email_and_check_transaction
          create_and_test_outgoing_emails
          );

sub import {
    my $class = shift;
    my %args  = @_;
    my $t     = $class->builder;

    $t->plan( skip_all => 'GnuPG required.' )
      unless eval { require GnuPG::Interface; 1 };
    $t->plan( skip_all => 'gpg executable is required.' )
      unless RT::Test->find_executable('gpg');

    RT->Config->Set(
        GnuPG                  => Enable => 1,
        OutgoingMessagesFormat => 'RFC',
    );

    my %gnupg_options = (
        'no-permission-warning' => undef,
        $args{gnupg_options} ? %{ $args{gnupg_options} } : (),
    );
    $gnupg_options{homedir} ||= scalar tempdir( CLEANUP => 1 );

    RT->Config->Set( GnuPGOptions => %gnupg_options );

    RT::Test::diag "GnuPG --homedir " . RT->Config->Get('GnuPGOptions')->{'homedir'};

    RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

    $class->SUPER::import(%args);

    $class->set_rights(
        Principal => 'Everyone',
        Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
    );

    $class->set_mail_catcher;
    $class->export_to_level(1);
}

sub create_a_ticket {
    my $queue = shift;
    my $mail = shift;
    my $m = shift;
    my %args = (@_);

    RT::Test->clean_caught_mails;

    $m->goto_create_ticket( $queue );
    $m->form_name('TicketCreate');
    $m->field( Subject    => 'test' );
    $m->field( Requestors => 'rt-test@example.com' );
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

    $m->content_lacks("unable to sign outgoing email messages");


    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails(\%args, @mail );
    categorize_emails($mail, \%args, @mail );
}

sub update_ticket {
    my $tid = shift;
    my $mail = shift;
    my $m = shift;
    my %args = (@_);

    RT::Test->clean_caught_mails;

    $m->get( $m->rt_base_url . "/Ticket/Update.html?Action=Respond&id=$tid" );
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
    $m->content_contains("Message recorded", 'Message recorded') or diag $m->content;


    my @mail = RT::Test->fetch_caught_mails;
    check_text_emails(\%args, @mail );
    categorize_emails($mail, \%args, @mail );
}

sub categorize_emails {
    my $mail = shift;
    my $args = shift;
    my @mail = @_;

    if ( $args->{'Sign'} && $args->{'Encrypt'} ) {
        push @{ $mail->{'signed_encrypted'} }, @mail;
    }
    elsif ( $args->{'Sign'} ) {
        push @{ $mail->{'signed'} }, @mail;
    }
    elsif ( $args->{'Encrypt'} ) {
        push @{ $mail->{'encrypted'} }, @mail;
    }
    else {
        push @{ $mail->{'plain'} }, @mail;
    }
}

sub check_text_emails {
    my %args = %{ shift @_ };
    my @mail = @_;

    ok scalar @mail, "got some mail";
    for my $mail (@mail) {
        for my $type ('email', 'attachment') {
            next if $type eq 'attachment' && !$args{'Attachment'};

            my $content = $type eq 'email'
                        ? "Some content"
                        : "Attachment content";

            if ( $args{'Encrypt'} ) {
                unlike $mail, qr/$content/, "outgoing $type was encrypted";
            } else {
                like $mail, qr/$content/, "outgoing $type was not encrypted";
            } 

            next unless $type eq 'email';

            if ( $args{'Sign'} && $args{'Encrypt'} ) {
                like $mail, qr/BEGIN PGP MESSAGE/, 'outgoing email was signed';
            } elsif ( $args{'Sign'} ) {
                like $mail, qr/SIGNATURE/, 'outgoing email was signed';
            } else {
                unlike $mail, qr/SIGNATURE/, 'outgoing email was not signed';
            }
        }
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
    my $queue = shift;
    my %args = @_;
    $queue->SetEncrypt($args{'Encrypt'});
    $queue->SetSign($args{'Sign'});
}

sub send_email_and_check_transaction {
    my $mail = shift;
    my $type = shift;

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "got id of a newly created ticket - $id" );

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load($id);
    ok( $tick->id, "loaded ticket #$id" );

    my $txn = $tick->Transactions->First;
    my ( $msg, @attachments ) = @{ $txn->Attachments->ItemsArrayRef };

    if ( $attachments[0] ) {
        like $attachments[0]->Content, qr/Some content/,
          "RT's mail includes copy of ticket text";
    }
    else {
        like $msg->Content, qr/Some content/,
          "RT's mail includes copy of ticket text";
    }

    if ( $type eq 'plain' ) {
        ok !$msg->GetHeader('X-RT-Privacy'), "RT's outgoing mail has no crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
          "RT's outgoing mail looks not encrypted";
        ok !$msg->GetHeader('X-RT-Incoming-Signature'),
          "RT's outgoing mail looks not signed";
    }
    elsif ( $type eq 'signed' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'PGP',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted',
          "RT's outgoing mail looks not encrypted";
        like $msg->GetHeader('X-RT-Incoming-Signature'),
          qr/<rt-recipient\@example.com>/,
          "RT's outgoing mail looks signed";
    }
    elsif ( $type eq 'encrypted' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'PGP',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
          "RT's outgoing mail looks encrypted";
        ok !$msg->GetHeader('X-RT-Incoming-Signature'),
          "RT's outgoing mail looks not signed";

    }
    elsif ( $type eq 'signed_encrypted' ) {
        is $msg->GetHeader('X-RT-Privacy'), 'PGP',
          "RT's outgoing mail has crypto";
        is $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success',
          "RT's outgoing mail looks encrypted";
        like $msg->GetHeader('X-RT-Incoming-Signature'),
          qr/<rt-recipient\@example.com>/,
          "RT's outgoing mail looks signed";
    }
    else {
        die "unknown type: $type";
    }
}

sub create_and_test_outgoing_emails {
    my $queue = shift;
    my $m     = shift;
    my @variants =
      ( {}, { Sign => 1 }, { Encrypt => 1 }, { Sign => 1, Encrypt => 1 }, );

    # collect emails
    my %mail;

    # create a ticket for each combination
    foreach my $ticket_set (@variants) {
        create_a_ticket( $queue, \%mail, $m, %$ticket_set );
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
    foreach my $ticket_set (@variants) {
        update_ticket( $tid, \%mail, $m, %$ticket_set );
    }

# ------------------------------------------------------------------------------
# now delete all keys from the keyring and put back secret/pub pair for rt-test@
# and only public key for rt-recipient@ so we can verify signatures and decrypt
# like we are on another side recieve emails
# ------------------------------------------------------------------------------

    unlink $_
      foreach glob( RT->Config->Get('GnuPGOptions')->{'homedir'} . "/*" );
    RT::Test->import_gnupg_key( 'rt-recipient@example.com', 'public' );
    RT::Test->import_gnupg_key('rt-test@example.com');

    $queue = RT::Test->load_or_create_queue(
        Name              => 'Regression',
        CorrespondAddress => 'rt-test@example.com',
        CommentAddress    => 'rt-test@example.com',
    );
    ok $queue && $queue->id, 'changed props of the queue';

    for my $type ( keys %mail ) {
        for my $mail ( map cleanup_headers($_), @{ $mail{$type} } ) {
            send_email_and_check_transaction( $mail, $type );
        }
    }
}
