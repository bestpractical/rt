

use strict;
use warnings FATAL => 'all';

use RT::Test nodata => 1, tests => undef;
use Test::Warn;

# Before we get going, ditch all object_cfs; this will remove
# all custom fields systemwide;
my $object_cfs = RT::ObjectCustomFields->new(RT->SystemUser);
$object_cfs->UnLimit();
while (my $ocf = $object_cfs->Next) {
    $ocf->Delete();
}


my $queue = RT::Queue->new( RT->SystemUser );
$queue->Create( Name => 'RecordCustomFields-'.$$ );
ok ($queue->id, "Created the queue");

my $queue2 = RT::Queue->new( RT->SystemUser );
$queue2->Create( Name => 'RecordCustomFields2' );

my $ticket = RT::Ticket->new( RT->SystemUser );
$ticket->Create(
    Queue => $queue->Id,
    Requestor => 'root@localhost',
    Subject => 'RecordCustomFields1',
);

my $cfs = $ticket->CustomFields;
is( $cfs->Count, 0 );

# Check that record has no any CF values yet
my $cfvs = $ticket->CustomFieldValues;
is( $cfvs->Count, 0 );
is( $ticket->FirstCustomFieldValue, undef );

my $local_cf1 = RT::CustomField->new( RT->SystemUser );
$local_cf1->Create( Name => 'RecordCustomFields1-'.$$, Type => 'SelectSingle', Queue => $queue->id );
$local_cf1->AddValue( Name => 'RecordCustomFieldValues11' );
$local_cf1->AddValue( Name => 'RecordCustomFieldValues12' );

my $local_cf2 = RT::CustomField->new( RT->SystemUser );
$local_cf2->Create( Name => 'RecordCustomFields2-'.$$, Type => 'SelectSingle', Queue => $queue->id );
$local_cf2->AddValue( Name => 'RecordCustomFieldValues21' );
$local_cf2->AddValue( Name => 'RecordCustomFieldValues22' );

my $global_cf3 = RT::CustomField->new( RT->SystemUser );
$global_cf3->Create( Name => 'RecordCustomFields3-'.$$, Type => 'SelectSingle', Queue => 0 );
$global_cf3->AddValue( Name => 'RecordCustomFieldValues31' );
$global_cf3->AddValue( Name => 'RecordCustomFieldValues32' );

my $local_cf4 = RT::CustomField->new( RT->SystemUser );
$local_cf4->Create( Name => 'RecordCustomFields4', Type => 'SelectSingle', Queue => $queue2->id );
$local_cf4->AddValue( Name => 'RecordCustomFieldValues41' );
$local_cf4->AddValue( Name => 'RecordCustomFieldValues42' );


my @custom_fields = ($local_cf1, $local_cf2, $global_cf3);


$cfs = $ticket->CustomFields;
is( $cfs->Count, 3 );

# Check that record has no any CF values yet
$cfvs = $ticket->CustomFieldValues;
is( $cfvs->Count, 0 );
is( $ticket->FirstCustomFieldValue, undef );

