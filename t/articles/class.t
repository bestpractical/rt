
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

done_testing();
