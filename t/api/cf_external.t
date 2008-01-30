#!/usr/bin/perl

use warnings;
use strict;
use RT::Test; use Test::More tests => 12;


sub new {
    my $class = shift;
    return $class->new(current_user => RT->system_user);
}

use constant VALUES_CLASS => 'RT::Model::CustomFieldValueCollection::Groups';
use_ok(VALUES_CLASS);
my $q = new('RT::Model::Queue' );
isa_ok( $q, 'RT::Model::Queue' );
my ($qid) = $q->create( name => "CF-External-". $$ );
ok( $qid, "Created queue" );
my %arg = ( name        => $q->name,
            type        => 'Select',
            queue       => $q->id,
            MaxValues   => 1,
            ValuesClass => VALUES_CLASS );

my $cf = new('RT::Model::CustomField' );
isa_ok( $cf, 'RT::Model::CustomField' );

{
    my ($cfid) = $cf->create( %arg );
    ok( $cfid, "Created cf" );
    is( $cf->values_class, VALUES_CLASS, "right values class" );
    ok( $cf->is_external_values, "custom field has external values" );
}

{
    # create at least on group for the tests
    my $group = RT::Model::Group->new(current_user => RT->system_user );
    my ($ret, $msg) = $group->create_user_defined_group( name => $q->name );
    ok $ret, 'Created group' or diag "error: $msg";
}

{
    my $values = $cf->values;
    isa_ok( $values, VALUES_CLASS );
    ok( $values->count, "we have values" );
    my ($failure, $count) = (0, 0);
    while( my $value = $values->next ) {
        $count++;
        $failure = 1 unless $value->name;
    }
    ok( !$failure, "all values have name" );
    is( $values->count, $count, "count is correct" );
}

exit(0);
