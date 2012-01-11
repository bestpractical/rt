use strict;
use warnings;

use RT::Test::SMIME tests => undef;

use IPC::Run3 'run3';
use String::ShellQuote 'shell_quote';
use RT::Tickets;

RT->Config->Get('Crypt')->{'AllowEncryptDataInDB'} = 1;

RT::Test::SMIME->import_key('sender@example.com');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'sender@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue->id,
        Subject => 'test',
        Content => 'test',
    );

    my $txn = $ticket->Transactions->First;
    ok $txn && $txn->id, 'found first transaction';
    is $txn->Type, 'Create', 'it is Create transaction';

    my $attach = $txn->Attachments->First;
    ok $attach && $attach->id, 'found attachment';
    is $attach->Content, 'test', 'correct content';

    my ($status, $msg) = $attach->Encrypt;
    ok $status, 'encrypted attachment' or diag "error: $msg";

    isnt $attach->Content, 'test', 'correct content';

    ($status, $msg) = $attach->Decrypt;
    ok $status, 'decrypted attachment' or diag "error: $msg";

    is $attach->Content, 'test', 'correct content';
}

done_testing;
