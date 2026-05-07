use strict;
use warnings;
use RT::Test tests => undef;

eval { require RT::Test::Passkey; } or do {
    plan skip_all => 'Unable to test without RT::Test::Passkey';
};

use MIME::Base64 qw(encode_base64url decode_base64url);

use_ok('RT::Passkey');
use_ok('RT::Passkeys');

diag 'credential record CRUD';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $passkey = RT::Passkey->new( RT->SystemUser );
    my ( $id, $msg ) = $passkey->Create(
        UserId       => $u->id,
        CredentialId => 'test-cred-001',
        PublicKey    => 'pkbytes',
        Name         => 'Work laptop',
    );
    ok( $id, "created: $msg" );
    my $loaded = RT::Passkey->new( RT->SystemUser );
    $loaded->LoadByCredentialId('test-cred-001');
    ok( $loaded->id && $loaded->id == $passkey->id, 'lookup by credential id' );
    ok( $passkey->Created,                      'Created timestamp auto-set' );

    my $count = RT::Passkeys->new( RT->SystemUser );
    $count->LimitToUser( $u->id );
    is( $count->Count, 1, 'one credential for user' );

    my ( $ok, $msg2 ) = $u->ClearPasskeys;
    ok( $ok, "cleared: $msg2" );
    is( $u->PasskeyCount, 0, 'zero after clear' );
}

diag 'unique credential id enforced';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $passkey1 = RT::Passkey->new( RT->SystemUser );
    my ( $id1, $msg1 )
        = $passkey1->Create( UserId => $u->id, CredentialId => 'dup-cred', PublicKey => 'k', Name => 'first' );
    ok( $id1, "first ok: $msg1" );

    my $passkey2 = RT::Passkey->new( RT->SystemUser );
    my ( $id2, $msg2 )
        = $passkey2->Create( UserId => $u->id, CredentialId => 'dup-cred', PublicKey => 'k', Name => 'second' );
    ok( !$id2, 'duplicate refused' );

    $u->ClearPasskeys;
}

diag 'Name is required';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');

    my $p = RT::Passkey->new( RT->SystemUser );
    my ( $id, $msg ) = $p->Create(
        UserId       => $u->id,
        CredentialId => 'name-required-undef',
        PublicKey    => 'k',
    );
    ok( !$id, 'Create without Name refused' );
    like( $msg, qr/Name is required/, 'error mentions Name' );

    my $p2 = RT::Passkey->new( RT->SystemUser );
    my ( $id2, $msg2 ) = $p2->Create(
        UserId       => $u->id,
        CredentialId => 'name-required-empty',
        PublicKey    => 'k',
        Name         => '',
    );
    ok( !$id2, 'Create with empty Name refused' );

    $u->ClearPasskeys;
}

diag 'duplicate Name rejected case-insensitively per user';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');

    my $p1 = RT::Passkey->new( RT->SystemUser );
    my ( $id1, $msg1 ) = $p1->Create(
        UserId       => $u->id,
        CredentialId => 'dup-name-1',
        PublicKey    => 'k',
        Name         => 'Work laptop',
    );
    ok( $id1, "first ok: $msg1" );

    my $p2 = RT::Passkey->new( RT->SystemUser );
    my ( $id2, $msg2 ) = $p2->Create(
        UserId       => $u->id,
        CredentialId => 'dup-name-2',
        PublicKey    => 'k',
        Name         => 'Work laptop',
    );
    ok( !$id2, 'exact-match duplicate refused' );
    like( $msg2, qr/already have a passkey with this name/, 'duplicate message' );

    my $p3 = RT::Passkey->new( RT->SystemUser );
    my ( $id3, $msg3 ) = $p3->Create(
        UserId       => $u->id,
        CredentialId => 'dup-name-3',
        PublicKey    => 'k',
        Name         => 'WORK LAPTOP',
    );
    ok( !$id3, 'case-variant duplicate refused' );

    my $other = RT::Test->load_or_create_user(
        Name     => "passkey_dup_other_$$",
        Password => 'otherpw1',
    );
    my $p4 = RT::Passkey->new( RT->SystemUser );
    my ( $id4, $msg4 ) = $p4->Create(
        UserId       => $other->id,
        CredentialId => 'dup-name-4',
        PublicKey    => 'k',
        Name         => 'Work laptop',
    );
    ok( $id4, "different user can reuse name: $msg4" );

    $u->ClearPasskeys;
    $other->ClearPasskeys;
}

