
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'Not Pg' unless RT->Config->Get('DatabaseType') eq 'Pg';

use RT::Test::FTS;
RT->Config->Set(
    FullTextSearch => Enable => 1,
    Indexed        => 1,
    Column         => 'ContentIndex',
    Table          => 'AttachmentsIndex',
    CFColumn       => 'OCFVContentIndex',
    CFTable        => 'OCFVsIndex',
);

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
        next if $checks{ $ticket->id } || $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}

my $blase = Encode::decode_utf8("blasé");
@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'fts test 1', Content => "book $blase" },
    { Subject => 'fts test 2', Content => "bars blas&eacute;", ContentType => 'text/html'  },
    { Subject => 'all', Content => '', CustomFields => { short => "book $blase baby", long => "hobbit bars blas blase pubs " x 20 } },
    { Subject => 'none', Content => '', CustomFields => { short => "none", long => "none " x 100 } },
);
RT::Test::FTS->sync_index();

my $book = $tickets[0];
my $bars = $tickets[1];
my $all  = $tickets[2];
my $none = $tickets[3];

run_tests(
    "Content LIKE 'book'" => { $book->id => 1, $bars->id => 0, $all->id => 1, $none->id => 0 },
    "Content LIKE 'bars'" => { $book->id => 0, $bars->id => 1, $all->id => 1, $none->id => 0 },

    # Unicode searching
    "Content LIKE '$blase'" => { $book->id => 1, $bars->id => 1, $all->id => 1, $none->id => 0 },
    "Content LIKE 'blase'"  => { $book->id => 0, $bars->id => 0, $all->id => 1, $none->id => 0 },
    "Content LIKE 'blas'"   => { $book->id => 0, $bars->id => 0, $all->id => 1, $none->id => 0 },

    # make sure that Pg stemming works
    "Content LIKE 'books'" => { $book->id => 1, $bars->id => 0, $all->id => 1, $none->id => 0 },
    "Content LIKE 'bar'"   => { $book->id => 0, $bars->id => 1, $all->id => 1, $none->id => 0 },

    # no matches, except $all
    "Content LIKE 'baby'" => { $book->id => 0, $bars->id => 0, $all->id => 1, $none->id => 0 },
    "Content LIKE 'pubs'" => { $book->id => 0, $bars->id => 0, $all->id => 1, $none->id => 0 },

    "HistoryContent LIKE 'bars'" => { $book->id => 0, $bars->id => 1, $all->id => 0, $none->id => 0 },
    "CustomFieldContent LIKE 'bars'" => { $book->id => 0, $bars->id => 0, $all->id => 1, $none->id => 0 },
);

my ( $ret, $msg ) = $book->Correspond( Content => 'hobbit' );
ok( $ret, 'Corresponded' ) or diag $msg;

( $ret, $msg ) = $book->SetSubject('updated');
ok( $ret, 'Updated subject' ) or diag $msg;

RT::Test::FTS->sync_index();

run_tests(
    "Content LIKE 'book' AND Content LIKE 'hobbit'" => { $book->id => 1, $bars->id => 0, $all->id => 1, $none->id => 0 },
    "Subject LIKE 'updated' OR Content LIKE 'bars'" => { $book->id => 1, $bars->id => 1, $all->id => 1, $none->id => 0 },
    "( Subject LIKE 'updated' OR Content LIKE 'hobbit' ) AND ( Content LIKE 'book' OR Content LIKE 'bars' )" =>
        { $book->id => 1, $bars->id => 0, $all->id => 1, $none->id => 0 },
);

diag "Checking SQL query";

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL(q{Content LIKE 'book' AND Content LIKE 'hobbit'});
like( $tickets->BuildSelectQuery(), qr{ INTERSECT }, 'AND query contains INTERSECT' );

$tickets->FromSQL(q{Subject LIKE 'updated' OR Content LIKE 'bars'});
like( $tickets->BuildSelectQuery(), qr{ UNION }, 'OR query contains UNION' );

$tickets->FromSQL(
    q{( Subject LIKE 'updated' OR Content LIKE 'hobbit' ) AND ( Content LIKE 'book' OR Content LIKE 'bars' )});
like(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR query contains both INTERSECT and UNION'
);

diag "Checking transaction searches";

