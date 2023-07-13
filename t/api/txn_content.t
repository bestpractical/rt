use warnings;
use strict;

use RT::Test tests => undef;
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


# test RT::Transaction->QuoteContent
{
    {
        my $got = RT::Transaction->QuoteContent(
            Type        => 'text/plain',
            Content     => 'foo',
        );
        is $got, "> foo", "ok";
    }

    {
        my $got = RT::Transaction->QuoteContent(
            Type        => 'text/html',
            Content     => '<stron>jane & joe</strong>',
        );
        is $got, '<blockquote class="gmail_quote" type="cite">' . '<stron>jane & joe</strong>' . '</blockquote>', "ok",;
    }

    {
        my $got = RT::Transaction->QuoteContent(
            Type        => 'text/plain',
            Content     => 'jane & joe',
        );
        is $got, "> jane & joe", "ok",;
    }

    {
        my $got = RT::Transaction->QuoteContent(
            Type        => 'text/html',
            QuoteHeader => 'Nemo wrote:',
            Content     => '<stron>jane & joe</strong>',
        );
        is $got,
              '<div class="gmail_quote">Nemo wrote:<br />'
            . '<blockquote class="gmail_quote" type="cite">'
            . '<stron>jane & joe</strong>'
            . '</blockquote>'
            . '</div>',
            "ok",
            ;
    }

    {
        my $got = RT::Transaction->QuoteContent(
            Type        => 'text/plain',
            QuoteHeader => 'Nemo wrote:',
            Content     => 'foo',
        );
        is $got, "Nemo wrote:\n> foo", "ok";
    }
}


done_testing;
