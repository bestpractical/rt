use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue->id, 'loaded queue';

{
    my $mail = <<'END';
From: root@localhost
Subject: test
Content-type: text/plain; charset="not-supported-encoding"

ho hum just some text

END

    my ($stat, $id) = RT::Test->send_via_mailgate($mail);
    is( $stat >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "created ticket" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    ok $ticket->id, "loaded ticket";

    my $txn = $ticket->Transactions->First;
    ok !$txn->ContentObj, 'no content';

    my $attach = $txn->Attachments->First;
    like $attach->Content, qr{ho hum just some text}, 'attachment is there';
    is $attach->GetHeader('Content-Type'),
        'application/octet-stream; charset="not-supported-encoding"',
        'content type is changed'
    ;
    is $attach->GetHeader('X-RT-Original-Content-Type'),
        'text/plain',
        'original content type is saved'
    ;
}

done_testing;