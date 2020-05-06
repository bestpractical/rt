use warnings;
use strict;

use RT::Test tests => undef;

RT->Config->Set('InitialdataFormatHandlers' => [ 'perl', 'RT::Initialdata::JSON' ]);

# None of this should be in the DB
CheckDB('not_ok');

# Load the db from the initialdata test file
my $initialdata = RT::Test::get_relocatable_file("initialdata.json" => "..", "data", "initialdata");
my ($rv, $msg) = RT->DatabaseHandle->InsertData($initialdata, undef, disconnect_after => 0);
ok ($rv, "Insert test data from $initialdata ($msg)");

# Now all of this should be in the DB
CheckDB('ok');

done_testing();

sub CheckDB {
    no strict 'refs';
    no warnings 'uninitialized';

    my $tester = shift;

    my ($r,$m);
    my $su = RT->SystemUser;

    ($r,$m) = RT::Group->new($su)->LoadByCols(Name => 'Test Group 1');
    &$tester ($r, "Test Group 1 found in DB - should be $tester ($m)");

    my $tu1 = RT::User->new($su);
    ($r,$m) = $tu1->Load('testuser1');
    &$tester ($r, "testuser1 user found in DB - should be $tester ($m)");

    my $tq1 = RT::Queue->new($su);
    ($r,$m) = $tq1->Load('Test Queue 1');
    &$tester ($r, "Test Queue 1 found in DB - should be $tester ($m)");

    &$tester ($tu1->HasRight(Object => $tq1, Right => 'SeeQueue'),
        "testuser1 has SeeQueue on Test Queue 1 - should be $tester"
        ) if ($tu1->id and $tq1->id);

    ($r,$m) = RT::ScripAction->new($su)->Load('Test Action 1');
    &$tester ($r, "Test Action 1 found in DB - should be $tester ($m)");

    ($r,$m) = RT::ScripCondition->new($su)->Load('Test Condition 1');
    &$tester ($r, "Test Condition 1 found in DB - should be $tester ($m)");

    ($r,$m) = RT::Template->new($su)->Load('Test Template 1');
    &$tester ($r, "Test Template 1 found in DB - should be $tester ($m)");

    ($r,$m) = RT::CustomField->new($su)->Load('Favorite Color red or blue');
    &$tester ($r, "Favorite Color CF found in DB - should be $tester ($m)");

    ($r,$m) = RT::CustomField->new($su)->Load('Favorite Song');
    &$tester ($r, "Favorite Song CF found in DB - should be $tester ($m)");

    ($r,$m) = RT::Scrip->new($su)->LoadByCols(Description => 'Test Scrip 1');
    &$tester ($r, "Test Scrip 1 found in DB - should be $tester ($m)");

    ($r,$m) = RT::Attribute->new($su)->LoadByNameAndObject(
        Name => 'Test Search 1',
        Object => RT->System
        );
    &$tester ($r, "Test Search 1 found in DB - should be $tester ($m)");

    my $root = RT::Test->load_or_create_user( Name => 'root' );
    ( $r, $m ) = RT::Attribute->new($su)->LoadByNameAndObject(
        Name   => 'Test Search 2',
        Object => $root
    );
    &$tester( $r, "Test Search 2 found in DB - should be $tester ($m)" );
}

sub not_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok (!shift, shift);
}
