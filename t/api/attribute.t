
use strict;
use warnings;
use RT;
use RT::Test nodata => 1, tests => 7;


{

my $user = RT->SystemUser;
my ($id, $msg) =  $user->AddAttribute(Name => 'SavedSearch', Content => { Query => 'Foo'} );
ok ($id, $msg);
my $attr = RT::Attribute->new(RT->SystemUser);
$attr->Load($id);
is($attr->Name , 'SavedSearch');
$attr->SetSubValues( Format => 'baz');

my $format = $attr->SubValue('Format');
is ($format , 'baz');

$attr->SetSubValues( Format => 'bar');
$format = $attr->SubValue('Format');
is ($format , 'bar');

$attr->DeleteAllSubValues();
$format = $attr->SubValue('Format');
is ($format, undef);

$attr->SetSubValues(Format => 'This is a format');

my $attr2 = RT::Attribute->new(RT->SystemUser);
$attr2->Load($id);
is ($attr2->SubValue('Format'), 'This is a format');
$attr2->Delete;
my $attr3 = RT::Attribute->new(RT->SystemUser);
($id) = $attr3->Load($id);
is ($id, 0);


}

