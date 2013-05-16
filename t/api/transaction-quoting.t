
use strict;
use warnings;
use RT;
use RT::Test tests => 19;

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

    my $expected = <<QUOTED;
> # # This is a line that is longer than the 70 characters that will
> # # demonstrate quoting when text is wrapped to multiple lines.
> # # This is a line that is longer than the 70 characters that will
> # # demonstrate quoting when text is wrapped to multiple lines.
> > This is a line that is longer than the 70 characters that will
> > demonstrate quoting when text is wrapped to multiple lines.
> > This is a line that is longer than the 70 characters that will
> > demonstrate quoting when text is wrapped to multiple lines.
> 
> This is a line that is longer than the 70 characters that will
> demonstrate quoting when text is wrapped to multiple lines.
> This is a line that is longer than the 70 characters that will
> demonstrate quoting when text is wrapped to multiple lines.
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

diag "Test wrapping with no initial quoting";
{
    my $content =<<CONTENT;
This is a line that is longer than the 70 characters that will demonstrate quoting when text is wrapped to multiple lines. It is not already quoted
This is a line that is exactly 70 characters before it is wrapped here
This is a line that is exactly 76 characters before it is wrapped by the code
This is a short line.
These should remain separate lines.

Line after a line break.
CONTENT

    my $expected =<<EXPECTED;
> This is a line that is longer than the 70 characters that will
> demonstrate quoting when text is wrapped to multiple lines. It is not
> already quoted
> This is a line that is exactly 70 characters before it is wrapped here
> This is a line that is exactly 76 characters before it is wrapped by
> the code
> This is a short line.
> These should remain separate lines.
> 
> Line after a line break.
EXPECTED

    my $txn = RT::Transaction->new(RT->SystemUser);
    my $result = $txn->ApplyQuoteWrap( content => $content, cols => 70 );
    is( $result, $expected, 'Text quoted properly after one quoting.');

    $expected =<<EXPECTED;
> > This is a line that is longer than the 70 characters that will
> > demonstrate quoting when text is wrapped to multiple lines. It is not
> > already quoted
> > This is a line that is exactly 70 characters before it is wrapped here
> > This is a line that is exactly 76 characters before it is wrapped by
> > the code
> > This is a short line.
> > These should remain separate lines.
> > 
> > Line after a line break.
EXPECTED

    $result = $txn->ApplyQuoteWrap( content => $result, cols => 70 );
    is( $result, $expected, 'Text quoted properly after two quotings');

    # Wrapping is only triggered over 76 chars, so quote until 76 is exceeded
    $result = $txn->ApplyQuoteWrap( content => $result, cols => 70 );
    $result = $txn->ApplyQuoteWrap( content => $result, cols => 70 );
    $result = $txn->ApplyQuoteWrap( content => $result, cols => 70 );

    $expected =<<EXPECTED;
> > > > > This is a line that is longer than the 70 characters that will
> > > > > demonstrate quoting when text is wrapped to multiple lines. It
> > > > > is not
> > > > > already quoted
> > > > > This is a line that is exactly 70 characters before it is
> > > > > wrapped here
> > > > > This is a line that is exactly 76 characters before it is
> > > > > wrapped by
> > > > > the code
> > > > > This is a short line.
> > > > > These should remain separate lines.
> > > > >
> > > > > Line after a line break.
EXPECTED

    is( $result, $expected, 'Text quoted properly after five quotings');
}
