
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;



my $user = RT->SystemUser;
my ($id, $msg) =  $user->add_attribute(Name => 'SavedSearch', Content => { Query => 'Foo'} );
ok ($id, $msg);
my $attr = RT::Model::Attribute->new(RT->SystemUser);
$attr->load($id);
is($attr->Name , 'SavedSearch');
$attr->set_SubValues( Format => 'baz');

my $format = $attr->SubValue('Format');
is ($format , 'baz');

$attr->set_SubValues( Format => 'bar');
$format = $attr->SubValue('Format');
is ($format , 'bar');

$attr->deleteAllSubValues();
$format = $attr->SubValue('Format');
is ($format, undef);

$attr->set_SubValues(Format => 'This is a format');

my $attr2 = RT::Model::Attribute->new(RT->SystemUser);
$attr2->load($id);
is ($attr2->SubValue('Format'), 'This is a format');
$attr2->delete;
my $attr3 = RT::Model::Attribute->new(RT->SystemUser);
($id) = $attr3->load($id);
is ($id, 0);



1;
