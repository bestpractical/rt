#!/usr/bin/perl

use warnings;
use strict;
use RT::Test; use Test::More tests => 12;


sub new (*) {
    my $class = shift;
    return $class->new(RT->system_user);
}

use constant VALUES_CLASS => 'RT::Model::CustomFieldValueCollection::Groups';
use_ok(VALUES_CLASS);
my $q = new( RT::Model::Queue );
isa_ok( $q, 'RT::Model::Queue' );
my ($qid) = $q->create( Name => "CF-External-". $$ );
ok( $qid, "Created queue" );
my %arg = ( Name        => $q->Name,
            Type        => 'Select',
            Queue       => $q->id,
            MaxValues   => 1,
            ValuesClass => VALUES_CLASS );

my $cf = new( RT::Model::CustomField );
isa_ok( $cf, 'RT::Model::CustomField' );

{
    my ($cfid) = $cf->create( %arg );
    ok( $cfid, "Created cf" );
    is( $cf->ValuesClass, VALUES_CLASS, "right values class" );
    ok( $cf->IsExternalValues, "custom field has external values" );
}

{
    # create at least on group for the tests
    my $group = RT::Model::Group->new( RT->system_user );
    my ($ret, $msg) = $group->create_userDefinedGroup( Name => $q->Name );
    ok $ret, 'Created group' or diag "error: $msg";
}

{
    my $values = $cf->Values;
    isa_ok( $values, VALUES_CLASS );
    ok( $values->count, "we have values" );
    my ($failure, $count) = (0, 0);
    while( my $value = $values->next ) {
        $count++;
        $failure = 1 unless $value->Name;
    }
    ok( !$failure, "all values have name" );
    is( $values->count, $count, "count is correct" );
}

exit(0);
