
use Test::More tests => 24;
use RT;
RT::LoadConfig();
RT::Init();


my $runid = rand(200);

my $attribute = "squelch-$runid";

ok(require RT::Attributes);

my $user = RT::User->new($RT::SystemUser);
ok (UNIVERSAL::isa($user, 'RT::User'));
my ($id,$msg)  = $user->Create(Name => 'attrtest-'.$runid);
ok ($id, $msg);
ok($user->id, "Created a test user");

ok(1, $user->Attributes->BuildSelectQuery);
my $attr = $user->Attributes;

ok(1, $attr->BuildSelectQuery);


ok (UNIVERSAL::isa($attr,'RT::Attributes'), 'got the attributes object');

($id, $msg) =  $user->AddAttribute(Name => 'TestAttr', Content => 'The attribute has content'); 
ok ($id, $msg);
is ($attr->Count,1, " One attr after adidng a first one");
($id, $msg) = $attr->DeleteEntry(Name => $runid);
ok(!$id, "Deleted non-existant entry  - $msg");
is ($attr->Count,1, "1 attr after deleting an empty attr");

my @names = $attr->Names;
is ("@names", "TestAttr");


($id, $msg) = $user->AddAttribute(Name => $runid, Content => "First");

is ($attr->Count,2, " Two attrs after adding an attribute named $runid");
($id, $msg) = $user->AddAttribute(Name => $runid, Content => "Second");
ok($id, $msg);

is ($attr->Count,3, " Three attrs after adding a secondvalue to $runid");
($id, $msg) = $attr->DeleteEntry(Name => $runid, Content => "First");
ok($id, $msg);
is ($attr->Count,2);

#$attr->_DoSearch();
($id, $msg) = $attr->DeleteEntry(Name => $runid, Content => "Second");
ok($id, $msg);
is ($attr->Count,1);

#$attr->_DoSearch();
ok(1, $attr->BuildSelectQuery);
($id, $msg) = $attr->DeleteEntry(Name => "moose");
ok(!$id, "Deleted non-existant entry - $msg");
is ($attr->Count,1);

ok(1, $attr->BuildSelectQuery);
@names = $attr->Names;
is("@names", "TestAttr");



1;
