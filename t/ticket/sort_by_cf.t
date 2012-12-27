
use RT::Test nodata => 1, tests => 21;
RT::Init();

use strict;
use warnings;

use RT::Tickets;
use RT::Queue;
use RT::CustomField;

my($ret,$msg);


# Test Sorting by custom fields.
# TODO: it's hard to read this file, conver to new style,
# for example look at 23cfsort-freeform-single.t

# ---- Create a queue to test with.
my $queue = "CFSortQueue-$$";
my $queue_obj = RT::Queue->new( RT->SystemUser );
($ret, $msg) = $queue_obj->Create(
    Name => $queue,
    Description => 'queue for custom field sort testing'
);
ok($ret, "$queue test queue creation. $msg");

# ---- Create some custom fields.  We're not currently using all of
# them to test with, but the more the merrier.
my $cfO = RT::CustomField->new(RT->SystemUser);
my $cfA = RT::CustomField->new(RT->SystemUser);
my $cfB = RT::CustomField->new(RT->SystemUser);
my $cfC = RT::CustomField->new(RT->SystemUser);

($ret, $msg) = $cfO->Create( Name => 'Order',
                             Queue => 0,
                             SortOrder => 1,
                             Description => q{Something to compare results for, since we can't guarantee ticket ID},
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Order created");

($ret, $msg) = $cfA->Create( Name => 'Alpha',
                             Queue => $queue_obj->id,
                             SortOrder => 1,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Alpha created");

($ret, $msg) = $cfB->Create( Name => 'Beta',
                             Queue => $queue_obj->id,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Beta created");

($ret, $msg) = $cfC->Create( Name => 'Charlie',
                             Queue => $queue_obj->id,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Charlie created");

# ----- Create some tickets to test with.  Assign them some values to
# make it easy to sort with.
my $t1 = RT::Ticket->new(RT->SystemUser);
$t1->Create( Queue => $queue_obj->Id,
             Subject => 'One',
           );
$t1->AddCustomFieldValue(Field => $cfO->Id,  Value => '1');
$t1->AddCustomFieldValue(Field => $cfA->Id,  Value => '2');
$t1->AddCustomFieldValue(Field => $cfB->Id,  Value => '1');
$t1->AddCustomFieldValue(Field => $cfC->Id,  Value => 'BBB');

my $t2 = RT::Ticket->new(RT->SystemUser);
$t2->Create( Queue => $queue_obj->Id,
             Subject => 'Two',
           );
$t2->AddCustomFieldValue(Field => $cfO->Id,  Value => '2');
$t2->AddCustomFieldValue(Field => $cfA->Id,  Value => '1');
$t2->AddCustomFieldValue(Field => $cfB->Id,  Value => '2');
$t2->AddCustomFieldValue(Field => $cfC->Id,  Value => 'AAA');

# helper
sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->Next) {
    push @results, $t->CustomFieldValues($cfO->Id)->First->Content;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  @_ = ($results, $order , "Ordered correctly: $order");
  goto \&is;
}

# The real tests start here
my $tx = RT::Tickets->new( RT->SystemUser );


# Make sure we can sort in both directions on a queue specific field.
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderBy( FIELD => "CF.${queue}.{Charlie}", ORDER => 'DES' );
is($tx->Count,2 ,"We found 2 tickets when looking for cf charlie");
check_order( $tx, 1, 2);

$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderBy( FIELD => "CF.${queue}.{Charlie}", ORDER => 'ASC' );
is($tx->Count,2, "We found two tickets when sorting by cf charlie without limiting to it" );
check_order( $tx, 2, 1);

# When ordering by _global_ CustomFields, if more than one queue has a
# CF named Charlie, things will go bad.  So, these results are uniqued
# in Tickets_Overlay.
$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderBy( FIELD => "CF.{Charlie}", ORDER => 'DESC' );
is($tx->Count,2);
check_order( $tx, 1, 2);

$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderBy( FIELD => "CF.{Charlie}", ORDER => 'ASC' );
is($tx->Count,2);
check_order( $tx, 2, 1);

# Add a new ticket, to test sorting on multiple columns.
my $t3 = RT::Ticket->new(RT->SystemUser);
$t3->Create( Queue => $queue_obj->Id,
             Subject => 'Three',
           );
$t3->AddCustomFieldValue(Field => $cfO->Id,  Value => '3');
$t3->AddCustomFieldValue(Field => $cfA->Id,  Value => '3');
$t3->AddCustomFieldValue(Field => $cfB->Id,  Value => '2');
$t3->AddCustomFieldValue(Field => $cfC->Id,  Value => 'AAA');

$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderByCols(
    { FIELD => "CF.${queue}.{Charlie}", ORDER => 'ASC' },
    { FIELD => "CF.${queue}.{Alpha}",   ORDER => 'DES' },
);
is($tx->Count,3);
check_order( $tx, 3, 2, 1);

$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderByCols(
    { FIELD => "CF.${queue}.{Charlie}", ORDER => 'DES' },
    { FIELD => "CF.${queue}.{Alpha}",   ORDER => 'ASC' },
);
is($tx->Count,3);
check_order( $tx, 1, 2, 3);

# Reverse the order of the secondary column, which changes the order
# of the first two tickets.
$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderByCols(
    { FIELD => "CF.${queue}.{Charlie}", ORDER => 'ASC' },
    { FIELD => "CF.${queue}.{Alpha}",   ORDER => 'ASC' },
);
is($tx->Count,3);
check_order( $tx, 2, 3, 1);

$tx = RT::Tickets->new( RT->SystemUser );
$tx->FromSQL(qq[queue="$queue"] );
$tx->OrderByCols(
    { FIELD => "CF.${queue}.{Charlie}", ORDER => 'DES' },
    { FIELD => "CF.${queue}.{Alpha}",   ORDER => 'DES' },
);
is($tx->Count,3);
check_order( $tx, 1, 3, 2);
