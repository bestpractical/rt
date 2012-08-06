
use strict;
use warnings;
use RT;
use RT::Test tests => 16;

use_ok('RT::Transaction');

diag "Test quoting on transaction content";
{
    my $mail = <<'.';
From: root@localhost
Subject: Testing quoting on long lines
Content-Type: text/plain

> This is a short line.

This is a short line.
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket $id" );
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    my $txns = $ticket->Transactions;
    my $txn = $txns->Next;

    my $expected = <<'QUOTED';
> > This is a short line.
> 
> This is a short line.
QUOTED

    my ($content) = $txn->Content( Quote => 1 );
    like( $content, qr/$expected/, 'Text quoted properly');
}

diag "Test quoting on transaction content with lines > 70 chars";
{
    my $mail = <<'.';
From: root@localhost
Subject: Testing quoting on long lines
Content-Type: text/plain

> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.

This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket $id" );
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    my $txns = $ticket->Transactions;
    my $txn = $txns->Next;

    my $expected = <<'QUOTED';
> > This is a line that is longer than the 70 characters that will
> > demonstrate quoting when text is wrapped to multiple lines.
> 
> This is a line that is longer than the 70 characters that will
> demonstrate quoting when text is wrapped to multiple lines.
QUOTED

    my ($content) = $txn->Content( Quote => 1 );
    like( $content, qr/$expected/, 'Text quoted properly');
}

diag "More complex quoting";
{
    my $mail = <<'.';
From: root@localhost
Subject: Testing quoting on long lines
Content-Type: text/plain

# # This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
# # This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.

This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket $id" );
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    my $txns = $ticket->Transactions;
    my $txn = $txns->Next;

    my $expected = <<'QUOTED';
> # # This is a line that is longer than the 70 characters that will
> # # demonstrate quoting when text is wrapped to multiple lines. This is
> # # a line that is longer than the 70 characters that will demonstrate
> # # quoting when text is wrapped to multiple lines.
> > This is a line that is longer than the 70 characters that will
> > demonstrate quoting when text is wrapped to multiple lines. This is a
> > line that is longer than the 70 characters that will demonstrate
> > quoting when text is wrapped to multiple lines.
> 
> This is a line that is longer than the 70 characters that will
> demonstrate quoting when text is wrapped to multiple lines. This is a
> line that is longer than the 70 characters that will demonstrate
> quoting when text is wrapped to multiple lines.
QUOTED

    my ($content) = $txn->Content( Quote => 1 );
    like( $content, qr/$expected/, 'Text quoted properly');
}

diag "Test different wrap value";
{
    my $mail = <<'.';
From: root@localhost
Subject: Testing quoting on long lines
Content-Type: text/plain

> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.

This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket $id" );
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    my $txns = $ticket->Transactions;
    my $txn = $txns->Next;

    my $expected = <<'QUOTED';
> > This is a line that is longer
> > than the 70 characters that
> > will demonstrate quoting when
> > text is wrapped to multiple
> > lines.
> 
> This is a line that is longer
> than the 70 characters that
> will demonstrate quoting when
> text is wrapped to multiple
> lines.
QUOTED

    my ($content) = $txn->Content( Quote => 1, Wrap => 30 );
    like( $content, qr/$expected/, 'Text quoted properly');
}

diag "Test no quoting on transaction content";
{
    my $mail = <<'.';
From: root@localhost
Subject: Testing quoting on long lines
Content-Type: text/plain

> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.

This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket $id" );
    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    my $txns = $ticket->Transactions;
    my $txn = $txns->Next;

    my $expected = <<'QUOTED';
> This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.

This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines.
QUOTED

    my ($content) = $txn->Content( ); # Quote defaults to 0
    like( $content, qr/$expected/, 'Text quoted properly');
}