diag 'ValidateName and rename via framework auto-validate';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');

    my $a = RT::Passkey->new( RT->SystemUser );
    $a->Create( UserId => $u->id, CredentialId => 'vn-a', PublicKey => 'k', Name => 'alpha' );
    my $b = RT::Passkey->new( RT->SystemUser );
    $b->Create( UserId => $u->id, CredentialId => 'vn-b', PublicKey => 'k', Name => 'beta' );

    is( $b->ValidateName('alpha'),     0, 'rejects sibling name' );
    is( $b->ValidateName('ALPHA'),     0, 'rejects case-variant of sibling' );
    is( $b->ValidateName('beta'),      1, 'self excluded — own current name passes' );
    is( $b->ValidateName('gamma'),     1, 'fresh name passes' );
    is( $b->ValidateName(''),          0, 'rejects empty' );
    is( $b->ValidateName( 'x' x 256 ), 0, 'rejects too long' );

    # Framework auto-validate kicks in on _Set during the auto-generated
    # SetName, so a duplicate rename is rejected even without endpoint
    # pre-flight (the message is generic — endpoints pre-flight for
    # better UX).
    my ( $ret, $msg ) = $b->SetName('alpha');
    ok( !$ret, "SetName('alpha') refused: $msg" );
    is( $b->Name, 'beta', 'name unchanged after refusal' );

    ( $ret, $msg ) = $b->SetName('gamma');
    ok( $ret, "SetName('gamma') ok: $msg" );
    is( $b->Name, 'gamma', 'name updated' );

    $u->ClearPasskeys;
}

diag 'CanonicalizeName strips leading/trailing whitespace';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');

    is( RT::Passkey->CanonicalizeName('  hello  '),  'hello',    'leading and trailing spaces stripped' );
    is( RT::Passkey->CanonicalizeName("\t\nfoo\n "), 'foo',      'tabs and newlines stripped' );
    is( RT::Passkey->CanonicalizeName('keep mid'),   'keep mid', 'internal whitespace preserved' );
    is( RT::Passkey->CanonicalizeName(undef),        undef,      'undef preserved' );
    is( RT::Passkey->CanonicalizeName('   '),        '',         'all-whitespace becomes empty' );

    my $p = RT::Passkey->new( RT->SystemUser );
    my ($id) = $p->Create(
        UserId       => $u->id,
        CredentialId => 'canon-1',
        PublicKey    => 'k',
        Name         => '  Work laptop  ',
    );
    ok( $id, 'Create accepts whitespace-padded name' );
    is( $p->Name, 'Work laptop', 'Create stored canonical name' );

    $p->SetName(' renamed ');
    is( $p->Name, 'renamed', 'SetName stripped whitespace' );

    $u->ClearPasskeys;
}

diag 'AnonymizeUser clears credentials';
{
    my $u      = RT::User->new( RT->SystemUser );
    my $unique = 'passkeyuser_' . $$ . '_' . int( rand 100000 );
    my ( $id, $msg ) = $u->Create(
        Name         => $unique,
        EmailAddress => $unique . '@test.invalid',
        Password     => 'foobar1!',
    );
    ok( $id, "created user: $msg" );

    my $passkey = RT::Passkey->new( RT->SystemUser );
    $passkey->Create( UserId => $u->id, CredentialId => 'anon-' . $$, PublicKey => 'k', Name => 'anon' );
    is( $u->PasskeyCount, 1, 'one cred' );

    my $cred_db_id = $passkey->id;
    $u->SetDisabled(1);

    if ( $u->can('AnonymizeUser') ) {
        my ( $ok2, $msg2 ) = $u->AnonymizeUser( ClearCustomFields => 1 );
        ok( $ok2, "anonymized user: $msg2" );

        my $orphan = RT::Passkey->new( RT->SystemUser );
        $orphan->Load($cred_db_id);
        ok( !$orphan->id, 'credential row gone after anonymize' );
    } else {
        diag "AnonymizeUser not available; skipping cleanup verification";
    }
}

