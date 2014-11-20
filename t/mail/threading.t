use strict;
use warnings;

use RT::Test tests => 22;
RT->Config->Set( NotifyActor => 1 );

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

my $user = RT::Test->load_or_create_user(
    Name         => 'root',
    EmailAddress => 'root@localhost',
);
ok $user && $user->id, 'loaded or created user';

{
    my $mail = <<EOF;
From: root\@localhost
Subject: a ticket
Message-ID: <some-message-id>

Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    ok $id, "created a ticket";

    my @mail = RT::Test->fetch_caught_mails;
    is scalar @mail, 1, "autoreply";
    like $mail[0], qr{^In-Reply-To:\s*<some-message-id>$}mi;
    like $mail[0], qr{^References:\s*<RT-Ticket-\Q$id\E\@example\.com>}mi;

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, "loaded ticket";

    ($status, my ($msg)) = $ticket->Correspond( Content => 'boo' );
    ok $status, "replied to the ticket";

    @mail = RT::Test->fetch_caught_mails;
    is scalar @mail, 1, "reply";
    like $mail[0], qr{^References:\s*<RT-Ticket-\Q$id\E\@example\.com>$}mi,
        "no context, so only pseudo header is referenced";
}

{
    my ($ticket) = RT::Test->create_ticket(
        Queue => $queue->id,
        Requestor => $user->EmailAddress
    );
    my $id = $ticket->id;
    ok $id, "created a ticket";

    my @mail = RT::Test->fetch_caught_mails;
    is scalar @mail, 1, "autoreply";
    like $mail[0], qr{^References:\s*<RT-Ticket-\Q$id\E\@example\.com>}mi;
}

{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        Description => "Notify requestor on status change",
        ScripCondition => 'On Status Change',
        ScripAction    => 'Notify Requestors',
        Template       => 'Transaction',
        Stage          => 'TransactionCreate',
        Queue          => 0,
    );
    ok($status, "Scrip created");

    my ($ticket) = RT::Test->create_ticket(
        Queue => $queue->id,
        Requestor => $user->EmailAddress,
    );
    my $id = $ticket->id;
    ok $id, "created a ticket";

    RT::Test->fetch_caught_mails;
    ($status, $msg) = $ticket->SetStatus('open');
    ok $status, "changed status";

    my @mail = RT::Test->fetch_caught_mails;
    is scalar @mail, 1, "status change notification";
    like $mail[0], qr{^References:\s*<RT-Ticket-\Q$id\E\@example\.com>}mi;
}
