
use strict;
use warnings;
use RT;
use RT::Test tests => undef;
use Test::Warn;

use_ok('RT::CustomField');

my $queue = RT::Queue->new( RT->SystemUser );
$queue->Load( "General" );
ok( $queue->id, "found the General queue" );

my $cf = RT::CustomField->new(RT->SystemUser);
ok($cf, "Have a CustomField object");

# Use the old Queue field to set up a ticket CF
my ($ok, $msg) =  $cf->Create(
    Name        => 'TestingCF',
    Queue       => '0',
    Description => 'A Testing custom field',
    Type        => 'SelectSingle'
);
ok($ok, 'Global custom field correctly created');
is($cf->Type, 'Select', "Is a select CF");
ok($cf->SingleValue, "Also a single-value CF");
is($cf->MaxValues, 1, "...meaning only one value, max");

for my $value (qw/first second third forth fifth/) {
    ( $ok, $msg ) = $cf->AddValue( Name => "$value value" );
    ok( $ok, "Add $value to values: $msg" );
}

($ok, $msg) = $cf->SetMaxValues('0');
ok($ok, "Set to infinite values: $msg");
is($cf->Type, 'Select', "Still a select CF");
ok( ! $cf->SingleValue, "No longer single-value" );
is($cf->MaxValues, 0, "...meaning no maximum values");

# Test our sanity checking of CF types
($ok, $msg) = $cf->SetType('BogusType');
ok( ! $ok, "Unable to set a custom field's type to a bogus type: $msg");

$cf = RT::CustomField->new(RT->SystemUser);
($ok, $msg) = $cf->Create(
    Name => 'TestingCF-bad',
    Queue => '0',
    SortOrder => '1',
    Description => 'A Testing custom field with a bogus Type',
    Type=> 'SelectSingleton'
);
ok( ! $ok, "Correctly could not create with bogus type: $msg");

# Test adding and removing CFVs
$cf->Load(2);
($ok, $msg) = $cf->AddValue(Name => 'foo' , Description => 'TestCFValue', SortOrder => '6');
ok($ok, "Added a new value to the select options");
($ok, $msg) = $cf->DeleteValue($ok);
ok($ok, "Deleting it again");


# Loading, and context objects
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName( Name => "TestingCF" );
ok($cf->id, "Load finds it, given just a name" );
ok( ! $cf->ContextObject, "Did not get a context object");

# Old Queue => form should find the global, gain no context object
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0);
ok($cf->id, "Load finds it, given a Name and Queue => 0" );
ok( ! $cf->ContextObject, 'Context object not set when queue is 0');

# We don't default to also searching global -- but do pick up a contextobject
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1);
ok( ! $cf->id, "Load does not finds it, given a Name and Queue => 1" );
ok($cf->ContextObject->id, 'Context object is now set');

# If we IncludeGlobal, we find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeGlobal => 1 );
ok($cf->id, "Load now finds it, given a Name and Queue => 1 and IncludeGlobal" );
ok($cf->ContextObject->id, 'Context object is also set');

# The explicit LookupType works
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType );
ok($cf->id, "Load now finds it, given a Name and LookupType" );
ok( ! $cf->ContextObject, 'No context object gained');

# The explicit LookupType, ObjectId, and IncludeGlobal -- what most folks want
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType,
                ObjectId => 1, IncludeGlobal => 1 );
ok($cf->id, "Load now finds it, given a Name, LookupType, ObjectId, IncludeGlobal" );
ok($cf->ContextObject->id, 'And gains a context obj');

# Look for a queue by name
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => "General" );
ok( ! $cf->id, "No IncludeGlobal, so queue by name fails" );
ok($cf->ContextObject->id, 'But gains a context object');

# Look for a queue by name, include global
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => "General", IncludeGlobal => 1 );
ok($cf->id, "By name, and queue name works with IncludeGlobal" );
ok($cf->ContextObject->id, 'And gains a context object');



# A bogus Queue gets you no results, but a warning
$cf = RT::CustomField->new( RT->SystemUser );
warning_like {
    $cf->LoadByName(Name => 'TestingCF', Queue => "Bogus" );
    ok( ! $cf->id, "With a bogus queue name gets no results" );
    ok( ! $cf->ContextObject, 'And also no context object');
} qr/Failed to load RT::Queue 'Bogus'/, "Generates a warning";

