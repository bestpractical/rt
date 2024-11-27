
use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( FullTextSearch => Enable => 1, Indexed => 0 );

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

sub run_tests {
    my @test = @_;
    while ( my ($query, $checks) = splice @test, 0, 2 ) {
        run_test( $query, %$checks );
    }
}

my @tickets;
sub run_test {
    my ($query, %checks) = @_;
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL( "( $query_prefix ) AND ( $query )" );

    my $error = 0;

    my $count = 0;
    $count++ foreach grep $_, values %checks;
    is($tix->Count, $count, "found correct number of ticket(s) by '$query'") or $error = 1;

    my $good_tickets = ($tix->Count == $count);
    while ( my $ticket = $tix->Next ) {
        next if $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}

@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'book', Content => 'book initial' },
    { Subject => 'bar', Content => 'bar' },
    { Subject => 'no content', Content => undef },
);

run_tests(
    "Content LIKE 'book'" => { book => 1, bar => 0 },
    "Content LIKE 'bar'" => { book => 0, bar => 1  },
    "(Content LIKE 'baz' OR Subject LIKE 'con')" => { 'no content' => 1 },
    "(Content LIKE 'bar' OR Subject LIKE 'con')" => { 'no content' => 1, bar => 1 },
    "(Content LIKE 'bar' OR Subject LIKE 'missing')" => { bar => 1 },
);

my $book = $tickets[0];
my ( $ret, $msg ) = $book->Correspond( Content => 'hobbit' );
ok( $ret, 'Corresponded' ) or diag $msg;

( $ret, $msg ) = $book->SetSubject('updated');
ok( $ret, 'Updated subject' ) or diag $msg;

run_tests(
    "Subject LIKE 'updated' OR Content LIKE 'bar'"  => { updated => 1, bar => 1 },
    "( Subject LIKE 'updated' OR Content LIKE 'hobbit' ) AND ( Content LIKE 'book' OR Content LIKE 'bar' )" =>
        { updated => 1, bar => 0 },
);

diag "Checking SQL query";

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL(q{Content LIKE 'book' AND Content LIKE 'hobbit'});
unlike( $tickets->BuildSelectQuery(), qr{ INTERSECT }, 'AND query does not contain INTERSECT' );

$tickets->FromSQL(q{Subject LIKE 'updated' OR Content LIKE 'bar'});
unlike( $tickets->BuildSelectQuery(), qr{ UNION }, 'OR query does not contain UNION' );

$tickets->FromSQL(
    q{( Subject LIKE 'updated' OR Content LIKE 'hobbit' ) AND ( Content LIKE 'book' OR Content LIKE 'bar' )});
unlike(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR query does not contain both INTERSECT and UNION'
);

diag "Checking transaction searches";

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL(qq{Content LIKE 'book' AND Content LIKE 'initial'});
is( $txns->Count, 1, 'Found one transaction' );
my $txn = $txns->First;
unlike( $txns->BuildSelectQuery(), qr{ INTERSECT },  'AND transaction query does not contain INTERSECT' );
like( $txn->Content,             qr/book initial/, 'Transaction content' );

$txns->FromSQL(q{Content LIKE 'book' AND Content LIKE 'hobbit'});
unlike( $txns->BuildSelectQuery(), qr{ INTERSECT }, 'AND transaction query does not contain INTERSECT' );
is( $txns->Count, 0, 'Found 0 transactions' );

$txns->FromSQL(q{Content LIKE 'book' OR Content LIKE 'hobbit'});
unlike( $txns->BuildSelectQuery(), qr{ UNION }, 'OR transaction query does not contain UNION' );
is( $txns->Count, 2, 'Found 2 transactions' );
my @txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/book/,   'Transaction content' );
like( $txns[1]->Content, qr/hobbit/, 'Transaction content' );

$txns->FromSQL(qq{( Content LIKE 'book' AND Content LIKE 'initial' ) OR Content LIKE 'hobbit'});
unlike(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR transaction query does not contain both INTERSECT and UNION'
);
is( $txns->Count, 2, 'Found 2 transactions' );
@txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/book/,   'Transaction content' );
like( $txns[1]->Content, qr/hobbit/, 'Transaction content' );

@tickets = ();

done_testing;
