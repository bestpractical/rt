use warnings;
use strict;

use RT::Test tests => 3;
use MIME::Entity;
my $ticket = RT::Ticket->new(RT->SystemUser);
my $mime   = MIME::Entity->build(
    From => 'test@example.com',
    Type => 'text/html',
    Data => ["this is body\n"],
);
$mime->attach( Data => ['this is attachment'] );
my $id = $ticket->Create( MIMEObj => $mime, Queue => 'General' );
ok( $id, "created ticket $id" );
my $txns = $ticket->Transactions;
$txns->Limit( FIELD => 'Type', VALUE => 'Create' );
my $txn = $txns->First;
ok( $txn, 'got Create txn' );
is( $txn->Content, "this is body\n", "txn's content" );
