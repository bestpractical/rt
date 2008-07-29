#!/usr/bin/perl

use 5.8.3;
use strict;
use warnings;

use RT;
RT::LoadConfig();
RT->Config->Set('LogToScreen' => 'debug');
RT::Init();

use RT::CachedGroupMembers;
my $cgms = RT::CachedGroupMembers->new( $RT::SystemUser );
$cgms->Limit(
    FIELD => 'id',
    OPERATOR => '!=',
    VALUE => 'main.Via',
    QUOTEVALUE => 0,
    ENTRYAGGREGATOR => 'AND',
);
$cgms->FindAllRows;

my $alias = $cgms->Join(
    TYPE   => 'LEFT',
    FIELD1 => 'Via',
    TABLE2 => 'CachedGroupMembers',
    FIELD2 => 'id',
);
$cgms->Limit(
    ALIAS => $alias,
    FIELD => 'MemberId',
    OPERATOR => '=',
    VALUE => $alias .'.GroupId',
    QUOTEVALUE => 0,
    ENTRYAGGREGATOR => 'AND',
);
$cgms->Limit(
    ALIAS => $alias,
    FIELD => 'id',
    OPERATOR => '=',
    VALUE => $alias .'.Via',
    QUOTEVALUE => 0,
    ENTRYAGGREGATOR => 'AND',
);

FetchNext( $cgms, 'init' );
while ( my $rec = FetchNext( $cgms ) ) {
    $RT::Handle->BeginTransaction;
    my ($status) = $rec->Delete;
    unless ($status) {
        print STDERR "Couldn't delete CGM #". $rec->id;
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