my $txns = RT::Transactions->new( RT->SystemUser );
$txns->FromSQL(qq{Content LIKE 'book' AND Content LIKE '$blase'});
is( $txns->Count, 1, 'Found one transaction' );
my $txn = $txns->First;
like( $txns->BuildSelectQuery(), qr{ INTERSECT }, 'AND transaction query contains INTERSECT' );
like( $txn->Content,             qr/book $blase/, 'Transaction content' );

$txns->FromSQL(q{Content LIKE 'book' AND Content LIKE 'hobbit'});
like( $txns->BuildSelectQuery(), qr{ INTERSECT }, 'AND transaction query contains INTERSECT' );
is( $txns->Count, 0, 'Found 0 transactions' );

$txns->FromSQL(q{Content LIKE 'book' OR Content LIKE 'hobbit'});
like( $txns->BuildSelectQuery(), qr{ UNION }, 'OR transaction query contains UNION' );
is( $txns->Count, 2, 'Found 2 transactions' );
my @txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/book/,   'Transaction content' );
like( $txns[1]->Content, qr/hobbit/, 'Transaction content' );

$txns->FromSQL(qq{( Content LIKE 'book' AND Content LIKE '$blase' ) OR Content LIKE 'hobbit'});
like(
    $tickets->BuildSelectQuery(),
    qr{ (?:INTERSECT|UNION) .+ (?:INTERSECT|UNION) },
    'AND&OR transaction query contains both INTERSECT and UNION'
);
is( $txns->Count, 2, 'Found 2 transactions' );
@txns = @{ $txns->ItemsArrayRef };
like( $txns[0]->Content, qr/book/,   'Transaction content' );
like( $txns[1]->Content, qr/hobbit/, 'Transaction content' );


diag q{Test the "ts_vector too long" skip};

my $content = "";
$content .= "$_\n" for 1..200_000;
@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'Short content', Content => '50' },
    { Subject => 'Long content',  Content => $content  },
    { Subject => 'More short',    Content => '50' },
);

my ($exit_code, $output) = RT::Test->run_and_capture(
    command => $RT::SbinPath .'/rt-fulltext-indexer'
);
like($output, qr/string is too long for tsvector/, "Got a warning for the ticket");
ok(!$exit_code, "set up index");

# The long content is skipped entirely
run_tests(
    "Content LIKE '1'"  => { $tickets[0]->id => 0, $tickets[1]->id => 0, $tickets[2]->id => 0 },
    "Content LIKE '50'" => { $tickets[0]->id => 1, $tickets[1]->id => 0, $tickets[2]->id => 1 },
);

@tickets = ();

diag "Checking phrase search";

@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'phrase match', Content => 'alpha beta gamma' },
    { Subject => 'phrase reverse', Content => 'beta alpha gamma' },
);
RT::Test::FTS->sync_index();

run_tests(
    "Content LIKE 'alpha beta'" => { 'phrase match' => 1, 'phrase reverse' => 0 },
    "Content LIKE 'beta alpha'" => { 'phrase match' => 0, 'phrase reverse' => 1 },
    "Content LIKE 'alpha'" => { 'phrase match' => 1, 'phrase reverse' => 1 },
);

@tickets = ();

diag "Re-indexing with rt-fulltext-indexer --reindex";

my $dbh = $RT::Handle->dbh;
my $short_cf = RT::Test->load_or_create_custom_field(
    Name => 'short', Type => 'FreeformSingle', Queue => $q->Id );

sub run_indexer {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return RT::Test->run_and_capture(
        command => $RT::SbinPath . '/rt-fulltext-indexer',
        @_,
    );
}

sub index_content_for {
    my $attachment_id = shift;
    my ($content) = $dbh->selectrow_array(
        "SELECT ContentIndex FROM AttachmentsIndex WHERE id = ?", undef, $attachment_id );
    return $content;
}

sub blank_index_for {
    my @ids = @_;
    $dbh->do( "UPDATE AttachmentsIndex SET ContentIndex = ''::tsvector WHERE id IN ("
            . join( ',', ('?') x @ids ) . ")", undef, @ids );
}

sub new_attachment_id {
    my ( $subject, $content ) = @_;
    my $ticket = RT::Test->create_ticket(
        Queue => $queue, Subject => $subject, Content => $content );
    return $ticket->Transactions->First->Attachments->First->id;
}

