
use strict;
use warnings;
use RT;
use RT::Test tests => 29;
use Test::Warn;


{

use_ok('RT::CustomField');
ok(my $cf = RT::CustomField->new($RT::SystemUser));
ok(my ($id, $msg)=  $cf->Create( Name => 'TestingCF',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field',
                                 Type=> 'SelectSingle'), 'Created a global CustomField');
isnt($id , 0, 'Global custom field correctly created');
ok ($cf->SingleValue);
is($cf->Type, 'Select');
is($cf->MaxValues, 1);

(my $val, $msg) = $cf->SetMaxValues('0');
ok($val, $msg);
is($cf->Type, 'Select');
is($cf->MaxValues, 0);
ok(!$cf->SingleValue );
ok(my ($bogus_val, $bogus_msg) = $cf->SetType('BogusType') , "Trying to set a custom field's type to a bogus type");
is($bogus_val , 0, "Unable to set a custom field's type to a bogus type");

ok(my $bad_cf = RT::CustomField->new($RT::SystemUser));
ok(my ($bad_id, $bad_msg)=  $cf->Create( Name => 'TestingCF-bad',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field with a bogus Type',
                                 Type=> 'SelectSingleton'), 'Created a global CustomField with a bogus type');
is($bad_id , 0, 'Global custom field correctly decided to not create a cf with a bogus type ');


}

{

ok(my $cf = RT::CustomField->new($RT::SystemUser));
$cf->Load(1);
is($cf->Id , 1);
ok(my ($val,$msg)  = $cf->AddValue(Name => 'foo' , Description => 'TestCFValue', SortOrder => '6'));
isnt($val , 0);
ok (my ($delval, $delmsg) = $cf->DeleteValue($val));
ok ($delval,"Deleting a cf value: $delmsg");


}

{

ok(my $cf = RT::CustomField->new($RT::SystemUser));

warning_like {
ok($cf->ValidateType('SelectSingle'));
} qr/deprecated/;

warning_like {
ok($cf->ValidateType('SelectMultiple'));
} qr/deprecated/;

warning_like {
ok(!$cf->ValidateType('SelectFooMultiple'));
} qr/deprecated/;


}

1;