# Ditto by number which is bogus
$cf = RT::CustomField->new( RT->SystemUser );
warning_like {
    $cf->LoadByName(Name => 'TestingCF', Queue => "9000" );
    ok( ! $cf->id, "With a bogus queue number gets no results" );
    ok( ! $cf->ContextObject, 'And also no context object');
} qr/Failed to load RT::Queue '9000'/, "Generates a warning";

# But if they also wanted global results, we might have an answer
$cf = RT::CustomField->new( RT->SystemUser );
warning_like {
    $cf->LoadByName(Name => 'TestingCF', Queue => "9000", IncludeGlobal => 1 );
    ok($cf->id, "Bogus queue but IncludeGlobal founds it" );
    ok( ! $cf->ContextObject, 'But no context object');
} qr/Failed to load RT::Queue '9000'/, "And generates a warning";


# Make it only apply to one queue
$cf->Load(2);
my $ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->LoadByCols( CustomField => $cf->id, ObjectId => 0 );
ok( $ok, "Found global application of CF" );
( $ok, $msg ) = $ocf->Delete;
ok( $ok, "...and deleted it");
( $ok, $msg ) = $ocf->Add( CustomField => $cf->id, ObjectId => 1 );
ok($ok, "Applied to just queue 1" );

# Looking for it globally with Queue => 0 should fail, gain no context object
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0);
ok( ! $cf->id, "Load fails to find, given a Name and Queue => 0" );
ok( ! $cf->ContextObject, 'Context object not set when queue is 0');

# Looking it up by Queue => 1 works fine, and gets context object
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1);
ok($cf->id, "Load does finds it, given a Name and Queue => 1" );
ok($cf->ContextObject->id, 'Context object is now set');

# Also find it with IncludeGlobal
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeGlobal => 1 );
ok($cf->id, "Load also finds it, given a Name and Queue => 1 and IncludeGlobal" );
ok($cf->ContextObject->id, 'Context object is also set');

# The explicit LookupType works
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType );
ok($cf->id, "Load also finds it, given a Name and LookupType" );
ok( ! $cf->ContextObject, 'But no context object gained');

# Explicit LookupType, ObjectId works
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType,
                ObjectId => 1 );
ok($cf->id, "Load still finds it, given a Name, LookupType, ObjectId" );
ok($cf->ContextObject->id, 'And gains a context obj');

# Explicit LookupType, ObjectId works
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType,
                ObjectId => 1, IncludeGlobal => 1 );
ok($cf->id, "Load also finds it, given a Name, LookupType, ObjectId, and IncludeGlobal" );
ok($cf->ContextObject->id, 'And gains a context obj');

# Look for a queue by name
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => "General" );
ok($cf->id, "Finds it by queue name" );
ok($cf->ContextObject->id, 'But gains a context object');

# Look for a queue by name, include global
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => "General", IncludeGlobal => 1 );
ok($cf->id, "By name, and queue name works with IncludeGlobal" );
ok($cf->ContextObject->id, 'And gains a context object');




# Change the lookup type to be a _queue_ CF
($ok, $msg) = $cf->SetLookupType( RT::Queue->CustomFieldLookupType );
ok($ok, "Changed CF type to be a CF on queues" );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );

# Just looking by name gets you CFs of any type
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF');
ok($cf->id, "Find the CF by name, with no queue" );

# Queue => 0 means "ticket CF", so doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0);
ok( ! $cf->id, "Wrong lookup type to find with Queue => 0" );

# Queue => 1 and IncludeGlobal also doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0, IncludeGlobal => 1);
ok( ! $cf->id, "Also doesn't find with Queue => 0 and IncludeGlobal" );

# Find it with the right LookupType
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType );
ok($cf->id, "Found for the right lookup type" );

# Found globally
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType, ObjectId => 0 );
ok($cf->id, "Found for the right lookup type and ObjectId 0" );

# Also works with Queue instead of ObjectId
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType, Queue => 0 );
ok($cf->id, "Found for the right lookup type and Queue 0" );

# Not found without IncludeGlobal
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType, ObjectId => 1 );
ok( ! $cf->id, "Not found for ObjectId 1 and no IncludeGlobal" );

# Found with IncludeGlobal
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType,
                ObjectId => 1, IncludeGlobal => 1 );
ok($cf->id, "Found for ObjectId 1 and IncludeGlobal" );

