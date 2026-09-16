
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
    my @args = @_;
    my ( $exit_code, $output ) = RT::Test->run_and_capture(
        command => $RT::SbinPath . '/rt-fulltext-indexer',
        @args,
    );
    return ( $exit_code, $output );
}

sub index_content_for {
    my $attachment_id = shift;
    my ($content) = $dbh->selectrow_array(
        "SELECT Content FROM AttachmentsIndex WHERE id = ?", undef, $attachment_id );
    return $content;
}

my $ticket = RT::Test->create_ticket(
    Queue   => $queue,
    Subject => 'reindex blank',
    Content => 'unmistakable haystack content',
);
ok( $ticket->id, 'created ticket' );

my $attachments = $ticket->Transactions->First->Attachments;
my $attachment_id = $attachments->First->id;
ok( $attachment_id, 'found the attachment' );

RT::Test::FTS->sync_index();
like( index_content_for($attachment_id), qr/unmistakable haystack content/,
    'attachment is indexed to start with' );

diag "--reindex blank re-indexes rows the indexer previously gave up on";

# This is the state rt-fulltext-indexer leaves behind when an attachment
# fails to index: a zero-length row, which the MAX(id) resume will never
# revisit.
$dbh->do( "UPDATE AttachmentsIndex SET Content = '' WHERE id = ?", undef, $attachment_id );
is( index_content_for($attachment_id), '', 'index row blanked' );

my ( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, '--reindex blank exited 0' ) or diag "output: $output";

like( index_content_for($attachment_id), qr/unmistakable haystack content/,
    '--reindex blank restored the content' );

diag "--reindex accepts a SQL predicate against Attachments";

my $sql_ticket = RT::Test->create_ticket(
    Queue   => $queue,
    Subject => 'reindex by sql',
    Content => 'distinctive needle phrase',
);
my $sql_attachment_id = $sql_ticket->Transactions->First->Attachments->First->id;

RT::Test::FTS->sync_index();
$dbh->do( "DELETE FROM AttachmentsIndex WHERE id = ?", undef, $sql_attachment_id );
is( index_content_for($sql_attachment_id), undef, 'index row removed' );

( $exit_code, $output ) = run_indexer( reindex => "id = $sql_attachment_id" );
is( $exit_code, 0, '--reindex <sql> exited 0' ) or diag "output: $output";

like( index_content_for($sql_attachment_id), qr/distinctive needle phrase/,
    '--reindex <sql> indexed the selected attachment' );

diag "--reindex blank selects only zero-length rows";

# A one-byte row is what a genuinely empty attachment indexes to: the
# normal path always writes join("\n", Subject, Content).  Use a sentinel
# of the same length to prove the boundary is LENGTH = 0, not falsiness.
$dbh->do( "UPDATE AttachmentsIndex SET Content = 'X' WHERE id = ?", undef, $attachment_id );

( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, '--reindex blank exited 0 with nothing to do' ) or diag "output: $output";

is( index_content_for($attachment_id), 'X',
    '--reindex blank left the one-byte row alone' );

diag "--dry-run reports what would be re-indexed and changes nothing";

$dbh->do( "UPDATE AttachmentsIndex SET Content = '' WHERE id = ?", undef, $attachment_id );

( $exit_code, $output ) = run_indexer( reindex => 'blank', 'dry-run' => 1 );
is( $exit_code, 0, '--dry-run exited 0' ) or diag "output: $output";
like( $output, qr/\b1 attachment\b/, '--dry-run reported the count' )
    or diag "output: $output";
is( index_content_for($attachment_id), '',
    '--dry-run left the index untouched' );

# and without --dry-run the same selection is actually applied
( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, 'follow-up run exited 0' ) or diag "output: $output";
like( index_content_for($attachment_id), qr/unmistakable haystack content/,
    'follow-up run re-indexed what --dry-run predicted' );

diag "--reindex processes the whole set, not just the first --limit batch";

my @batch_ids;
for my $n ( 1 .. 3 ) {
    my $t = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => "batch $n",
        Content => "batch marker $n",
    );
    push @batch_ids, $t->Transactions->First->Attachments->First->id;
}
RT::Test::FTS->sync_index();

$dbh->do( "UPDATE AttachmentsIndex SET Content = '' WHERE id IN ("
        . join( ',', ('?') x @batch_ids ) . ")", undef, @batch_ids );

( $exit_code, $output ) = run_indexer( reindex => 'blank', limit => 2 );
is( $exit_code, 0, '--reindex with a limit smaller than the set exited 0' )
    or diag "output: $output";

for my $n ( 1 .. 3 ) {
    like( index_content_for( $batch_ids[ $n - 1 ] ), qr/batch marker $n/,
        "batch attachment $n re-indexed despite --limit 2" );
}

diag "--reindex only touches the attachments it selected";

my @pair;
for my $n ( 1 .. 2 ) {
    my $t = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => "selective $n",
        Content => "selective marker $n",
    );
    push @pair, $t->Transactions->First->Attachments->First->id;
}
RT::Test::FTS->sync_index();
$dbh->do( "UPDATE AttachmentsIndex SET Content = '' WHERE id IN (?,?)", undef, @pair );

( $exit_code, $output ) = run_indexer( reindex => "id = $pair[0]" );
is( $exit_code, 0, '--reindex <sql> exited 0' ) or diag "output: $output";

like( index_content_for( $pair[0] ), qr/selective marker 1/,
    'the selected attachment was re-indexed' );
is( index_content_for( $pair[1] ), '',
    'the unselected attachment was left blank' );

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
    Queue   => $queue,
    Subject => 'ocfv untouched',
    Content => 'ocfv marker',
    'CustomField-' . $short_cf->id => 'indexable custom value',
);
ok( $cf_ticket->id, 'created a ticket with a custom field value' );

$dbh->do( "UPDATE AttachmentsIndex SET Content = '' WHERE id = ?", undef, $attachment_id );

( $exit_code, $output ) = run_indexer( reindex => 'blank' );
is( $exit_code, 0, '--reindex blank exited 0' ) or diag "output: $output";

like( index_content_for($attachment_id), qr/unmistakable haystack content/,
    '--reindex still re-indexed the attachment' );
is( ocfv_index_count(), $ocfv_rows_before,
    '--reindex did not index the outstanding custom field value' );

# ...and an ordinary run still picks it up
RT::Test::FTS->sync_index();
cmp_ok( ocfv_index_count(), '>', $ocfv_rows_before,
    'an ordinary run still indexes custom field values' );

done_testing;
