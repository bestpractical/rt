#!/usr/bin/perl

use strict;
use RT::Test tests => 138;


# Before we get going, ditch all object_cfs; this will remove 
# all custom fields systemwide;
my $object_cfs = RT::Model::ObjectCustomFieldCollection->new($RT::SystemUser);
$object_cfs->find_all_rows();
while (my $ocf = $object_cfs->next) {
	$ocf->delete();
}


my $queue = RT::Model::Queue->new( $RT::SystemUser );
$queue->create( Name => 'RecordCustomFields-'.$$ );
ok ($queue->id, "Created the queue" . $queue->id);

my $queue2 = RT::Model::Queue->new( $RT::SystemUser );
$queue2->create( Name => 'RecordCustomFields2' );
ok ($queue->id, "Created the second  queue");

my $ticket = RT::Model::Ticket->new( $RT::SystemUser );
$ticket->create(
	Queue => $queue->id,
	Requestor => 'root@localhost',
	Subject => 'RecordCustomFields1',
);

ok($ticket->id, "Created the ticket ok");

my $cfs = $ticket->CustomFields;
is( $cfs->count, 0 );

# Check that record has no any CF values yet {{{
my $cfvs = $ticket->CustomFieldValues;
is( $cfvs->count, 0 );
is( $ticket->first_custom_field_value, undef );

my $local_cf1 = RT::Model::CustomField->new( $RT::SystemUser );
my ($status,$msg) = $local_cf1->create( Name => 'RecordCustomFields1-'.$$, Type => 'SelectSingle', Queue => $queue->id );
ok($status,$msg);
($status,$msg)=$local_cf1->AddValue( Name => 'RecordCustomFieldValues11' );
ok($status,$msg);
($status,$msg)= $local_cf1->AddValue( Name => 'RecordCustomFieldValues12' );
ok($status,$msg);

my $local_cf2 = RT::Model::CustomField->new( $RT::SystemUser );
$local_cf2->create( Name => 'RecordCustomFields2-'.$$, Type => 'SelectSingle', Queue => $queue->id );
$local_cf2->AddValue( Name => 'RecordCustomFieldValues21' );
$local_cf2->AddValue( Name => 'RecordCustomFieldValues22' );

my $global_cf3 = RT::Model::CustomField->new( $RT::SystemUser );
$global_cf3->create( Name => 'RecordCustomFields3-'.$$, Type => 'SelectSingle', Queue => 0 );
$global_cf3->AddValue( Name => 'RecordCustomFieldValues31' );
$global_cf3->AddValue( Name => 'RecordCustomFieldValues32' );

my $local_cf4 = RT::Model::CustomField->new( $RT::SystemUser );
$local_cf4->create( Name => 'RecordCustomFields4', Type => 'SelectSingle', Queue => $queue2->id );
$local_cf4->AddValue( Name => 'RecordCustomFieldValues41' );
$local_cf4->AddValue( Name => 'RecordCustomFieldValues42' );


my @custom_fields = ($local_cf1, $local_cf2, $global_cf3);


$cfs = $ticket->CustomFields;
is( $cfs->count, 3 );

# Check that record has no any CF values yet {{{
$cfvs = $ticket->CustomFieldValues;
is( $cfvs->count, 0 );
is( $ticket->first_custom_field_value, undef );

# CF with ID -1 shouldnt exist at all
$cfvs = $ticket->CustomFieldValues( -1 );
is( $cfvs->count, 0 );
is( $ticket->first_custom_field_value( -1 ), undef );

$cfvs = $ticket->CustomFieldValues( 'SomeUnexpedCustomFieldName' );
is( $cfvs->count, 0 );
is( $ticket->first_custom_field_value( 'SomeUnexpedCustomFieldName' ), undef );

for (@custom_fields) {
	$cfvs = $ticket->CustomFieldValues( $_->id );
	is( $cfvs->count, 0 );

	$cfvs = $ticket->CustomFieldValues( $_->Name );
	is( $cfvs->count, 0 );
	is( $ticket->first_custom_field_value( $_->id ), undef );
	is( $ticket->first_custom_field_value( $_->Name ), undef );
}
# }}}

# try to add field value with fields that do not exist {{{
 ($status, $msg) = $ticket->AddCustomFieldValue( Field => -1 , value => 'foo' );
ok(!$status, "shouldn't add value" );
($status, $msg) = $ticket->AddCustomFieldValue( Field => 'SomeUnexpedCustomFieldName' , value => 'foo' );
ok(!$status, "shouldn't add value" );
# }}}

