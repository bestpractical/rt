
use strict;
use warnings;

use RT::Test nodata => 1, tests => undef;

{
    no warnings 'redefine';
    use RT::CustomField;
    *RT::CustomField::IsNumeric = sub { 1 }
}

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my $cf    = RT::Test->load_or_create_custom_field( Name => 'test_cf', Queue => $queue->id, Type => 'FreeformSingle' );
my $cfid = $cf->id;

my $cf2    = RT::Test->load_or_create_custom_field( Name => 'test_cf2', Queue => $queue->id, Type => 'FreeformSingle' );
my $cf2id = $cf2->id;

my @tickets = RT::Test->create_tickets(
    { Queue   => $queue->Name },
    { Subject => 'Big',   "CustomField-$cfid" => 12, "CustomField-$cf2id" => 5 },
    { Subject => 'Small', "CustomField-$cfid" => 3, "CustomField-$cf2id" => 10 },
);

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf > 5 });
is( $tickets->Count,     1,               'Found 1 ticket' );
is( $tickets->First->id, $tickets[0]->id, 'Found the big ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf = 12 });
is( $tickets->Count,     1,               'Found 1 ticket' );
is( $tickets->First->id, $tickets[0]->id, 'Found the big ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf < 5});
is( $tickets->Count,     1,               'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the small ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf = 3});
is( $tickets->Count,     1,               'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the small ticket' );

$tickets->FromSQL(q{Queue = 'General' AND CF.test_cf < CF.test_cf2 });
is( $tickets->Count,     1,               'Found 1 ticket' );
is( $tickets->First->id, $tickets[1]->id, 'Found the small ticket' );

$tickets->FromSQL(q{Queue = 'General'});
is( $tickets->Count, 2, 'Found 2 tickets' );
$tickets->OrderByCols( { FIELD => 'CustomField.test_cf' } );
is( $tickets->First->id, $tickets[1]->id, 'Small ticket first' );

$tickets->OrderByCols( { FIELD => 'CustomField.test_cf', ORDER => 'DESC' } );
is( $tickets->First->id, $tickets[0]->id, 'Big ticket first' );

done_testing;