diag 'soft authenticator -> ValidateRegistration';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $authn = RT::Test::Passkey->new_authenticator;
    my ( $opts, $challenge ) = RT::Authen::Passkey->BuildRegistrationOptions(
        User               => $u,
        Name               => 'soft test',
        ExcludeCredentials => [],
    );
    my $resp = $authn->register(
        challenge_b64   => $opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $opts->{user}->{id},
    );
    my ( $ok, $data, $err ) = RT::Authen::Passkey->ValidateRegistration(
        Challenge            => $challenge,
        ClientDataJSONB64    => $resp->{client_data_json_b64},
        AttestationObjectB64 => $resp->{attestation_object_b64},
    );
    ok( $ok, "registration validated" ) or diag $err;
    like( $data->{credential_id}, qr/^[A-Za-z0-9_-]+$/, 'b64url credential id returned' );
}

diag 'soft authenticator -> ValidateAssertion';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $authn = RT::Test::Passkey->new_authenticator;

    my ( $reg_opts, $reg_challenge ) = RT::Authen::Passkey->BuildRegistrationOptions(
        User               => $u,
        Name               => 'soft test',
        ExcludeCredentials => [],
    );
    my $reg = $authn->register(
        challenge_b64   => $reg_opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( undef, $reg_data ) = RT::Authen::Passkey->ValidateRegistration(
        Challenge            => $reg_challenge,
        ClientDataJSONB64    => $reg->{client_data_json_b64},
        AttestationObjectB64 => $reg->{attestation_object_b64},
    );

    my ( $opts, $challenge ) = RT::Authen::Passkey->BuildAssertionOptions;
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( $ok, $data, $err ) = RT::Authen::Passkey->ValidateAssertion(
        Challenge            => $challenge,
        CredentialPubKeyB64  => $reg_data->{credential_pubkey},
        StoredSignCount      => 0,
        ClientDataJSONB64    => $assertion->{client_data_json_b64},
        AuthenticatorDataB64 => $assertion->{authenticator_data_b64},
        SignatureB64         => $assertion->{signature_b64},
    );
    ok( $ok, "assertion validated" ) or diag $err;
    cmp_ok( $data->{signature_count}, '>', 0, 'sign count incremented' );
}