# {{{
SKIP: {

	skip "TODO: We want fields that are not allowed to set unexpected values", 10;
	for (@custom_fields) {
		($status, $msg) = $ticket->AddCustomFieldValue( Field => $_ , value => 'SomeUnexpectedCFValue' );
		ok( !$status, 'value doesn\'t exist');
	
		($status, $msg) = $ticket->AddCustomFieldValue( Field => $_->id , value => 'SomeUnexpectedCFValue' );
		ok( !$status, 'value doesn\'t exist');
	
		($status, $msg) = $ticket->AddCustomFieldValue( Field => $_->Name , value => 'SomeUnexpectedCFValue' );
		ok( !$status, 'value doesn\'t exist');
	}
	
	# Let check that we did not add value to be sure
	# using only first_custom_field_value sub because
	# we checked other variants allready
	for (@custom_fields) {
		is( $ticket->first_custom_field_value( $_->id ), undef );
	}
	
}
# Add some values to our custom fields
for (@custom_fields) {
	# this should be tested elsewhere
	$_->AddValue( Name => 'Foo' );
	$_->AddValue( Name => 'Bar' );
}

my $test_add_delete_cycle = sub {
	my $cb = shift;
	for (@custom_fields) {
		($status, $msg) = $ticket->AddCustomFieldValue( Field => $cb->($_) , value => 'Foo' );
		ok( $status, "message: $msg");
	}
	
	# does it exist?
	$cfvs = $ticket->CustomFieldValues;
	is( $cfvs->count, 3, "We found all three custom fields on our ticket" );
	for (@custom_fields) {
		$cfvs = $ticket->CustomFieldValues( $_->id );
		is( $cfvs->count, 1 , "we found one custom field when searching by id");
	
		$cfvs = $ticket->CustomFieldValues( $_->Name );
		is( $cfvs->count, 1 , " We found one custom field when searching by name for " . $_->Name);
		is( $ticket->first_custom_field_value( $_->id ), 'Foo' , "first value by id is foo");
		is( $ticket->first_custom_field_value( $_->Name ), 'Foo' , "first value by name is foo");

	}
	# because our CFs are SingleValue then new value addition should override
	for (@custom_fields) {
		($status, $msg) = $ticket->AddCustomFieldValue( Field => $_ , value => 'Bar' );
		ok( $status, "message: $msg");
	}
	$cfvs = $ticket->CustomFieldValues;
	is( $cfvs->count, 3 );
	for (@custom_fields) {
		$cfvs = $ticket->CustomFieldValues( $_->id );
		is( $cfvs->count, 1 );
	
		$cfvs = $ticket->CustomFieldValues( $_->Name );
		is( $cfvs->count, 1 );
		is( $ticket->first_custom_field_value( $_->id ), 'Bar' );
		is( $ticket->first_custom_field_value( $_->Name ), 'Bar' );
	}
	# delete it
	for (@custom_fields ) { 
		($status, $msg) = $ticket->delete_custom_field_value( Field => $_ , Value => 'Bar' );
		ok( $status, "Deleted a custom field value 'Bar' for field ".$_->id.": $msg");
	}
	$cfvs = $ticket->CustomFieldValues;
	is( $cfvs->count, 0, "The ticket (".$ticket->id.") no longer has any custom field values"  );
	for (@custom_fields) {
		$cfvs = $ticket->CustomFieldValues( $_->id );
		is( $cfvs->count, 0,  $ticket->id." has no values for cf  ".$_->id );
	
		$cfvs = $ticket->CustomFieldValues( $_->Name );
		is( $cfvs->count, 0 , $ticket->id." has no values for cf  '".$_->Name. "'" );
		is( $ticket->first_custom_field_value( $_->id ), undef , "There is no first custom field value when loading by id" );
		is( $ticket->first_custom_field_value( $_->Name ), undef, "There is no first custom field value when loading by Name" );
	}
};

# lets test cycle via CF id
$test_add_delete_cycle->( sub { return $_[0]->id } );
# lets test cycle via CF object reference
$test_add_delete_cycle->( sub { return $_[0] } );

$ticket->AddCustomFieldValue( Field => $local_cf2->id , value => 'Baz' );
$ticket->AddCustomFieldValue( Field => $global_cf3->id , value => 'Baz' );
# now if we ask for cf values on RecordCustomFields4 we should not get any
$cfvs = $ticket->CustomFieldValues( 'RecordCustomFields4' );
is( $cfvs->count, 0, "No custom field values for non-Queue cf" );
is( $ticket->first_custom_field_value( 'RecordCustomFields4' ), undef, "No first custom field value for non-Queue cf" );


#SKIP: {
#	skip "TODO: should we add CF values to objects via CF Name?", 48;
# names are not unique
	# lets test cycle via CF Name
#	$test_add_delete_cycle->( sub { return $_[0]->Name } );
#}


