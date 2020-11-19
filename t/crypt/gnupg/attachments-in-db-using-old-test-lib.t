use strict;
use warnings;

use RT::Test::GnuPG
    tests         => 12,
    gnupg_options => {
        passphrase    => 'recipient',
        'trust-model' => 'always',
    }
;

RT->Config->Get('Crypt')->{'AllowEncryptDataInDB'} = 1;

RT::Test->import_gnupg_key('general@example.com', 'public');
RT::Test->import_gnupg_key('general@example.com', 'secret');
my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'general@example.com',
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
    ok $status, 'encrypted attachment';

    isnt $attach->Content, 'test', 'correct content';

    ($status, $msg) = $attach->Decrypt;
    ok $status, 'decrypted attachment';

    is $attach->Content, 'test', 'correct content';
}



