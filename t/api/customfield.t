
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 25;
use RT;


{

use_ok('RT::Model::CustomField');
ok(my $cf = RT::Model::CustomField->new(current_user => RT->system_user));
ok(my ($id, $msg)=  $cf->create( name => 'TestingCF',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field',
                                 type=> 'SelectSingle'), 'Created a global CustomField');
isnt($id , 0, 'Global custom field correctly Created');
ok ($cf->single_value);
is($cf->type, 'Select');
is($cf->MaxValues, 1);

(my $val, $msg) = $cf->set_MaxValues('0');
ok($val, $msg);
is($cf->type, 'Select');
ok(!$cf->MaxValues);
ok(!$cf->single_value );
ok(my ($bogus_val, $bogus_msg) = $cf->set_type('BogusType') , "Trying to set a custom field's type to a bogus type");
is($bogus_val , 0, "Unable to set a custom field's type to a bogus type");

ok(my $bad_cf = RT::Model::CustomField->new(current_user => RT->system_user));
ok(my ($bad_id, $bad_msg)=  $cf->create( name => 'TestingCF-bad',
                                 Queue => '0',
                                 SortOrder => '1',
                                 Description => 'A Testing custom field with a bogus Type',
                                 type=> 'SelectSingleton'), 'Created a global CustomField with a bogus type');
is($bad_id , 0, 'Global custom field correctly decided to not create a cf with a bogus type ');


}

{

ok(my $cf = RT::Model::CustomField->new(current_user => RT->system_user));
$cf->load(1);
is($cf->id , 1);
ok(my ($val,$msg)  = $cf->add_value(name => 'foo' , Description => 'TestCFValue', SortOrder => '6'));
isnt($val , 0);
ok (my ($delval, $delmsg) = $cf->delete_value($val));
ok ($delval,"Deleting a cf value: $delmsg");


}

{

ok(my $cf = RT::Model::CustomField->new(current_user => RT->system_user));
 ok($cf->validate_type('Select'));
 ok(!$cf->validate_type('SelectFoo'));
 
}

1;
