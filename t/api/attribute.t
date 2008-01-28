
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;



my $user = RT->system_user;
my ($id, $msg) =  $user->user_object->add_attribute(name => 'SavedSearch', Content => { Query => 'Foo'} );
ok ($id, $msg);
my $attr = RT::Model::Attribute->new(current_user => RT->system_user);
$attr->load($id);
is($attr->name , 'SavedSearch');
$attr->set_sub_values( Format => 'baz');

my $format = $attr->sub_value('Format');
is ($format , 'baz');

$attr->set_sub_values( Format => 'bar');
$format = $attr->sub_value('Format');
is ($format , 'bar');

$attr->delete_all_sub_values();
$format = $attr->sub_value('Format');
is ($format, undef);

$attr->set_sub_values(Format => 'This is a format');

my $attr2 = RT::Model::Attribute->new(current_user => RT->system_user);
$attr2->load($id);
is ($attr2->sub_value('Format'), 'This is a format');
$attr2->delete;
my $attr3 = RT::Model::Attribute->new(current_user => RT->system_user);
($id) = $attr3->load($id);
is ($id, 0);



1;
