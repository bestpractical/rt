use strict;
use warnings;

use RT::Test::Crypt GnuPG => 1, undef => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->follow_link_ok( { text => 'Manage GnuPG Keys' } );
$m->title_is('Manage GnuPG Keys');

$m->text_contains('No public keys found');
$m->text_contains('No private keys found');

$m->submit_form_ok(
    {   form_name => 'ImportKeys',
        fields =>
          { Content => RT::Test->file_content( [ 't', 'data', 'gnupg', 'keys', 'recipient-at-example.com.public.key' ] ), },
        button => 'Import',
    },
    'Import keys for rt-test@example.com'
);

$m->text_contains('public key "Test User <recipient@example.com>" imported');
$m->text_contains('Test User <recipient@example.com> (7232A3C60F796865796370A54855ED8893EB9DE7)');
$m->text_lacks('No public keys found');
$m->text_contains('No private keys found');
$m->content_contains( '<td>Not set</td>', 'Default trust level' );

$m->form_name('PublicKeys');
$m->tick( 'PublicKey', '7232A3C60F796865796370A54855ED8893EB9DE7' );
$m->submit_form_ok( { fields => { OwnerTrustLevel => 4 }, button => 'TrustPublic' }, 'Delete keys for recipient@example.com' );
$m->text_contains('Key 93EB9DE7 trust level is updated');
$m->content_contains( '<td>I trust fully</td>', 'Updated trust level' );

$m->form_name('PublicKeys');
$m->tick( 'PublicKey', '7232A3C60F796865796370A54855ED8893EB9DE7' );
$m->submit_form_ok( { button => 'DeletePublic' }, 'Delete keys for recipient@example.com' );

$m->text_contains('Key 93EB9DE7 is deleted');
$m->text_contains('No public keys found');
$m->text_contains('No private keys found');

$m->submit_form_ok(
    {   form_name => 'ImportKeys',
        fields =>
          { Content => RT::Test->file_content( [ 't', 'data', 'gnupg', 'keys', 'rt-test-at-example.com.2.secret.key' ] ), },
        button => 'Import',
    },
    'Import keys for rt-test@example.com'
);

$m->text_contains('public key "RT Test the same <rt-test@example.com>" imported');
$m->text_contains('secret key imported');
$m->text_contains('RT Test the same <rt-test@example.com> (4CFD3F7DCD464852DB980F26C798591AA831DBFB)');

$m->text_lacks('No public keys found');
$m->text_lacks('No private keys found');

$m->form_name('PrivateKeys');
$m->tick( 'PrivateKey', '4CFD3F7DCD464852DB980F26C798591AA831DBFB' );
$m->submit_form_ok( { button => 'DeletePrivate' }, 'Delete keys for rt-test@example.com' );

$m->text_contains('Key A831DBFB is deleted');
$m->text_contains('No public keys found');
$m->text_contains('No private keys found');

done_testing;
