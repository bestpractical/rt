use strict;
use warnings;

use RT::Test::SMIME tests => undef;
my $test = 'RT::Test::SMIME';

use IPC::Run3 'run3';
use RT::Interface::Email;

my ($url, $m) = RT::Test->started_ok;
ok $m->login, "logged in";

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
    CommentAddress    => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

{
    my ($status, $msg) = $queue->SetEncrypt(1);
    ok $status, "turn on encyption by default"
        or diag "error: $msg";
}

my $user;
{
    $user = RT::User->new($RT::SystemUser);
    ok($user->LoadByEmail('root@localhost'), "Loaded user 'root'");
    ok($user->Load('root'), "Loaded user 'root'");
    is($user->EmailAddress, 'root@localhost');

    RT::Test::SMIME->import_key( 'root@example.com.crt' => $user );
}

RT::Test->clean_caught_mails;

{
    my $mail = <<END;
From: root\@localhost
To: rt\@example.com
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!

END

    my ($status, $id) = RT::Test->send_via_mailgate(
        $mail, queue => $queue->Name,
    );
    is $status >> 8, 0, "successfuly executed mailgate";

    my $ticket = RT::Ticket->new($RT::SystemUser);
    $ticket->Load( $id );
    ok ($ticket->id, "found ticket ". $ticket->id);
}

{
    my @mails = RT::Test->fetch_caught_mails;
    is scalar @mails, 1, "autoreply";

    my ($buf, $err);
    local $@;
    ok(eval {
        run3([
            qw(openssl smime -decrypt -passin pass:123456),
            '-inkey', $test->key_path('root@example.com.key'),
            '-recip', $test->key_path('root@example.com.crt')
        ], \$mails[0], \$buf, \$err )
        }, 'can decrypt'
    );
    diag $@ if $@;
    diag $err if $err;
    diag "Error code: $?" if $?;
    like($buf, qr'This message has been automatically generated in response');
}

done_testing;
