#!/usr/bin/perl

use Test::More tests => 21;
use RT::Test;
RT::Init();

use strict;
use warnings;

use RT::Model::Tickets;
use RT::Model::Queue;
use RT::Model::CustomField;

my($ret,$msg);


# Test Sorting by custom fields.

# ---- Create a queue to test with.
my $queue = "CFSortQueue-$$";
my $queue_obj = RT::Model::Queue->new( $RT::SystemUser );
($ret, $msg) = $queue_obj->create(
    Name => $queue,
    Description => 'queue for custom field sort testing'
);
ok($ret, "$queue test queue creation. $msg");

# ---- Create some custom fields.  We're not currently using all of
# them to test with, but the more the merrier.
my $cfO = RT::Model::CustomField->new($RT::SystemUser);
my $cfA = RT::Model::CustomField->new($RT::SystemUser);
my $cfB = RT::Model::CustomField->new($RT::SystemUser);
my $cfC = RT::Model::CustomField->new($RT::SystemUser);

($ret, $msg) = $cfO->create( Name => 'Order',
                             Queue => 0,
                             SortOrder => 1,
                             Description => q{Something to compare results for, since we can't guarantee ticket ID},
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Order Created");

($ret, $msg) = $cfA->create( Name => 'Alpha',
                             Queue => $queue_obj->id,
                             SortOrder => 1,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Alpha Created");

($ret, $msg) = $cfB->create( Name => 'Beta',
                             Queue => $queue_obj->id,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Beta Created");

($ret, $msg) = $cfC->create( Name => 'Charlie',
                             Queue => $queue_obj->id,
                             Description => 'A Testing custom field',
                             Type=> 'FreeformSingle');
ok($ret, "Custom Field Charlie Created");

# ----- Create some tickets to test with.  Assign them some values to
# make it easy to sort with.
my $t1 = RT::Model::Ticket->new($RT::SystemUser);
$t1->create( Queue => $queue_obj->id,
             Subject => 'One',
           );
$t1->AddCustomFieldValue(Field => $cfO->id,  value => '1');
$t1->AddCustomFieldValue(Field => $cfA->id,  value => '2');
$t1->AddCustomFieldValue(Field => $cfB->id,  value => '1');
$t1->AddCustomFieldValue(Field => $cfC->id,  value => 'BBB');

my $t2 = RT::Model::Ticket->new($RT::SystemUser);
$t2->create( Queue => $queue_obj->id,
             Subject => 'Two',
           );
$t2->AddCustomFieldValue(Field => $cfO->id,  value => '2');
$t2->AddCustomFieldValue(Field => $cfA->id,  value => '1');
$t2->AddCustomFieldValue(Field => $cfB->id,  value => '2');
$t2->AddCustomFieldValue(Field => $cfC->id,  value => 'AAA');

# helper
sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->next) {
    push @results, $t->CustomFieldValues($cfO->id)->first->Content;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  @_ = ($results, $order , "Ordered correctly: $order");
  goto \&is;
}

# The real tests start here
my $tx = new RT::Model::Tickets( $RT::SystemUser );


# Make sure we can sort in both directions on a queue specific field.
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by({ column => "CF.${queue}.{Charlie}", order => 'DES' });
is($tx->count,2 ,"We found 2 tickets when lookign for cf charlie");
check_order( $tx, 1, 2);

$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by( {column => "CF.${queue}.{Charlie}", order => 'ASC' });
is($tx->count,2, "We found two tickets when sorting by cf charlie without limiting to it" );
check_order( $tx, 2, 1);

# When ordering by _global_ CustomFields, if more than one queue has a
# CF named Charlie, things will go bad.  So, these results are uniqued
# in Tickets_Overlay.
$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by({ column => "CF.{Charlie}", order => 'DESC' });
diag $tx->build_select_query;
is($tx->count,2);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 1, 2);
}

$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by( {column => "CF.{Charlie}", order => 'ASC' });
diag $tx->build_select_query;
is($tx->count,2);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 2, 1);
}

# Add a new ticket, to test sorting on multiple columns.
my $t3 = RT::Model::Ticket->new($RT::SystemUser);
$t3->create( Queue => $queue_obj->id,
             Subject => 'Three',
           );
$t3->AddCustomFieldValue(Field => $cfO->id,  value => '3');
$t3->AddCustomFieldValue(Field => $cfA->id,  value => '3');
$t3->AddCustomFieldValue(Field => $cfB->id,  value => '2');
$t3->AddCustomFieldValue(Field => $cfC->id,  value => 'AAA');

$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by(
    { column => "CF.${queue}.{Charlie}", order => 'ASC' },
    { column => "CF.${queue}.{Alpha}",   order => 'DES' },
);
is($tx->count,3);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 3, 2, 1);
}

$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by(
    { column => "CF.${queue}.{Charlie}", order => 'DES' },
    { column => "CF.${queue}.{Alpha}",   order => 'ASC' },
);
is($tx->count,3);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 1, 2, 3);
}

# Reverse the order of the secondary column, which changes the order
# of the first two tickets.
$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by(
    { column => "CF.${queue}.{Charlie}", order => 'ASC' },
    { column => "CF.${queue}.{Alpha}",   order => 'ASC' },
);
is($tx->count,3);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 2, 3, 1);
}

$tx = new RT::Model::Tickets( $RT::SystemUser );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by(
    { column => "CF.${queue}.{Charlie}", order => 'DES' },
    { column => "CF.${queue}.{Alpha}",   order => 'DES' },
);
is($tx->count,3);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 1, 3, 2);
}
