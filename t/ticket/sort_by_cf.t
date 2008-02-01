#!/usr/bin/perl

use RT::Test; use Test::More tests => 21;

RT::init();

use strict;
use warnings;

use RT::Model::TicketCollection;
use RT::Model::Queue;
use RT::Model::CustomField;

my($ret,$msg);


# Test Sorting by custom fields.

# ---- Create a queue to test with.
my $queue = "CFSortQueue-$$";
my $queue_obj = RT::Model::Queue->new(current_user => RT->system_user );
($ret, $msg) = $queue_obj->create(
    name => $queue,
    description => 'queue for custom field sort testing'
);
ok($ret, "$queue test queue creation. $msg");

# ---- Create some custom fields.  We're not currently using all of
# them to test with, but the more the merrier.
my $cfO = RT::Model::CustomField->new(current_user => RT->system_user);
my $cfA = RT::Model::CustomField->new(current_user => RT->system_user);
my $cfB = RT::Model::CustomField->new(current_user => RT->system_user);
my $cfC = RT::Model::CustomField->new(current_user => RT->system_user);

($ret, $msg) = $cfO->create( name => 'Order',
                             queue => 0,
                             sort_order => 1,
                             description => q{Something to compare results for, since we can't guarantee ticket ID},
                             type=> 'FreeformSingle');
ok($ret, "Custom Field Order Created");

($ret, $msg) = $cfA->create( name => 'Alpha',
                             queue => $queue_obj->id,
                             sort_order => 1,
                             description => 'A Testing custom field',
                             type=> 'FreeformSingle');
ok($ret, "Custom Field Alpha Created");

($ret, $msg) = $cfB->create( name => 'Beta',
                             queue => $queue_obj->id,
                             description => 'A Testing custom field',
                             type=> 'FreeformSingle');
ok($ret, "Custom Field Beta Created");

($ret, $msg) = $cfC->create( name => 'Charlie',
                             queue => $queue_obj->id,
                             description => 'A Testing custom field',
                             type=> 'FreeformSingle');
ok($ret, "Custom Field Charlie Created");

# ----- Create some tickets to test with.  Assign them some values to
# make it easy to sort with.
my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
$t1->create( queue => $queue_obj->id,
             subject => 'One',
           );
$t1->add_custom_field_value(field => $cfO->id,  value => '1');
$t1->add_custom_field_value(field => $cfA->id,  value => '2');
$t1->add_custom_field_value(field => $cfB->id,  value => '1');
$t1->add_custom_field_value(field => $cfC->id,  value => 'BBB');

my $t2 = RT::Model::Ticket->new(current_user => RT->system_user);
$t2->create( queue => $queue_obj->id,
             subject => 'Two',
           );
$t2->add_custom_field_value(field => $cfO->id,  value => '2');
$t2->add_custom_field_value(field => $cfA->id,  value => '1');
$t2->add_custom_field_value(field => $cfB->id,  value => '2');
$t2->add_custom_field_value(field => $cfC->id,  value => 'AAA');

# helper
sub check_order {
  my ($tx, @order) = @_;
  my @results;
  while (my $t = $tx->next) {
    push @results, $t->custom_field_values($cfO->id)->first->content;
  }
  my $results = join (" ",@results);
  my $order = join(" ",@order);
  @_ = ($results, $order , "Ordered correctly: $order");
  goto \&is;
}

# The real tests start here
my $tx = RT::Model::TicketCollection->new( current_user => RT->system_user );


# Make sure we can sort in both directions on a queue specific field.
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by({ column => "CF.${queue}.{Charlie}", order => 'DES' });
is($tx->count,2 ,"We found 2 tickets when lookign for cf charlie");
check_order( $tx, 1, 2);

$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by( {column => "CF.${queue}.{Charlie}", order => 'ASC' });
is($tx->count,2, "We found two tickets when sorting by cf charlie without limiting to it" );
check_order( $tx, 2, 1);

# When ordering by _global_ CustomFields, if more than one queue has a
# CF named Charlie, things will go bad.  So, these results are uniqued
# in Tickets_Overlay.
$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by({ column => "CF.{Charlie}", order => 'DESC' });
diag $tx->build_select_query;
is($tx->count,2);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 1, 2);
}

$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
$tx->from_sql(qq[queue="$queue"] );
$tx->order_by( {column => "CF.{Charlie}", order => 'ASC' });
diag $tx->build_select_query;
is($tx->count,2);
TODO: {
    local $TODO = 'order by CF fail';
check_order( $tx, 2, 1);
}

# Add a new ticket, to test sorting on multiple columns.
my $t3 = RT::Model::Ticket->new(current_user => RT->system_user);
$t3->create( queue => $queue_obj->id,
             subject => 'Three',
           );
$t3->add_custom_field_value(field => $cfO->id,  value => '3');
$t3->add_custom_field_value(field => $cfA->id,  value => '3');
$t3->add_custom_field_value(field => $cfB->id,  value => '2');
$t3->add_custom_field_value(field => $cfC->id,  value => 'AAA');

$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
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

$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
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
$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
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

$tx = RT::Model::TicketCollection->new( current_user => RT->system_user );
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
