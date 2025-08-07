use strict;
use warnings;

use RT::Test::Crypt SMIME => 1, tests => undef;

use RT::Tickets;

RT::Test::Crypt->smime_import_key('sender@example.com');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

{
    my ($status, $msg) = $queue->SetEncrypt(1);
    ok $status, "turn on encyption by default"
        or diag "error: $msg";
}

my $root;
{
    $root = RT::User->new($RT::SystemUser);
    ok($root->LoadByEmail('root@localhost'), "Loaded user 'root'");
    ok($root->Load('root'), "Loaded user 'root'");
    is($root->EmailAddress, 'root@localhost');

    RT::Test::Crypt->smime_import_key( 'root@example.com.crt' => $root );
}

my $untrusted_user = RT::Test->load_or_create_user(
    Name         => 'smime@example.com',
    EmailAddress => 'smime@example.com',
);
RT::Test::Crypt->smime_import_key( 'smime@example.com.crt' => $untrusted_user );
my ( $status, @issues )
    = RT::Crypt->CheckRecipients( Recipients => [ Email::Address->parse('smime@example.com') ] );
ok( !$status, 'smime@example.com.crt can not be used' );
like( $issues[0]{Message}, qr/There is no key suitable for encryption/, 'Reason' );

my $bad_user;
{
    $bad_user = RT::Test->load_or_create_user(
        Name => 'bad_user',
        EmailAddress => 'baduser@example.com',
    );
    ok $bad_user && $bad_user->id, 'created a user without key';
}

RT::Test->clean_caught_mails;

use Test::Warn;

warnings_like {
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ( $status, undef, $msg )
        = $ticket->Create( Queue => $queue->id, Requestor => [ $root->id, $bad_user->id, $untrusted_user->id ] );
    ok $status, "created a ticket" or diag "error: $msg";

    my @mails = RT::Test->fetch_caught_mails;
    is scalar @mails, 4, "autoreply, to bad user, to RT owner";

    like $mails[0], qr{To: baduser\@example\.com}, "notification to bad user";
    like $mails[0], qr{Subject: Your public key in RT is missing or unusable}, "notification subject to bad user";
    like $mails[1], qr{To: smime\@example\.com}, "notification to untrusted user";
    like $mails[1], qr{Subject: Your public key in RT is missing or unusable}, "notification subject to untrusted user";
    like $mails[2], qr{To: root}, "notification to RT owner";
    like $mails[2], qr{Recipient 'baduser\@example\.com' is unusable, the reason is 'Key not found'},
        "notification to owner has error";
    like $mails[2], qr{Recipient 'smime\@example\.com' is unusable, the reason is 'Key not trusted'},
        "notification to owner has error";
} [qr{Recipient 'baduser\@example\.com' is unusable, the reason is 'Key not found'},
   qr{Recipient 'smime\@example\.com' is unusable, the reason is 'Key not trusted'}
  ];

done_testing;
