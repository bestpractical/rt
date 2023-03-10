
use strict;
use warnings;

use RT::Test tests => undef;

use_ok 'RT::Articles';
use_ok 'RT::Classes';
use_ok 'RT::Class';

my $root = RT::CurrentUser->new('root');
ok ($root->Id, "Loaded root");
my $cl = RT::Class->new($root);
ok (UNIVERSAL::isa($cl, 'RT::Class'), "the new class is a class");

my ($id, $msg) = $cl->Create(Name => 'Test-'.$$, Description => 'A test class');

ok ($id, $msg);

ok( $cl->SetName( 'test-' . $$ ), 'rename to lower cased version' );
ok( $cl->SetName( 'Test-' . $$ ), 'rename back' );

# no duplicate class names should be allowed
($id, $msg) = RT::Class->new($root)->Create(Name => 'Test-'.$$, Description => 'A test class');

ok (!$id, $msg);

($id, $msg) = RT::Class->new($root)->Create(Name => 'test-'.$$, Description => 'A test class');

ok (!$id, $msg);

#class name should be required

($id, $msg) = RT::Class->new($root)->Create(Name => '', Description => 'A test class');

ok (!$id, $msg);



$cl->Load('Test-'.$$);
ok($cl->id, "Loaded the class we want");
ok($cl->IncludeName, 'Class will include article names');
ok($cl->IncludeSummary, 'Class will include article summary');
ok($cl->EscapeHTML, 'Class will escape HTML content');

diag('Test class custom fields');

my $cfs = $cl->CustomFields;
is( $cfs->Count, 0, 'Class has no custom fields' );

my $ok;
my $single_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', LookupType => RT::Class->CustomFieldLookupType);
ok($ok, $msg);
my $single_cf_id = $single_cf->Id;

($ok, $msg) = $single_cf->AddToObject($cl);
ok($ok, $msg);

$cfs = $cl->CustomFields;
is( $cfs->Count, 1, 'Class now has one custom field' );

($ok, $msg) = $cl->AddCustomFieldValue( Field => 'Single' , Value => 'foo' );
ok($ok, $msg);
is( $cl->FirstCustomFieldValue('Single'), 'foo', 'Custom field has the correct value' );

# Create a new user. make sure they can't create a class

my $u= RT::User->new(RT->SystemUser);
$u->Create(Name => "ArticlesTest".time, Privileged => 1);
ok ($u->Id, "Created a new user");

# Make sure you can't create a group with no acls
$cl = RT::Class->new($u);
ok (UNIVERSAL::isa($cl, 'RT::Class'), "the new class is a class");

($id, $msg) = $cl->Create(Name => 'Test-nobody'.$$, Description => 'A test class');


ok (!$id, $msg. "- Can not create classes as a random new user - " .$u->Id);
$u->PrincipalObj->GrantRight(Right =>'AdminClass', Object => RT->System);
($id, $msg) = $cl->Create(Name => 'Test-nobody-'.$$, Description => 'A test class');

ok ($id, $msg. "- Can create classes as a random new user after ACL grant");

# now check the Web UI

my ($url, $m) = RT::Test->started_ok;
ok($m->login);
$m->get_ok("$url/Admin/Articles/Classes/Modify.html?Create=1");
$m->content_contains('Create a Class', 'found title');
$m->submit_form_ok({
    form_number => 3,
    fields => { Name => 'Test Redirect' },
});
$m->content_contains('Object created', 'found results');
$m->content_contains('Modify the Class Test Redirect', 'found title');
$m->form_number(3);
$m->untick( 'Include-Name', 1 );
$m->field( 'Description', 'Test Description' );
$m->submit();
$m->content_like(qr/Description changed from.*no value.*to .*Test Description/,'description changed');
$m->form_number(3);
is($m->current_form->find_input('Include-Name')->value,undef,'Disabled Including Names for this Class');

my $class_reload = RT::Class->new(RT->SystemUser);
($ok, $msg) = $class_reload->Load('Test Redirect');
ok($ok, $msg);
ok(!$class_reload->IncludeName, 'Class will not include article names');

done_testing();
