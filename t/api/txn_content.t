use warnings;
use strict;

use RT::Test tests => 4;
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

# ->Content converts from text/html to plain text if we don't explicitly ask
# for html. Our html -> text converter seems to add an extra trailing newline
like( $txn->Content, qr/^\s*this is body\s*$/, "txn's html content converted to plain text" );
is( $txn->Content(Type => 'text/html'), "this is body\n", "txn's html content" );
