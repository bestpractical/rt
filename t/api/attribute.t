
use strict;
use warnings;
use Test::More; 
plan tests => 7;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $user = $RT::SystemUser;
my ($id, $msg) =  $user->AddAttribute(Name => 'SavedSearch', Content => { Query => 'Foo'} );
ok ($id, $msg);
my $attr = RT::Attribute->new($RT::SystemUser);
$attr->Load($id);
ok($attr->Name eq 'SavedSearch');
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

my $attr2 = RT::Attribute->new($RT::SystemUser);
$attr2->Load($id);
is ($attr2->SubValue('Format'), 'This is a format');
$attr2->Delete;
my $attr3 = RT::Attribute->new($RT::SystemUser);
($id) = $attr3->Load($id);
is ($id, 0);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
