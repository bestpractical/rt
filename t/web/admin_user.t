
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

# TODO more /Admin/Users tests

done_testing;
