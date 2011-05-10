use strict;
use warnings;

use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

use MIME::Entity;

diag "simple rfc822 attachment";
{

    my $top = MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'this is top',
        Data    => ['top mail'],
    );

    my $rfc822 = MIME::Entity->build(
        From    => 'foo@localhost',
        To      => 'bar@localhost',
        Subject => 'rfc822',
        Data    => ['rfc822 attachment'],
    );

    $top->attach(
        Data => $rfc822->stringify,
        Type => 'message/rfc822',
    );
    like( $top->stringify, qr/foo\@localhost/,
        'original mail has rfc822 att header' );

    test_mail( $top );
}

diag "multipart rfc822 attachment";
{

    my $top = MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'this is top',
        Data    => ['top mail'],
    );

    my $rfc822 = MIME::Entity->build(
        From    => 'foo@localhost',
        To      => 'bar@localhost',
        Subject => 'rfc822',
        Data    => ['rfc822 attachment'],
    );

    $rfc822->attach(
        Data => 'attachment of rfc822 attachment',
        Type => 'text/plain',
    );

    $top->attach(
        Data => $rfc822->stringify,
        Type => 'message/rfc822',
    );
    like( $top->stringify, qr/foo\@localhost/,
        'original mail has rfc822 att header' );

    test_mail( $top );
}

sub test_mail {
    my $entity = shift;
    my ( $status, $id ) = RT::Test->send_via_mailgate($entity);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "created ticket" );
    my $ticket = RT::Test->last_ticket;

    my $txn = $ticket->Transactions->First;
    like( $txn->ContentAsMIME->stringify,
        qr/foo\@localhost/, 'txn content has rfc822 att header' );

}
