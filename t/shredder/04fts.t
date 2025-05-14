
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'Only on Pg and mysql' unless RT->Config->Get('DatabaseType') =~ /mysql|Pg/;

use RT::Test::FTS;
RT->Config->Set(
    FullTextSearch => Enable => 1,
    Indexed        => 1,
    Column         => 'ContentIndex',
    Table          => 'AttachmentsIndex',
    CFTable        => 'OCFVsIndex',
    CFColumn       => 'OCFVContentIndex',
);
RT::Test::FTS->setup_indexing();

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';

my $cf = RT::Test->load_or_create_custom_field( Name => 'Foo', Queue => $q->Id, Type => 'FreeformSingle' );

# don't want to import as we are not on SQLite, but we want to use couple of utils
require RT::Test::Shredder;

{
    my @tickets = RT::Test->create_tickets(
        { Queue => $q->id },
        { Subject => 'first', Content => 'english', 'CustomField-' . $cf->id => 'foobar' },
    );
    $_->ApplyTransactionBatch for @tickets;

    RT::Test::FTS->sync_index;

    my ( $index_ids, $cf_index_ids ) = index_ids(@tickets);
    is scalar @$index_ids, 1, 'one attachment indexed';
    is scalar @$cf_index_ids, 1, 'one cf indexed';

    my $shredder = RT::Test::Shredder->shredder_new();
    $shredder->PutObjects( Objects => \@tickets );
    $shredder->WipeoutAll;

    my $count = count_indexes(@$index_ids, @$cf_index_ids);
    is $count, 0, 'no attachment/cf indexed';

    RT::Test::Shredder->db_is_valid;

    like get_dump($shredder), qr/AttachmentsIndex/, 'dump contains AttachmentsIndex';
    like get_dump($shredder), qr/OCFVsIndex/, 'dump contains OCFVsIndex';
}

# select directly from FTS table and get ids of indexed attachments
sub index_ids {
    my @tickets = @_;
    my @ids = map { $_->id } @tickets;

    my $dbh = $RT::Handle->dbh;
    my $res = $dbh->selectcol_arrayref(
        "SELECT a.id FROM AttachmentsIndex ai
        JOIN Attachments a ON a.id = ai.id
        JOIN Transactions txn ON a.TransactionId = txn.id AND txn.ObjectType = ?
        WHERE txn.ObjectId IN (" . join( ',', ('?') x @ids ) . ")",
        undef, 'RT::Ticket', @ids,
    );

    my $cf_res = $dbh->selectcol_arrayref(
        "SELECT c.id FROM OCFVsIndex ci
        JOIN ObjectCustomFieldValues c ON c.id = ci.id
        WHERE c.ObjectId IN (" . join( ',', ('?') x @ids ) . ")",
        undef, @ids,
    );
    return ( $res, $cf_res );
}

sub count_indexes {
    my @ids = @_;
    my $dbh = $RT::Handle->dbh;
    my ($res) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM AttachmentsIndex ai WHERE ai.id IN (" . join( ',', ('?') x @ids ) . ")",
        undef, @ids,
    );
    my ($cf_res) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM OCFVsIndex ci WHERE ci.id IN (" . join( ',', ('?') x @ids ) . ")",
        undef, @ids,
    );
    return $res + $cf_res;
}

sub slurp {
    my $fname = shift;

    open my $fh, '<', $fname or die "Can't open $fname: $!";
    return do { local $/; <$fh> };
}

sub get_dump {
    my $shredder = shift;
    my $dplugin = $shredder->{'dump_plugins'}[0];
    my $fname = $dplugin->FileName;
    return slurp($fname);
}

done_testing();
