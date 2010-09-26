#!/usr/bin/perl

use 5.8.3;
use strict;
use warnings;

use RT;
RT::LoadConfig();
RT->Config->Set('LogToScreen' => 'debug');
RT::Init();

use RT::Transactions;
my $txns = RT::Transactions->new( RT->SystemUser );
$txns->Limit(
    FIELD => 'ObjectType',
    OPERATOR => '=',
    VALUE => 'RT::Group',
    QUOTEVALUE => 1,
    ENTRYAGGREGATOR => 'AND',
);

my $alias = $txns->Join(
    TYPE   => 'LEFT',
    FIELD1 => 'ObjectId',
    TABLE2 => 'Groups',
    FIELD2 => 'Id',
);
$txns->Limit(
    ALIAS => $alias,
    FIELD => 'Domain',
    OPERATOR => '=',
    VALUE => 'ACLEquivalence',
    QUOTEVALUE => 1,
    ENTRYAGGREGATOR => 'AND',
);

$txns->Limit(
    ALIAS => $alias,
    FIELD => 'Type',
    OPERATOR => '=',
    VALUE => 'UserEquiv',
    QUOTEVALUE => 1,
    ENTRYAGGREGATOR => 'AND',
);

$| = 1;
my $total = $txns->Count;
my $i = 0;

FetchNext( $txns, 'init' );
while ( my $rec = FetchNext( $txns ) ) {
    $i++;
    printf("\r%0.2f %%", 100 * $i / $total);
    $RT::Handle->BeginTransaction;
    my ($status) = $rec->Delete;
    unless ($status) {
        print STDERR "Couldn't delete TXN #". $rec->id;
        exit 1;
    }
    $RT::Handle->Commit;
}

use constant PAGE_SIZE => 1000;
sub FetchNext {
    my ($objs, $init) = @_;
    if ( $init ) {
        $objs->RowsPerPage( PAGE_SIZE );
        $objs->FirstPage;
        return;
    }

    my $obj = $objs->Next;
    return $obj if $obj;
    $objs->RedoSearch;
    $objs->FirstPage;
    return $objs->Next;
}