# CF with ID -1 shouldnt exist at all
warning_like {
    $cfvs = $ticket->CustomFieldValues( -1 );
} qr{Couldn't load custom field};
is( $cfvs->Count, 0 );
warning_like {
    is( $ticket->FirstCustomFieldValue( -1 ), undef );
} qr{Couldn't load custom field};

warning_like {
    $cfvs = $ticket->CustomFieldValues( 'SomeUnexpedCustomFieldName' );
} qr{Couldn't load custom field};
is( $cfvs->Count, 0 );
warning_like {
    is( $ticket->FirstCustomFieldValue( 'SomeUnexpedCustomFieldName' ), undef );
} qr{Couldn't load custom field};

for (@custom_fields) {
    $cfvs = $ticket->CustomFieldValues( $_->id );
    is( $cfvs->Count, 0 );

    $cfvs = $ticket->CustomFieldValues( $_->Name );
    is( $cfvs->Count, 0 );
    is( $ticket->FirstCustomFieldValue( $_->id ), undef );
    is( $ticket->FirstCustomFieldValue( $_->Name ), undef );
}

# try to add field value with fields that do not exist
my ($status, $msg) = $ticket->AddCustomFieldValue( Field => -1 , Value => 'foo' );
ok(!$status, "shouldn't add value" );
($status, $msg) = $ticket->AddCustomFieldValue( Field => 'SomeUnexpedCustomFieldName' , Value => 'foo' );
ok(!$status, "shouldn't add value" );

SKIP: {

    skip "TODO: We want fields that are not allowed to set unexpected values", 10;
    for (@custom_fields) {
        ($status, $msg) = $ticket->AddCustomFieldValue( Field => $_ , Value => 'SomeUnexpectedCFValue' );
        ok( !$status, 'value doesn\'t exist');

        ($status, $msg) = $ticket->AddCustomFieldValue( Field => $_->id , Value => 'SomeUnexpectedCFValue' );
        ok( !$status, 'value doesn\'t exist');

        ($status, $msg) = $ticket->AddCustomFieldValue( Field => $_->Name , Value => 'SomeUnexpectedCFValue' );
        ok( !$status, 'value doesn\'t exist');
    }

    # Let check that we did not add value to be sure
    # using only FirstCustomFieldValue sub because
    # we checked other variants allready
    for (@custom_fields) {
        is( $ticket->FirstCustomFieldValue( $_->id ), undef );
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
        ($status, $msg) = $ticket->AddCustomFieldValue( Field => $cb->($_) , Value => 'Foo' );
        ok( $status, "message: $msg");
    }

    # does it exist?
    $cfvs = $ticket->CustomFieldValues;
    is( $cfvs->Count, 3, "We found all three custom fields on our ticket" );
    for (@custom_fields) {
        $cfvs = $ticket->CustomFieldValues( $_->id );
        is( $cfvs->Count, 1 , "we found one custom field when searching by id");

        $cfvs = $ticket->CustomFieldValues( $_->Name );
        is( $cfvs->Count, 1 , " We found one custom field when searching by name for " . $_->Name);
        is( $ticket->FirstCustomFieldValue( $_->id ), 'Foo' , "first value by id is foo");
        is( $ticket->FirstCustomFieldValue( $_->Name ), 'Foo' , "first value by name is foo");
    }
    # because our CFs are SingleValue then new value addition should override
    for (@custom_fields) {
        ($status, $msg) = $ticket->AddCustomFieldValue( Field => $_ , Value => 'Bar' );
        ok( $status, "message: $msg");
    }
    $cfvs = $ticket->CustomFieldValues;
    is( $cfvs->Count, 3 );
    for (@custom_fields) {
        $cfvs = $ticket->CustomFieldValues( $_->id );
        is( $cfvs->Count, 1 );

        $cfvs = $ticket->CustomFieldValues( $_->Name );
        is( $cfvs->Count, 1 );
        is( $ticket->FirstCustomFieldValue( $_->id ), 'Bar' );
        is( $ticket->FirstCustomFieldValue( $_->Name ), 'Bar' );
    }
    # delete it
    for (@custom_fields ) {
        ($status, $msg) = $ticket->DeleteCustomFieldValue( Field => $_ , Value => 'Bar' );
        ok( $status, "Deleted a custom field value 'Bar' for field ".$_->id.": $msg");
    }
    $cfvs = $ticket->CustomFieldValues;
    is( $cfvs->Count, 0, "The ticket (".$ticket->id.") no longer has any custom field values"  );
    for (@custom_fields) {
        $cfvs = $ticket->CustomFieldValues( $_->id );
        is( $cfvs->Count, 0,  $ticket->id." has no values for cf  ".$_->id );

        $cfvs = $ticket->CustomFieldValues( $_->Name );
        is( $cfvs->Count, 0 , $ticket->id." has no values for cf  '".$_->Name. "'" );
        is( $ticket->FirstCustomFieldValue( $_->id ), undef , "There is no first custom field value when loading by id" );
        is( $ticket->FirstCustomFieldValue( $_->Name ), undef, "There is no first custom field value when loading by Name" );
    }
};

# lets test cycle via CF id
$test_add_delete_cycle->( sub { return $_[0]->id } );
# lets test cycle via CF object reference
$test_add_delete_cycle->( sub { return $_[0] } );

$ticket->AddCustomFieldValue( Field => $local_cf2->id , Value => 'Baz' );
$ticket->AddCustomFieldValue( Field => $global_cf3->id , Value => 'Baz' );
# now if we ask for cf values on RecordCustomFields4 we should not get any
warning_like {
    $cfvs = $ticket->CustomFieldValues( 'RecordCustomFields4' );
} qr{Couldn't load custom field};
is( $cfvs->Count, 0, "No custom field values for non-Queue cf" );
warning_like {
    is( $ticket->FirstCustomFieldValue( 'RecordCustomFields4' ), undef, "No first custom field value for non-Queue cf" );
} qr{Couldn't load custom field};

{
    my $cfname = $global_cf3->Name;
    ($status, $msg) = $global_cf3->SetDisabled(1);
    ok($status, "Disabled CF named $cfname");

    my $load = RT::CustomField->new( RT->SystemUser );
    $load->LoadByName( Name => $cfname);
    ok($load->Id, "Loaded CF named $cfname");
    is($load->Id, $global_cf3->Id, "Can load disabled CFs");

    my $dup = RT::CustomField->new( RT->SystemUser );
    $dup->Create( Name => $cfname, Type => 'SelectSingle', Queue => 0 );
    ok($dup->Id, "Created CF with duplicate name");

    $load->LoadByName( Name => $cfname);
    is($load->Id, $dup->Id, "Loading by name gets non-disabled first");

    $dup->SetDisabled(1);
    $global_cf3->SetDisabled(0);

    $load->LoadByName( Name => $cfname);
    is($load->Id, $global_cf3->Id, "Loading by name gets non-disabled first, even with order swapped");
}

{
    my $cf = RT::Test->load_or_create_custom_field(
        Name  => 'HasEntry cache',
        Type  => 'FreeformSingle',
        Queue => 0,
    );

    my ( $ret, $msg ) = $ticket->AddCustomFieldValue( Field => $cf, Value => 'foo' );
    ok( $ret, $msg );
    is( $ticket->FirstCustomFieldValue( $cf ), 'foo', 'value is foo' );
    my $ocfvs = $ticket->CustomFieldValues( $cf );
    ok( $ocfvs->HasEntry( 'foo' ), 'foo is cached in HasEntry' );

    ( $ret, $msg ) = $ticket->AddCustomFieldValue( Field => $cf, Value => 'bar' );
    ok( $ret, $msg );
    is( $ticket->FirstCustomFieldValue( $cf ), 'bar', 'value is bar' );
    ok( !$ocfvs->HasEntry( 'foo' ), 'foo is not cached in HasEntry' );
    ok( $ocfvs->HasEntry( 'bar' ),  'bar is cached in HasEntry' );

    ( $ret, $msg ) = $ticket->AddCustomFieldValue( Field => $cf, Value => 'foo' );
    ok( $ret, $msg );
    is( $ticket->FirstCustomFieldValue( $cf ), 'foo', 'value is foo' );
    ok( $ocfvs->HasEntry( 'foo' ),  'foo is cached in HasEntry' );
    ok( !$ocfvs->HasEntry( 'bar' ), 'bar is not cached in HasEntry' );
}

#SKIP: {
#       skip "TODO: should we add CF values to objects via CF Name?", 48;
# names are not unique
        # lets test cycle via CF Name
#       $test_add_delete_cycle->( sub { return $_[0]->Name } );
#}

# These represent adding the custom field to all objects
my $all_queues = RT::Queue->new( RT->SystemUser );
my $all_classes = RT::Class->new( RT->SystemUser );

# Queue CustomField Message Test
{
    my $queue = RT::Queue->new( RT->SystemUser );
    $queue->Create( Name => 'queue_name_0' );

    my $custom_field = RT::CustomField->new( RT->SystemUser );
    $custom_field->Create( Name => 'custom_field_0', Type => 'SelectSingle', LookupType => 'RT::Queue' );

    my ($status, $msg) = $custom_field->AddToObject( $queue );
    is($msg, 'Added custom field custom_field_0 to queue_name_0.', "Adding custom field to queue produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $queue );
    is($msg, 'Removed custom field custom_field_0 from queue_name_0.', "Removing custom field from queue produces appropriate message");

    ($status, $msg) = $custom_field->AddToObject( $all_queues );
    is($msg, 'Globally added custom field custom_field_0.', "Adding custom field globally produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $all_queues );
    is($msg, 'Globally removed custom field custom_field_0.', "Rmeoving custom field globally produces appropriate message");
}

# Ticket CustomField Message Test
{
    my $queue = RT::Queue->new( RT->SystemUser );
    $queue->Create( Name => 'queue_name_1' );

    my $custom_field = RT::CustomField->new( RT->SystemUser );
    $custom_field->Create( Name => 'custom_field_1', Type => 'SelectSingle', LookupType => 'RT::Queue-RT::Ticket' );

    my ($status, $msg) = $custom_field->AddToObject( $queue );
    is($msg, 'Added custom field custom_field_1 to queue_name_1.', "Adding custom field to queue-ticket produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $queue );
    is($msg, 'Removed custom field custom_field_1 from queue_name_1.', "Removing custom field from queue produces appropriate message");

    ($status, $msg) = $custom_field->AddToObject( $all_queues );
    is($msg, 'Globally added custom field custom_field_1.', "Adding custom field globally produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $all_queues );
    is($msg, 'Globally removed custom field custom_field_1.', "Removing custom field globally produces appropriate message");
}

# Class CustomField Message Test
{
    my $class = RT::Class->new( RT->SystemUser );
    $class->Create( Name => 'class_name_0' );

    my $custom_field = RT::CustomField->new( RT->SystemUser );
    $custom_field->Create( Name => 'custom_field_2', Type => 'SelectSingle', LookupType => 'RT::Class-RT::Article' );

    my ($status, $msg) = $custom_field->AddToObject( $class );
    is($msg, 'Added custom field custom_field_2 to class_name_0.', "Adding custom field to class-ticket produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $class );
    is($msg, 'Removed custom field custom_field_2 from class_name_0.', "Remove custom field from class produces appropriate message");

    ($status, $msg) = $custom_field->AddToObject( $all_classes );
    is($msg, 'Globally added custom field custom_field_2.', "Adding custom field globally produces appropriate message");

    ($status, $msg) = $custom_field->RemoveFromObject( $all_classes );
    is($msg, 'Globally removed custom field custom_field_2.', "Removing custom field globally produces appropriate message");
}

done_testing;
