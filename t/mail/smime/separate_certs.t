use strict;
use warnings;

use RT::Test::SMIME tests => undef;

use IPC::Run3 'run3';
use Test::Warn;

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
);

my ( $ret, $msg ) = $queue->SetSignAuto(1);
ok( $ret, 'Enabled SignAuto' );

my %signing = (
    'sender@example.com.pem'            => 1,
    'sender@example.com.signing.pem'    => 1,
    'sender@example.com.encryption.pem' => 0,
);

my $key_ring = RT->Config->Get('SMIME')->{'Keyring'};
for my $key ( keys %signing ) {
    diag "Testing signing with $key";

    RT::Test::SMIME->import_key('sender@example.com');
    if ( $key ne 'sender@example.com' ) {
        rename File::Spec->catfile( $key_ring, 'sender@example.com.pem' ), File::Spec->catfile( $key_ring, $key )
          or die $!;
    }

    my $mail = <<END;
From: root\@localhost
Subject: test signing

Hello
END

    my ( $ret, $id ) = RT::Test->send_via_mailgate( $mail, queue => $queue->Name, );
    is $ret >> 8, 0, "Successfuly executed mailgate";

    my @mails = RT::Test->fetch_caught_mails;
    if ( $signing{$key} ) {
        is scalar @mails, 1, "autoreply";
        like( $mails[0], qr'Content-Type: application/x-pkcs7-signature', 'Sent message contains signature' );

        my ( $buf, $err );
        run3( [ qw(openssl smime -verify), '-CAfile', RT::Test::SMIME->key_path . "/demoCA/cacert.pem", ],
            \$mails[0], \$buf, \$err );

        like( $err, qr'Verification successful', 'Verification output' );
        like( $buf, qr'This message has been automatically generated in response', 'Verified message' );
        unlike( $buf, qr'Content-Type: application/x-pkcs7-signature', 'Verified message does not contain signature' );
    }
    else {
        is scalar @mails, 0, "Couldn't send autoreply";
    }

    unlink File::Spec->catfile( $key_ring, $key );
}

( $ret, $msg ) = $queue->SetSignAuto(0);
ok( $ret, 'Disabled SignAuto' );

my %encryption = (
    'sender@example.com.pem'            => 1,
    'sender@example.com.signing.pem'    => 0,
    'sender@example.com.encryption.pem' => 1,
);

my $root = RT::Test->load_or_create_user( Name => 'root' );
( $ret, $msg ) = $root->SetEmailAddress('root@example.com');
ok( $ret, 'set root email to root@example.com' );
RT::Test::SMIME->import_key( 'root@example.com', $root );

for my $key ( keys %encryption ) {
    diag "Testing decryption with $key";

    RT::Test::SMIME->import_key('sender@example.com');
    if ( $key ne 'sender@example.com' ) {
        rename File::Spec->catfile( $key_ring, 'sender@example.com.pem' ), File::Spec->catfile( $key_ring, $key )
          or die $!;
    }

    my ( $buf, $err );
    run3(
        [   qw(openssl smime -encrypt  -des3),
            -from    => 'root@example.com',
            -to      => 'sender@example.com',
            -subject => "Encrypted message for queue",
            RT::Test::SMIME->key_path('sender@example.com.crt'),
        ],
        \"\nthis is content",
        \$buf,
        \$err,
    );

    my ( $ret, $id );
    if ( $encryption{$key} ) {
        ( $ret, $id ) = RT::Test->send_via_mailgate($buf);
    }
    else {
        warning_like {
            ( $ret, $id ) = RT::Test->send_via_mailgate($buf);
        }
        [   qr!Couldn't find SMIME key for addresses: sender\@example.com!,
            qr!Failure during SMIME keycheck: Secret key is not available!
        ],
          "Got missing key warning";
    }

    is( $ret >> 8, 0, "The mail gateway exited normally" );

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load($id);
    is( $ticket->Subject, 'Encrypted message for queue', "Created the ticket" );
    my $txn = $ticket->Transactions->First;
    my ( $msg, $attach, $orig ) = @{ $txn->Attachments->ItemsArrayRef };

    is( $msg->GetHeader('X-RT-Privacy'), 'SMIME', 'X-RT-Privacy is SMIME' );
    is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message', 'Original message is recorded' );

    if ( $encryption{$key} ) {
        is( $msg->GetHeader('X-RT-Incoming-Encryption'), 'Success', 'X-RT-Incoming-Encryption is success' );
        is( $attach->Content, 'this is content', 'Content is decrypted' );
    }
    else {
        is( $msg->GetHeader('X-RT-Incoming-Encryption'), 'Not encrypted', 'X-RT-Incoming-Encryption is not encrypted' );
        unlike( $attach->Content, qr/this is content/, 'Content is not decrypted' );
    }

    unlink File::Spec->catfile( $key_ring, $key );
}

done_testing;