diag 'tampered signature rejected';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $authn = RT::Test::Passkey->new_authenticator;
    my ( $reg_opts, $reg_challenge ) = RT::Authen::Passkey->BuildRegistrationOptions(
        User               => $u,
        Name               => 't',
        ExcludeCredentials => [],
    );
    my $reg = $authn->register(
        challenge_b64   => $reg_opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( undef, $reg_data ) = RT::Authen::Passkey->ValidateRegistration(
        Challenge            => $reg_challenge,
        ClientDataJSONB64    => $reg->{client_data_json_b64},
        AttestationObjectB64 => $reg->{attestation_object_b64},
    );
    my ( $opts, $challenge ) = RT::Authen::Passkey->BuildAssertionOptions;
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );

    my $sig     = decode_base64url( $assertion->{signature_b64} );
    my $byte    = unpack( 'C', substr( $sig, 0, 1 ) );
    my $corrupt = chr( $byte ^ 0xff ) . substr( $sig, 1 );
    my $bad_b64 = encode_base64url($corrupt);

    my ( $ok, $data, $err ) = RT::Authen::Passkey->ValidateAssertion(
        Challenge            => $challenge,
        CredentialPubKeyB64  => $reg_data->{credential_pubkey},
        StoredSignCount      => 0,
        ClientDataJSONB64    => $assertion->{client_data_json_b64},
        AuthenticatorDataB64 => $assertion->{authenticator_data_b64},
        SignatureB64         => $bad_b64,
    );
    ok( !$ok, "tampered signature rejected: " . ( $err // 'no err msg' ) );
}

diag 'sign-count regression rejected';
{
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    my $authn = RT::Test::Passkey->new_authenticator;

    my ( $reg_opts, $reg_challenge ) = RT::Authen::Passkey->BuildRegistrationOptions(
        User               => $u,
        Name               => 'sc test',
        ExcludeCredentials => [],
    );
    my $reg = $authn->register(
        challenge_b64   => $reg_opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( undef, $reg_data ) = RT::Authen::Passkey->ValidateRegistration(
        Challenge            => $reg_challenge,
        ClientDataJSONB64    => $reg->{client_data_json_b64},
        AttestationObjectB64 => $reg->{attestation_object_b64},
    );

    # First assertion bumps the soft authenticator's counter to 1 and
    # establishes the stored counter on the server side.
    my ( $opts, $challenge ) = RT::Authen::Passkey->BuildAssertionOptions;
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( $ok1, $data1 ) = RT::Authen::Passkey->ValidateAssertion(
        Challenge            => $challenge,
        CredentialPubKeyB64  => $reg_data->{credential_pubkey},
        StoredSignCount      => 0,
        ClientDataJSONB64    => $assertion->{client_data_json_b64},
        AuthenticatorDataB64 => $assertion->{authenticator_data_b64},
        SignatureB64         => $assertion->{signature_b64},
    );
    ok( $ok1, 'first assertion succeeds' );
    my $stored = $data1->{signature_count};

    # Force the soft authenticator's counter back -- simulates a clone
    # whose counter has not kept up with the legitimate device.
    $authn->set_sign_count(0);

    my ( $opts2, $challenge2 ) = RT::Authen::Passkey->BuildAssertionOptions;
    my $assertion2 = $authn->assert(
        challenge_b64   => $opts2->{challenge},
        rp_id           => RT::Authen::Passkey->RPID,
        origin          => RT::Authen::Passkey->Origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    my ( $ok2, undef, $err2 ) = RT::Authen::Passkey->ValidateAssertion(
        Challenge            => $challenge2,
        CredentialPubKeyB64  => $reg_data->{credential_pubkey},
        StoredSignCount      => $stored,
        ClientDataJSONB64    => $assertion2->{client_data_json_b64},
        AuthenticatorDataB64 => $assertion2->{authenticator_data_b64},
        SignatureB64         => $assertion2->{signature_b64},
    );
    ok( !$ok2, 'regressed sign-count rejected' );
    like( $err2 // '', qr/signature count/i, 'error mentions signature count' );
}

diag 'WebAuthn user handle is random and persisted';
{
    my $alice = RT::Test->load_or_create_user( Name => "uhtest_alice_$$" );
    my $bob   = RT::Test->load_or_create_user( Name => "uhtest_bob_$$" );

    ok( !length( $alice->__Value('PasskeyUserHandle') // '' ),
        'no handle stored before SetRandomPasskeyUserHandle' );
    my ( $ok_a, $msg_a ) = $alice->SetRandomPasskeyUserHandle;
    ok( $ok_a, "minted handle: $msg_a" );
    my $h1 = $alice->__Value('PasskeyUserHandle');
    ok( length $h1 >= 20, 'handle is long enough to be ~128-bit' );

    # Round-trip: a fresh load sees the same persisted value.
    my $reloaded = RT::User->new( RT->SystemUser );
    $reloaded->Load( $alice->id );
    is( $reloaded->__Value('PasskeyUserHandle'), $h1, 'handle is persisted across loads' );

    # Two users get distinct handles -- the value is not derived from the
    # user id.
    my ( $ok_b ) = $bob->SetRandomPasskeyUserHandle;
    ok( $ok_b, 'minted handle for second user' );
    my $h2 = $bob->__Value('PasskeyUserHandle');
    isnt( $h1, $h2, 'distinct users get distinct handles' );
}

done_testing;