my $attachment_id = new_attachment_id( 'reindex blank', 'unmistakable haystack content' );
ok( $attachment_id, 'created an indexable attachment' );

RT::Test::FTS->sync_index();
like( index_content_for($attachment_id), qr/haystack/,
    'attachment is indexed to start with' );

diag "--reindex blank re-indexes rows the indexer previously gave up on";

# An empty tsvector is what rt-fulltext-indexer leaves behind for an
# attachment that failed to index; the MAX(id) resume never revisits it.
blank_index_for($attachment_id);
is( index_content_for($attachment_id), '', 'index entry blanked' );

( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, '--reindex blank exited 0' ) or diag "output: $output";
like( index_content_for($attachment_id), qr/haystack/,
    '--reindex blank restored the content' );

diag "--reindex only touches the attachments it selected";

my @pair = (
    new_attachment_id( 'selective 1', 'selective marker oneword' ),
    new_attachment_id( 'selective 2', 'selective marker twoword' ),
);
RT::Test::FTS->sync_index();
blank_index_for(@pair);

( $exit_code, $output ) = run_indexer( reindex => "id = $pair[0]" );
is( $exit_code, 0, '--reindex <sql> exited 0' ) or diag "output: $output";
like( index_content_for( $pair[0] ), qr/oneword/,
    'the selected attachment was re-indexed' );
is( index_content_for( $pair[1] ), '',
    'the unselected attachment was left blank' );

diag "--reindex processes the whole set, not just the first --limit batch";

my @batch = map { new_attachment_id( "batch $_", "batch marker number$_" ) } 1 .. 3;
RT::Test::FTS->sync_index();
blank_index_for(@batch);

( $exit_code, $output ) = run_indexer( reindex => 'blank', limit => 2 );
is( $exit_code, 0, '--reindex with a limit smaller than the set exited 0' )
    or diag "output: $output";
for my $n ( 1 .. 3 ) {
    like( index_content_for( $batch[ $n - 1 ] ), qr/number$n/,
        "batch attachment $n re-indexed despite --limit 2" );
}

diag "--dry-run reports what would be re-indexed and changes nothing";

blank_index_for($attachment_id);

# Content that tokenises to nothing is stored as an empty tsvector too,
# and is indistinguishable from an entry the indexer gave up on, so count
# rather than assuming this attachment is the only one selected.
my ($blank_count) = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM AttachmentsIndex WHERE ContentIndex = ''::tsvector" );
cmp_ok( $blank_count, '>=', 1, 'at least the blanked attachment is selectable' );

( $exit_code, $output ) = run_indexer( reindex => 'blank', 'dry-run' => 1 );
is( $exit_code, 0, '--dry-run exited 0' ) or diag "output: $output";
like( $output, qr/\b$blank_count attachments? would be re-indexed/,
    '--dry-run reported the count' )
    or diag "output: $output";
is( index_content_for($attachment_id), '', '--dry-run left the index untouched' );

diag "--reindex leaves custom field values alone";

sub ocfv_index_count {
    my ($count) = $dbh->selectrow_array("SELECT COUNT(*) FROM OCFVsIndex");
    return $count;
}

# Get any already-outstanding custom field values indexed, so the only
# unindexed one left is the value created below.
RT::Test::FTS->sync_index();
my $ocfv_rows_before = ocfv_index_count();

my $cf_ticket = RT::Test->create_ticket(
    Queue                        => $queue,
    Subject                      => 'ocfv untouched',
    Content                      => 'ocfv marker',
    'CustomField-' . $short_cf->id => 'indexable custom value',
);
ok( $cf_ticket->id, 'created a ticket with a custom field value' );

blank_index_for($attachment_id);

( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, '--reindex blank exited 0' ) or diag "output: $output";

like( index_content_for($attachment_id), qr/haystack/,
    '--reindex still re-indexed the attachment' );
is( ocfv_index_count(), $ocfv_rows_before,
    '--reindex did not index the outstanding custom field value' );

RT::Test::FTS->sync_index();
cmp_ok( ocfv_index_count(), '>', $ocfv_rows_before,
    'an ordinary run still indexes custom field values' );

done_testing;
