
use strict;
use warnings;

use RT::Test::GnuPG
  tests         => undef,
  gnupg_options => {
    passphrase    => 'recipient',
    'trust-model' => 'always',
  };

RT::Test->import_gnupg_key( 'rt-test@example.com', 'secret' );

ok( my $user = RT::User->new( RT->SystemUser ) );
ok( $user->Load('root'), "loaded user 'root'" );
$user->SetEmailAddress('rt-test@example.com');

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

my $root = RT::User->new( $RT::SystemUser );
$root->Load('root');
ok( $root->id, 'loaded root' );


diag "test the history page" if $ENV{TEST_VERBOSE};
$m->get_ok( $url . '/Admin/Users/History.html?id=' . $root->id );
$m->content_contains('User created', 'has User created entry');

diag "test keys page" if $ENV{TEST_VERBOSE};
$m->follow_link_ok( { text => 'Private keys' } );
$m->content_contains('Public key&#40;s&#41; for rt-test@example.com');
$m->content_contains('The key is ultimately trusted');
$m->content_contains('F0CB3B482CFA485680A4A0BDD328035D84881F1B');
$m->content_contains('Tue Aug 07 2007');
$m->content_contains('never');

$m->content_contains('GnuPG private key');

my $form = $m->form_with_fields('PrivateKey');
is( $form->find_input('PrivateKey')->value,
    '__empty_value__', 'default no private key' );
$m->submit_form_ok(
    {
        fields => { PrivateKey => 'D328035D84881F1B' },
        button => 'Update',
    },
    'submit PrivateKey form'
);

$m->content_contains('Set private key');
$form = $m->form_with_fields('PrivateKey');
is( $form->find_input('PrivateKey')->value,
    'D328035D84881F1B', 'set private key' );
$m->submit_form_ok(
    {
        fields => { PrivateKey => '__empty_value__' },
        button => 'Update',
    },
    'submit PrivateKey form'
);

$m->content_contains('Unset private key');
is( $form->find_input('PrivateKey')->value,
    '__empty_value__', 'unset private key' );
$form = $m->form_with_fields('PrivateKey');
$m->submit_form_ok(
    {
        fields => { PrivateKey => 'C798591AA831DBFB' },
        button => 'Update',
    },
    'submit PrivateKey form'
);
is( $form->find_input('PrivateKey')->value,
    'C798591AA831DBFB', 'set private key' );


diag "Test user searches";

my @cf_names = qw( CF1 CF2 CF3 );
my @cfs = ();
foreach my $cf_name ( @cf_names ) {
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ( $id, $msg ) = $cf->Create(
        Name => $cf_name,
        TypeComposite => 'Freeform-1',
        LookupType => RT::User->CustomFieldLookupType,
    );
    ok( $id, $msg );
    # Create a global ObjectCustomField record
    my $object = $cf->RecordClassFromLookupType->new( RT->SystemUser );
    ( $id, $msg ) = $cf->AddToObject( $object );
    ok( $id, $msg );
    push ( @cfs, $cf );
}
my $cf_1 = $cfs[0];
my $cf_2 = $cfs[1];
my $cf_3 = $cfs[2];

my @user_names = qw( user1 user2 user3 user4 );
my @users = ();
foreach my $user_name ( @user_names ) {
    my $user = RT::Test->load_or_create_user(
        Name => $user_name, Password => 'password',
    );
    ok( $user && $user->id, 'Created '.$user->Name.' with id '.$user->Id );
    push ( @users, $user );
}

$users[0]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );

$users[1]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );
$users[1]->AddCustomFieldValue( Field => $cf_2->id, Value => 'two' );

$users[2]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );
$users[2]->AddCustomFieldValue( Field => $cf_2->id, Value => 'two' );
$users[2]->AddCustomFieldValue( Field => $cf_3->id, Value => 'three' );

$m->get_ok( $url . '/Admin/Users/index.html' );
ok( $m->form_name( 'UsersAdmin' ), 'found the filter admin users form');
$m->select( UserField => 'Name', UserOp => 'LIKE' );
$m->field( UserString => 'user' );
$m->select( UserField2 => 'CustomField: '.$cf_1->Name, UserOp2 => 'LIKE' );
$m->field( UserString2 => 'one' );
$m->select( UserField3 => 'CustomField: '.$cf_2->Name, UserOp3 => 'LIKE' );
$m->field( UserString3 => 'two' );
$m->click( 'Go' );

diag "Verify results contain users 2 & 3, but not 1 & 4";
$m->content_contains( $users[1]->Name );
$m->content_contains( $users[2]->Name );
$m->content_lacks( $users[0]->Name );
$m->content_lacks( $users[3]->Name );

# TODO more /Admin/Users tests

done_testing;