# Found with IncludeGlobal and Queue instead of ObjectId
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Queue->CustomFieldLookupType,
                ObjectId => 1, IncludeGlobal => 1 );
ok($cf->id, "Found for Queue 1 and IncludeGlobal" );



# Change the lookup type to be a _transaction_ CF
($ok, $msg) = $cf->SetLookupType( RT::Transaction->CustomFieldLookupType );
ok($ok, "Changed CF type to be a CF on transactions" );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );

# Just looking by name gets you CFs of any type
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF');
ok($cf->id, "Find the CF by name, with no queue" );

# Queue => 0 means "ticket CF", so doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0);
ok( ! $cf->id, "Wrong lookup type to find with Queue => 0" );

# Queue => 1 and IncludeGlobal also doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0, IncludeGlobal => 1);
ok( ! $cf->id, "Also doesn't find with Queue => 0 and IncludeGlobal" );


# Change the lookup type to be a _user_ CF
$cf->Load(2);
($ok, $msg) = $cf->SetLookupType( RT::User->CustomFieldLookupType );
ok($ok, "Changed CF type to be a CF on users" );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );

# Just looking by name gets you CFs of any type
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF');
ok($cf->id, "Find the CF by name, with no queue" );

# Queue => 0 means "ticket CF", so doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0);
ok( ! $cf->id, "Wrong lookup type to find with Queue => 0" );

# Queue => 1 and IncludeGlobal also doesn't find it
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0, IncludeGlobal => 1);
ok( ! $cf->id, "Also doesn't find with Queue => 0 and IncludeGlobal" );

# But RT::User->CustomFieldLookupType does
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::User->CustomFieldLookupType );
ok($cf->id, "User lookuptype does" );

# Also with an explicit global
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::User->CustomFieldLookupType, ObjectId => 0 );
ok($cf->id, "Also with user CF and explicit global" );



# Add a second, queue-specific CF to test load order
$cf->Load(2);
($ok, $msg) = $cf->SetLookupType( RT::Ticket->CustomFieldLookupType );
ok($ok, "Changed CF type back to be a CF on tickets" );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->Add( CustomField => $cf->id, ObjectId => 0 );
ok($ok, "Applied globally" );
($ok, $msg) = $cf->SetDescription( "Global CF" );
ok($ok, "Changed CF type back to be a CF on tickets" );

($ok, $msg) = $cf->Create(
    Name        => 'TestingCF',
    Queue       => '1',
    Description => 'Queue-specific CF',
    Type        => 'SelectSingle'
);
ok($ok, "Created second CF successfully");

# If passed just a name, you get the first by id
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF' );
like($cf->Description, qr/Global/, "Gets the first (global) one if just loading by name" );

# Ditto if also limited to lookuptype
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', LookupType => RT::Ticket->CustomFieldLookupType );
like($cf->Description, qr/Global/, "Same, if one adds a LookupType" );

# Gets the global with Queue => 0
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 0 );
like($cf->Description, qr/Global/, "Specify Queue => 0 and get global" );

# Gets the queue with Queue => 1
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1 );
like($cf->Description, qr/Queue/, "Specify Queue => 1 and get the queue" );

# Gets the queue with Queue => 1 and IncludeGlobal
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeGlobal => 1 );
like($cf->Description, qr/Queue/, "Specify Queue => 1 and IncludeGlobal and get the queue" );


# Disable one of them
($ok, $msg) = $cf->SetDisabled(1);
is($msg, "Disabled", "Disabling custom field gives correct message");
ok($ok, "Disabled the Queue-specific one");
($ok, $msg) = $cf->SetDisabled(0);
is($msg, "Enabled", "Enabling custom field gives correct message");
ok($ok, "Enabled the Queue-specific one");
($ok, $msg) = $cf->SetDisabled(1);
is($msg, "Disabled", "Disabling custom field again gives correct message");
ok($ok, "Disabled the Queue-specific one again");

# With just a name, prefers the non-disabled
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF' );
like($cf->Description, qr/Global/, "Prefers non-disabled CFs" );

# Still finds the queue one, if asked
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1 );
like($cf->Description, qr/Queue/, "Still loads the disabled queue CF" );

# Prefers the global one if IncludeGlobal
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeGlobal => 1 );
like($cf->Description, qr/Global/, "Prefers the global one with IncludeGlobal" );

