use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 7,
  gnupg_options => {
    passphrase => 'rt-test',
    homedir => RT::Test::get_abs_relocatable_dir(
        File::Spec->updir(), qw/data gnupg keyrings/
    ),
  };

my ($baseurl, $m) = RT::Test->started_ok;

$m->login;
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
         fields      => { CorrespondAddress => 'rt@example.com' } );
$m->content_like(qr/rt\@example.com.* - never/, 'has key info.');

ok(my $user = RT::User->new(RT->SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('rt@example.com');

if (0) {
    # XXX: need to generate these mails
    diag "no signature";
    diag "no encryption on encrypted queue";
    diag "mismatched signature";
    diag "unknown public key";
    diag "unknown private key";
    diag "signer != sender";
    diag "encryption to user whose pubkey is not signed";
    diag "no encryption of attachment on encrypted queue";
    diag "no signature of attachment";
    diag "revoked key";
    diag "expired key";
    diag "unknown algorithm";
}

