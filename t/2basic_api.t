#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw/no_plan/;


use_ok('RT');
RT::LoadConfig();
RT::Init();

use_ok('RT::FM::Class');

my $class = RT::FM::Class->new($RT::SystemUser);
isa_ok($class, 'RT::FM::Class');
isa_ok($class, 'RT::FM::Record');
isa_ok($class, 'RT::Record');


my $name = 'test-'.$$;
my ($id,$msg) = $class->Create( Name =>$name, Description => 'Test class');
ok($id,$msg);
is ($class->Name, $name);
is ($class->Description, 'Test class');



# Test custom fields.

can_ok($class, 'CustomFields');
can_ok($class, 'AddCustomFieldValue');
can_ok($class, 'DeleteCustomFieldValue');
can_ok($class, 'FirstCustomFieldValue');
can_ok($class, 'CustomFieldValues');


# Add a custom field to our class
my $cf = RT::CustomField->new($RT::SystemUser);
isa_ok($cf, 'RT::CustomField');

($id,$msg) = $cf->Create( Name => 'FM::Sample-'.$$,
             Description => 'Test text cf',
             LookupType => RT::FM::Class->_LookupTypes,
             Type => 'Text'
             );



ok($id,$msg);


($id,$msg) = $cf->AddToObject($class);
ok ($id,$msg);


# Does our class have a custom field?

my $cfs = $class->CustomFields;
isa_ok($cfs, 'RT::CustomFields');
is($cfs->Count, 1, "We only have one custom field");
my $found_cf = $cfs->First;
is ($cf->id, $found_cf->id, "it's the right one");

($id,$msg) = $cf->RemoveFromObject($class);

is($class->CustomFields->Count, 0, "All gone!");

# Put it back. we want to go forward.

($id,$msg) = $cf->AddToObject($class);
ok ($id,$msg);




use_ok('RT::FM::Article');

my $art = RT::FM::Article->new($RT::SystemUser);
($id,$msg) =$art->Create(Class => $class->id,
             Name => 'Sample'.$$,
             Description => 'A sample article');

ok($id,"Created article ".$id." - " .$msg);

# make sure there is one transaction.

my $txns = $art->Transactions;

is($txns->Count, 1, "One txn");
my $txn = $txns->First;
is ($txn->ObjectType, 'RT::FM::Article');
is ($txn->ObjectId , $id ,  "It's the right article");
is ($txn->Type, 'Create', "It's a create!");


# Test some custom fields

