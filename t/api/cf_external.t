#!/usr/bin/perl

use warnings;
use strict;

use RT;
use RT::Test nodata => 1, tests => 11;

sub new (*) {
    my $class = shift;
    return $class->new($RT::SystemUser);
}

use constant VALUES_CLASS => 'RT::CustomFieldValues::Groups';

my $q = new( RT::Queue );
isa_ok( $q, 'RT::Queue' );
my ($qid) = $q->Create( Name => "CF-External-". $$ );
ok( $qid, "created queue" );
my %arg = ( Name        => $q->Name,
            Type        => 'Select',
            Queue       => $q->id,
            MaxValues   => 1,
            ValuesClass => VALUES_CLASS );

my $cf = new( RT::CustomField );
isa_ok( $cf, 'RT::CustomField' );

{
    my ($cfid) = $cf->Create( %arg );
    ok( $cfid, "created cf" );
    is( $cf->ValuesClass, VALUES_CLASS, "right values class" );
    ok( $cf->IsExternalValues, "custom field has external values" );
}

{
    # create at least on group for the tests
    my $group = RT::Group->new( $RT::SystemUser );
    my ($ret, $msg) = $group->CreateUserDefinedGroup( Name => $q->Name );
    ok $ret, 'created group' or diag "error: $msg";
}

{
    my $values = $cf->Values;
    isa_ok( $values, VALUES_CLASS );
    ok( $values->Count, "we have values" );
    my ($failure, $count) = (0, 0);
    while( my $value = $values->Next ) {
        $count++;
        $failure = 1 unless $value->Name;
    }
    ok( !$failure, "all values have name" );
    is( $values->Count, $count, "count is correct" );
}

exit(0);
