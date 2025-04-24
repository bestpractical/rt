
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'Not mysql' unless RT->Config->Get('DatabaseType') eq 'mysql';

use RT::Test::FTS;

RT->Config->Set( FullTextSearch => Enable => 1, Indexed => 1, Table => 'AttachmentsIndex', CFTable => 'OCFVsIndex' );

RT::Test::FTS->setup_indexing();

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

RT::Test->load_or_create_custom_field( Name => 'short', Type => 'FreeformSingle', Queue => $q->Id );
RT::Test->load_or_create_custom_field( Name => 'long',  Type => 'TextSingle',     Queue => $q->Id );

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
    { Subject => 'first', Content => 'english american' },
    { Subject => 'second',  Content => 'french' },
    { Subject => 'third',  Content => 'spanish' },
    { Subject => 'fourth',  Content => 'german' },
    {
        Subject      => 'all',
        Content      => '',
        CustomFields => { short => 'english', long => join ' ', (qw/american french spanish german/) x 30 },
    },
    { Subject => 'none', Content => 'none', CustomFields => { short => 'none', long => 'none ' x 100 }  },
);
RT::Test::FTS->sync_index();

run_tests(
    "Content LIKE 'english'" => { first => 1, second => 0, third => 0, fourth => 0, all => 1, none => 0 },
    "Content LIKE 'french'" => { first => 0, second => 1, third => 0, fourth => 0, all => 1, none => 0 },
    "Subject LIKE 'first' OR Content LIKE 'french'" => { first => 1, second => 1, third => 0, fourth => 0, all => 1, none => 0 },
    "Content LIKE 'english' AND Content LIKE 'american'" => { first => 1, second => 0, third => 0, fourth => 0, all => 1, none => 0 },
    "HistoryContent LIKE 'french'" => { first => 0, second => 1, third => 0, fourth => 0, all => 0, none => 0 },
    "CustomFieldContent LIKE 'french'" => { first => 0, second => 0, third => 0, fourth => 0, all => 1, none => 0 },
);

my ( $ret, $msg ) = $tickets[0]->Correspond( Content => 'chinese' );
ok( $ret, 'Corresponded' ) or diag $msg;

( $ret, $msg ) = $tickets[0]->SetSubject('updated');
ok( $ret, 'Updated subject' ) or diag $msg;

RT::Test::FTS->sync_index();

run_tests(
    "Content LIKE 'english' AND Content LIKE 'chinese'" => { updated => 1, second => 0, third => 0, fourth => 0, all => 0, none => 0 },
    "Subject LIKE 'updated' OR Content LIKE 'french'"   => { updated => 1, second => 1, third => 0, fourth => 0, all => 1, none => 0 },
    "( Subject LIKE 'updated' OR Content LIKE 'english' ) AND ( Content LIKE 'french' OR Content LIKE 'chinese' )"
        => { updated => 1, second => 0, third => 0, fourth => 0, all => 1, none => 0 },
);

diag "Checking SQL query";

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL(q{Content LIKE 'english' AND Content LIKE 'chinese'});
like( $tickets->BuildSelectQuery(), qr{ INTERSECT }, 'AND query contains INTERSECT' );

$tickets->FromSQL(q{Subject LIKE 'updated' OR Content LIKE 'french'});
like( $tickets->BuildSelectQuery(), qr{ UNION }, 'OR query contains UNION' );

$tickets->FromSQL(
    q{(Subject LIKE 'updated' OR Content LIKE 'english') AND ( Content LIKE 'french' OR Content LIKE 'chinese' )});
like(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR query contains both INTERSECT and UNION'
);

diag "Checking transaction searches";

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL(q{Content LIKE 'english' AND Content LIKE 'american'});
is( $txns->Count, 1, 'Found one transaction' );
my $txn = $txns->First;
like( $txns->BuildSelectQuery(), qr{ INTERSECT },      'AND transaction query contains INTERSECT' );
like( $txn->Content,             qr/english american/, 'Transaction content' );

$txns->FromSQL(q{Content LIKE 'english' AND Content LIKE 'chinese'});
like( $txns->BuildSelectQuery(), qr{ INTERSECT }, 'AND transaction query contains INTERSECT' );
is( $txns->Count, 0, 'Found 0 transactions' );

$txns->FromSQL(q{Content LIKE 'english' OR Content LIKE 'chinese'});
like( $txns->BuildSelectQuery(), qr{ UNION }, 'OR transaction query contains UNION' );
is( $txns->Count, 2, 'Found 2 transactions' );
my @txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/english/, 'Transaction content' );
like( $txns[1]->Content, qr/chinese/, 'Transaction content' );

$txns->FromSQL(q{( Content LIKE 'english' AND Content LIKE 'american' ) OR Content LIKE 'chinese'});
like(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR transaction query contains both INTERSECT and UNION'
);
is( $txns->Count, 2, 'Found 2 transactions' );
@txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/english/, 'Transaction content' );
like( $txns[1]->Content, qr/chinese/, 'Transaction content' );

@tickets = ();

done_testing;
