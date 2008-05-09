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
    FIELD => 'MemberId',
    OPERATOR => '=',
    VALUE => 'main.GroupId',
    QUOTEVALUE => 0,
    ENTRYAGGREGATOR => 'AND',
);
$cgms->Limit(
    FIELD => 'id',
    OPERATOR => '=',
    VALUE => 'main.Via',
    QUOTEVALUE => 0,
    ENTRYAGGREGATOR => 'AND',
);
$cgms->FindAllRows;

while ( my $loop_cgm = $cgms->Next ) {
    my $descendants = RT::CachedGroupMembers->new( $RT::SystemUser );
    $descendants->Limit(
        FIELD => 'Via',
        VALUE => $loop_cgm->id,
        ENTRYAGGREGATOR => 'AND',
    );
    $descendants->Limit(
        FIELD => 'id',
        OPERATOR => '!=',
        VALUE => 'main.Via',
        QUOTEVALUE => 0,
        ENTRYAGGREGATOR => 'AND',
    );
    $descendants->FindAllRows;

    while ( my $rec = $descendants->Next ) {
        my ($status) = $rec->Delete;
        unless ($status) {
            print STDERR "Couldn't delete CGM #". $rec->id;
            exit 1;
        }
    }
}