# IncludeDisabled allows filtering out the disabled one
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeDisabled => 0 );
ok( ! $cf->id, "Doesn't find it if IncludeDisabled => 0" );

$cf->LoadByName( Name => 'TestingCF', Queue => 0, IncludeGlobal => 1 );
is( $cf->MaxValues, 0, 'Max value is 0' );
my $ticket = RT::Test->create_ticket( Queue => 1, Subject => 'test cf values' );
ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'first value' ) );
ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'second value' ) );

my $cf_values = $cf->ValuesForObject($ticket);
is( $cf_values->Count, 2, 'Found 2 values' );
is( $ticket->CustomFieldValuesAsString( $cf, Separator => ', ' ), 'first value, second value', 'Current cf contents' );

($ok, $msg) = $cf->SetMaxValues(1);
is( $cf->MaxValues, 1, 'Max value is 1' );
ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'third value' ) );

$cf_values = $cf->ValuesForObject($ticket);
is( $cf_values->Count, 1, 'Found 1 value' );
is( $ticket->CustomFieldValuesAsString( $cf, Separator => ', ' ), 'third value', 'Current cf contents' );

($ok, $msg) = $cf->SetMaxValues(2);
is( $cf->MaxValues, 2, 'Max value is 2' );
ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'forth value' ) );

$cf_values = $cf->ValuesForObject($ticket);
is( $cf_values->Count, 2, 'Found 2 values' );
is( $ticket->CustomFieldValuesAsString( $cf, Separator => ', ' ), 'third value, forth value', 'Current cf contents' );

ok( $ticket->AddCustomFieldValue( Field => $cf, Value => 'fifth value' ) );
$cf_values = $cf->ValuesForObject($ticket);
is( $cf_values->Count, 2, 'Found 2 values' );
is( $ticket->CustomFieldValuesAsString( $cf, Separator => ', ' ), 'forth value, fifth value', 'Current cf contents' );

$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF', Queue => 1, IncludeDisabled => 1 );
($ok, $msg) = $cf->SetDisabled(0);
ok($ok, "Re-enabled CF " . $cf->Name);

diag 'Test sort ordering when disabling and re-enabling CFs';

# Create more CFs
foreach my $i (2..5) {
    ($ok, $msg) = $cf->Create(
        Name        => "TestingCF$i",
        Queue       => '0',
        Description => 'Global CF',
        Type        => 'SelectSingle'
    );
    ok($ok, "Created " . $cf->Name . " successfully");

    $ocf = RT::ObjectCustomField->new( RT->SystemUser );
    ( $ok, $msg ) = $ocf->LoadByCols( CustomField => $cf->id, ObjectId => 0 );
    ok( $ok, "Found OCF " . $ocf->Id);
    is( $ocf->SortOrder, $i, "Sort order is $i for OCF " . $ocf->Id);
}

diag 'Disable TestingCF4';
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF4', Queue => 0 );
($ok, $msg) = $cf->SetDisabled(1);
ok($ok, "Disabled " . $cf->Name);

diag 'MoveUp TestingCF5';
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF5', Queue => 0 );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->LoadByCols( CustomField => $cf->id, ObjectId => 0 );
ok( $ok, "Found OCF " . $ocf->Id . " for " . $cf->Name );
is( $ocf->SortOrder, 5, 'Sort order before MoveUp');
$ocf->MoveUp;
is( $ocf->SortOrder, 3, 'Sort order after MoveUp');

$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF3', Queue => 0 );
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->LoadByCols( CustomField => $cf->id, ObjectId => 0 );
ok( $ok, "Found OCF " . $ocf->Id . " for " . $cf->Name );
is( $ocf->SortOrder, 4, 'Sort order is 4 for OCF ' . $ocf->Id);


# Sort order should become 5 when re-enabled and not stay at 4
$cf = RT::CustomField->new( RT->SystemUser );
$cf->LoadByName(Name => 'TestingCF4', Queue => 0 );
($ok, $msg) = $cf->SetDisabled(0);
ok($ok, "Re-enabled " . $cf->Name);
$ocf = RT::ObjectCustomField->new( RT->SystemUser );
( $ok, $msg ) = $ocf->LoadByCols( CustomField => $cf->id, ObjectId => 0 );
ok( $ok, "Found OCF for " . $cf->Name );
is( $ocf->SortOrder, 5, 'Sort order is 5, CF moved to bottom of list on re-enable');

done_testing;
