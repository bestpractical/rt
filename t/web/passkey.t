use strict;
use warnings;
use RT::Test tests => undef;

eval { require RT::Test::Passkey; } or do {
    plan skip_all => 'Passkey dependencies not installed';
};

use MIME::Base64 qw(encode_base64url);
use JSON         qw(decode_json);

my ( $baseurl, $m ) = RT::Test->started_ok( disable_config_cache => 1 );

RT::Test->add_rights(
    { Principal => 'Privileged',   Right => ['ModifySelf'] },
    { Principal => 'Unprivileged', Right => ['ModifySelf'] },
);

my $rpid   = RT::Authen::Passkey->RPID;
my $origin = RT::Authen::Passkey->Origin;

# Cross-process sanity check: the running server's view of RPID must
# match the test process. Drift here masks every later "rp_id mismatch"
# failure with a confusing message; surface it up front instead.
{
    my $probe = RT::Test::Web->new;
    $probe->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' } );
    my $opts = decode_json( $probe->content );
    is( $opts->{rpId}, $rpid, 'running server RPID matches test process' );
}

# === Registration: happy path ===
diag 'registration happy path';
{
    $m->login;
    my $authn = RT::Test::Passkey->new_authenticator;
    my ( $user_handle, $verify ) = $authn->enroll( mech => $m, name => 'soft test' );
    ok( $user_handle, 'got challenge' );
    ok( $verify->{ok}, 'registration verified' ) or diag $verify->{error};
    is( $verify->{name}, 'soft test', 'name persisted' );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    $u->ClearPasskeys;
}

# === Registration: cap enforced ===
diag 'cap enforced';
{
    RT::Test->set_config( PasskeyMaxCredentials => 2 );
    $m->login;

    for my $i ( 1, 2 ) {
        my ( undef, $v ) = RT::Test::Passkey->new_authenticator->enroll( mech => $m, name => "key$i" );
        ok( $v->{ok}, "registered $i" ) or diag $v->{error};
    }

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'extra' }, );
    my $opts = decode_json( $m->content );
    like( $opts->{error}, qr/[Mm]aximum/, 'cap error returned' );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    $u->ClearPasskeys;
    RT::Test->set_config( PasskeyMaxCredentials => 10 );
}

# === Login: happy path ===
diag 'login happy path';
{
    $m->login;
    my $authn = RT::Test::Passkey->new_authenticator;
    my ($user_handle) = $authn->enroll( mech => $m, name => 'login test' );

    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    my $opts = decode_json( $login_mech->content );
    ok( $opts->{challenge}, 'login challenge' );

    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );

    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $result = decode_json( $login_mech->content );
    ok( $result->{ok}, 'logged in via passkey' ) or diag $result->{error};
    like( $result->{redirect}, qr{^https?://}, 'redirect URL returned' );

    $login_mech->get_ok($baseurl);

    my $next_mech = RT::Test::Web->new;
    $next_mech->get("$baseurl/Search/Build.html");
    my $next = $next_mech->form_id('login')->value('next');
    ok( $next, 'login form carries the next page hash' );

    $next_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' } );
    $opts      = decode_json( $next_mech->content );
    $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );
    $next_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
            next               => $next,
        },
    );
    $result = decode_json( $next_mech->content );
    ok( $result->{ok}, 'logged in via passkey with next' ) or diag $result->{error};
    like( $result->{redirect}, qr{/Search/Build\.html$}, 'redirected to the originally requested page' );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    $u->ClearPasskeys;
}

# === Login: passkey bypasses MFA ===
# A successful passkey assertion is itself multi-factor (device + UV
# gesture), so RT treats it as fully authed and skips the TOTP step.
diag 'passkey login bypasses MFA';
SKIP: {
    eval { require RT::MFA::TOTP } or skip 'MFA TOTP not available', 7;

    my $user = RT::Test->load_or_create_user(
        Name     => "mfauser_$$",
        Password => 'mfapass1!',
    );
    my $group = RT::Test->load_or_create_group("mfa_required_$$");
    $group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

    # Register the passkey while the user is still outside the
    # MFA-required group, so password login isn't gated by MFA enroll.
    $m->login( $user->Name, 'mfapass1!', logout => 1 );
    my $authn = RT::Test::Passkey->new_authenticator;
    my ( $user_handle, $verify ) = $authn->enroll( mech => $m, name => 'mfa bypass key' );
    ok( $verify->{ok}, 'registered passkey before enabling MFA' )
        or diag $verify->{error};
    $m->logout;

    # Now flip the user into the MFA-required state.
    $user->SetTOTPSecret( RT::MFA::TOTP->GenerateSecret );
    $user->SetTOTPEnrolled(1);
    $group->AddMember( $user->PrincipalId );
    is( $user->TOTPEnrolled, 1, 'TOTP enrolled' );

    # Sanity: a regular password login is now intercepted by MFA verify.
    my $pw_mech = RT::Test::Web->new;
    $pw_mech->get( "$baseurl/?user=" . $user->Name . ";pass=mfapass1!" );
    like( $pw_mech->uri, qr{/NoAuth/MFA/Verify\.html}, 'password login redirected to MFA verify' );

    # Passkey login on the same user must NOT redirect to MFA verify.
    my $pk_mech = RT::Test::Web->new;
    $pk_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    my $opts      = decode_json( $pk_mech->content );
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );
    $pk_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $result = decode_json( $pk_mech->content );
    ok( $result->{ok}, 'passkey login succeeded with MFA required' )
        or diag $result->{error};
    $pk_mech->get_ok($baseurl);
    unlike( $pk_mech->uri, qr{/NoAuth/MFA/Verify\.html}, 'follow-up request not redirected to MFA verify' );
    $pk_mech->content_contains( 'Logout', 'session is fully authenticated' );

    $user->ClearPasskeys;
}

# === Login: unknown credential -> generic error ===
diag 'unknown credential rejected with generic error';
{
    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );

    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => encode_base64url( "x" x 16 ),
            client_data_json   => 'AA',
            authenticator_data => 'AA',
            signature          => 'AA',
            user_handle        => encode_base64url( "\0" x 8 ),
        },
    );
    is( $login_mech->status, 401, 'unknown credential returns 401' );
    my $result = decode_json( $login_mech->content );
    is( $result->{error}, 'Passkey authentication failed', 'generic error' );
    ok( !$result->{ok}, 'no session' );
}

# === Login: challenge consumed even on failed verify ===
diag 'login challenge is consumed on failed verify';
{
    $m->login;
    my $authn = RT::Test::Passkey->new_authenticator;
    my ($user_handle) = $authn->enroll( mech => $m, name => 'consume test' );
    $m->logout;

    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    my $opts      = decode_json( $login_mech->content );
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );

    # First verify is intentionally bogus (garbage signature). The
    # validator must still consume the challenge so a follow-up
    # legitimate-looking POST in the same session is rejected.
    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => encode_base64url( "\xff" x 64 ),
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $bad = decode_json( $login_mech->content );
    ok( !$bad->{ok}, 'garbage signature rejected' );

    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $second = decode_json( $login_mech->content );
    ok( !$second->{ok}, 'valid assertion against consumed challenge rejected' );
    is( $second->{error}, 'Passkey authentication failed', 'generic error' );
    $m->next_warning_like( qr/FAILED LOGIN for root from \S+ \(passkey\)/, 'failed login logged' );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    $u->ClearPasskeys;
}

# === Login: known credential id with wrong userHandle ===
diag 'mismatched userHandle rejected';
{
    my $other = RT::Test->load_or_create_user(
        Name     => "uh_target_$$",
        Password => 'foobar1!',
    );

    $m->login;
    my $authn = RT::Test::Passkey->new_authenticator;
    my ($user_handle) = $authn->enroll( mech => $m, name => 'uh test' );
    $m->logout;

    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    my $opts      = decode_json( $login_mech->content );
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );

    # Submit root's valid assertion but with $other's userHandle.
    # The credential lookup succeeds and the signature verifies, but
    # the userHandle/UserId binding mismatch must reject the login.
    # Mint a handle for $other so the comparison value is a real
    # (but wrong) opaque string rather than the empty default.
    $other->SetRandomPasskeyUserHandle;
    my $other_handle = $other->__Value('PasskeyUserHandle');

    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $other_handle,
        },
    );
    my $result = decode_json( $login_mech->content );
    ok( !$result->{ok}, 'mismatched userHandle rejected' );
    is( $result->{error}, 'Passkey authentication failed', 'generic error' );
    $m->next_warning_like( qr/FAILED LOGIN for root from \S+ \(passkey\)/, 'failed login logged' );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('root');
    $u->ClearPasskeys;
}

# === Register: empty/duplicate name rejected at challenge step ===
diag 'register pre-flight: empty name';
{
    $m->login;
    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => '' }, );
    is( $m->status, 400, 'empty name returns 400' );
    my $r = decode_json( $m->content );
    like( $r->{error}, qr/Name is required/, 'empty name rejected before ceremony' );
    $m->logout;
}

diag 'register pre-flight: duplicate name';
{
    $m->login;
    my ( undef, $v ) = RT::Test::Passkey->new_authenticator->enroll( mech => $m, name => 'preflight-dup' );
    ok( $v->{ok}, 'first registration succeeded' );

    # Second challenge with the same name — should be refused before
    # any options are returned.
    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'preflight-dup' }, );
    my $r = decode_json( $m->content );
    like( $r->{error}, qr/already have a passkey with this name/, 'duplicate name rejected pre-flight' );
    ok( !$r->{challenge}, 'no WebAuthn challenge returned' );

    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $v->{id} }, );
    $m->logout;
}

diag 'manage rename: duplicate name surfaces error';
{
    $m->login;

    my ( undef, $a ) = RT::Test::Passkey->new_authenticator->enroll( mech => $m, name => 'rename-a' );
    ok( $a->{ok}, 'a registered' );
    my ( undef, $b ) = RT::Test::Passkey->new_authenticator->enroll( mech => $m, name => 'rename-b' );
    ok( $b->{ok}, 'b registered' );

    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'rename', id => $b->{id}, name => 'rename-a' }, );
    my $rn = decode_json( $m->content );
    like( $rn->{error}, qr/already have a passkey with this name/, 'duplicate rename refused' );

    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $a->{id} }, );
    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $b->{id} }, );
    $m->logout;
}

# === Manage: cross-user requires AdminUsers ===
diag 'cross-user requires AdminUsers';
{
    my $alice = RT::Test->load_or_create_user(
        Name     => "alice_$$",
        Password => 'alicepw',
    );
    my $bob = RT::Test->load_or_create_user(
        Name     => "bob_$$",
        Password => 'bobpw1',
    );
    my $passkey = RT::Passkey->new( RT->SystemUser );
    $passkey->Create(
        UserId       => $alice->id,
        CredentialId => "alice-cred-$$",
        PublicKey    => 'k',
        Name         => 'alice key',
    );

    $m->login( $bob->Name, 'bobpw1', logout => 1 );
    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $passkey->id, user_id => $alice->id }, );
    my $del = decode_json( $m->content );
    like( $del->{error}, qr/[Pp]ermission/, 'bob cannot delete alice cred' );

    $alice->ClearPasskeys;
    $m->logout;
}

# === Config: $DisablePasskey hides endpoints ===
diag '$DisablePasskey hides endpoints';
{
    RT::Test->set_config( DisablePasskey => 1 );
    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    is( $login_mech->status, 404, 'login endpoint 404 when disabled' );
    RT::Test->set_config( DisablePasskey => undef );
}

# === UI: passkey sections render where expected ===
diag 'passkey UI rendering';
{
    my $self_service = RT::Test->load_or_create_user(
        Name       => "passkey_ui_unpriv_$$",
        Password   => 'password',
        Privileged => 0,
    );
    my $no_password = RT::Test->load_or_create_user(
        Name       => "passkey_ui_nopass_$$",
        Password   => 'password',
        Privileged => 1,
    );

    my $check_pages = sub {
        my $enabled = shift;
        my $label   = $enabled ? 'shown' : 'hidden';
        my $present = sub { $_[0] ? 1 : 0 };

        my $anon = RT::Test::Web->new;
        $anon->get_ok($baseurl);
        is( $present->( $anon->dom->at('#passkey-login-btn') ), $enabled, "login page passkey button $label" );

        $m->login;
        $m->get_ok("$baseurl/Prefs/AboutMe.html");
        is( $present->( $m->dom->at('#user-prefs-passkeys') ), $enabled, "About me passkey section $label" );
        $m->get_ok( "$baseurl/Admin/Users/Modify.html?id=" . $self_service->id );
        is( $present->( $m->dom->at('#admin-passkey-list') ), $enabled, "admin user page passkey section $label" );
        $m->logout;

        my $ss_mech = RT::Test::Web->new;
        ok( $ss_mech->login( $self_service->Name, 'password' ), 'logged in as unprivileged user' );
        $ss_mech->get_ok("$baseurl/SelfService/Prefs.html");
        is( $present->( $ss_mech->dom->at('#user-prefs-passkeys') ), $enabled, "self-service passkey section $label" );
    };

    $check_pages->(1);

    RT::Test->set_config( DisablePasskey => 1 );
    $check_pages->(0);
    RT::Test->set_config( DisablePasskey => undef );

    my $nopass_mech = RT::Test::Web->new;
    ok( $nopass_mech->login( $no_password->Name, 'password' ), 'logged in as user to lose the password' );
    my ( $ret, $msg ) = $no_password->UnsetPassword;
    ok( $ret, 'password unset' ) or diag $msg;
    $nopass_mech->get_ok("$baseurl/Prefs/AboutMe.html");
    ok( !$nopass_mech->dom->at('#user-prefs-passkeys'), 'About me passkey section hidden without an RT password' );
}

# === Unprivileged users manage passkeys via the SelfService helpers ===
diag 'unprivileged passkey management';
{
    my $user = RT::Test->load_or_create_user(
        Name       => "passkey_unpriv_$$",
        Password   => 'password',
        Privileged => 0,
    );
    my $ss_mech = RT::Test::Web->new;
    ok( $ss_mech->login( $user->Name, 'password' ), 'logged in as unprivileged user' );

    my $helpers = "$baseurl/SelfService/Helpers/Passkey";
    my ( undef, $reg ) = RT::Test::Passkey->new_authenticator->enroll(
        mech         => $ss_mech,
        name         => 'self-service key',
        self_service => 1,
    );
    ok( $reg->{ok}, 'unprivileged user registered a passkey' ) or diag $reg->{error};

    $ss_mech->post( "$helpers/Manage", { action => 'rename', id => $reg->{id}, name => 'renamed key' } );
    ok( decode_json( $ss_mech->content )->{ok}, 'unprivileged user renamed the passkey' );

    my $passkey = RT::Passkey->new( RT->SystemUser );
    $passkey->Load( $reg->{id} );
    is( $passkey->Name, 'renamed key', 'passkey renamed' );

    $ss_mech->post( "$helpers/Manage", { action => 'delete', id => $reg->{id} } );
    ok( decode_json( $ss_mech->content )->{ok}, 'unprivileged user deleted the passkey' );
    is( $user->PasskeyCount, 0, 'no passkeys left' );

    RT::Test->set_config( DisablePasskey => 1 );
    $ss_mech->post( "$helpers/Manage", { action => 'delete_all' } );
    is( $ss_mech->status, 404, 'SelfService helper 404 when disabled' );
    RT::Test->set_config( DisablePasskey => undef );
}

# === Re-auth gate: stale session blocks state-changing ops ===
diag 're-auth gate';
{
    require RT::Interface::Web::Session;

    # Force a logged-in session into the "stale" state by reaching into
    # the session store and rewinding LastInteractiveAuth. The forked
    # Plack server reads sessions from the same DB-backed store, so this
    # change is visible to the next request.
    my $expire_session = sub {
        my $sid = shift;
        my %s;
        tie %s, RT::Interface::Web::Session->Class, $sid, RT::Interface::Web::Session->Attributes;
        $s{LastInteractiveAuth} = time - $RT::Interface::Web::REAUTH_WINDOW - 60;
        untie %s;
    };
    my $get_sid = sub {
        my $mech = shift;
        my ($cookie) = $mech->cookie_jar->as_string =~ /RT_SID_\S+?=([0-9a-f]+)/;
        return $cookie;
    };

    $m->login;

    # Register a credential up front so we have something to rename/delete
    # after we expire the session.
    my ( undef, $reg_verify ) = RT::Test::Passkey->new_authenticator->enroll( mech => $m, name => 'fresh' );
    my $cred_id = $reg_verify->{id};
    ok( $cred_id, 'registered passkey for stale-session test' );

    $expire_session->( $get_sid->($m) );

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'stale' }, );
    my $stale = decode_json( $m->content );
    is( $stale->{error}, 'Recent authentication required', 'stale session blocked from registration' );
    ok( $stale->{reauth}, 'reauth flag set' );

    # Rename and delete are intentionally NOT gated by step-up: a hijacked
    # session that wipes a user's passkeys is a DoS the user can recover
    # from, while a hijacked session that enrolls a new credential is a
    # persistent backdoor — only enrollment needs the gate.
    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'rename', id => $cred_id, name => 'renamed-stale' }, );
    my $stale_rename = decode_json( $m->content );
    ok( $stale_rename->{ok}, 'stale session can rename' )
        or diag $stale_rename->{error};
    ok( !$stale_rename->{reauth}, 'rename is exempt from re-auth' );

    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $cred_id }, );
    my $stale_delete = decode_json( $m->content );
    ok( $stale_delete->{ok}, 'stale session can delete' )
        or diag $stale_delete->{error};
    ok( !$stale_delete->{reauth}, 'delete is exempt from re-auth' );

    $m->post( "$baseurl/Helpers/Passkey/Reauth", { password => 'not-the-password' }, );
    my $bad = decode_json( $m->content );
    like( $bad->{error}, qr/[Ii]ncorrect/, 'wrong password rejected' );

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'still stale' }, );
    my $still_stale = decode_json( $m->content );
    ok( $still_stale->{reauth}, 'still gated after failed reauth' );

    $m->post( "$baseurl/Helpers/Passkey/Reauth", { password => 'password' } );
    my $ok = decode_json( $m->content );
    ok( $ok->{ok}, 'reauth succeeded' );

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'after reauth' }, );
    my $fresh = decode_json( $m->content );
    ok( $fresh->{challenge}, 'registration allowed after reauth' );
}

# === Re-auth lockout: repeated wrong-password attempts are capped ===
diag 're-auth lockout after repeated failures';
{
    require RT::Interface::Web::Session;
    my $expire_session = sub {
        my $sid = shift;
        my %s;
        tie %s, RT::Interface::Web::Session->Class, $sid, RT::Interface::Web::Session->Attributes;
        $s{LastInteractiveAuth} = time - $RT::Interface::Web::REAUTH_WINDOW - 60;
        untie %s;
    };
    my $get_sid = sub {
        my $mech = shift;
        my ($cookie) = $mech->cookie_jar->as_string =~ /RT_SID_\S+?=([0-9a-f]+)/;
        return $cookie;
    };

    $m->login;
    $expire_session->( $get_sid->($m) );

    my $max = $RT::Interface::Web::REAUTH_MAX_FAILURES;
    for my $i ( 1 .. $max ) {
        $m->post( "$baseurl/Helpers/Passkey/Reauth", { password => 'wrong' } );
        my $r = decode_json( $m->content );
        like( $r->{error}, qr/[Ii]ncorrect/, "wrong-password attempt $i rejected" );
    }

    $m->post( "$baseurl/Helpers/Passkey/Reauth", { password => 'password' } );
    my $locked = decode_json( $m->content );
    like( $locked->{error}, qr/[Tt]oo many/, 'lockout refuses even the correct password' );
    $m->next_warning_like( qr/Passkey re-auth lockout/, 'lockout warning logged' );

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'after lockout' }, );
    my $still_blocked = decode_json( $m->content );
    ok( $still_blocked->{reauth}, 'registration still gated after lockout' );
}

# === Config: $WebRemoteUserAuth + !$WebFallbackToRTLogin disables passkey login ===
diag 'passkey login disabled when external auth is exclusive';
{
    RT::Test->set_config(
        WebRemoteUserAuth    => 1,
        WebFallbackToRTLogin => 0,
    );
    my $mech = RT::Test::Web->new;
    $mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    is( $mech->status, 404, 'login endpoint 404 when external auth is the only path' );

    RT::Test->set_config(
        WebRemoteUserAuth    => undef,
        WebFallbackToRTLogin => undef,
    );
}

# === Externally-authed sessions cannot self-manage passkeys ===
diag 'externally-authed sessions refused on self endpoints';
{
    require RT::Interface::Web::Session;
    my $mark_external = sub {
        my $sid = shift;
        my %s;
        tie %s, RT::Interface::Web::Session->Class, $sid, RT::Interface::Web::Session->Attributes;
        $s{WebExternallyAuthed} = 1;
        $s{LastInteractiveAuth} = time;
        untie %s;
    };
    my $get_sid = sub {
        my $mech = shift;
        my ($cookie) = $mech->cookie_jar->as_string =~ /RT_SID_\S+?=([0-9a-f]+)/;
        return $cookie;
    };

    $m->login;
    $mark_external->( $get_sid->($m) );

    $m->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'external' }, );
    my $reg = decode_json( $m->content );
    like( $reg->{error}, qr/external/i, 'register refuses externally-authed session' );

    $m->post( "$baseurl/Helpers/Passkey/Reauth", { password => 'password' } );
    my $reauth = decode_json( $m->content );
    like( $reauth->{error}, qr/external/i, 'reauth refuses externally-authed session' );

    my $nonadmin = RT::Test->load_or_create_user(
        Name       => "ext_self_$$",
        Password   => 'pw1pw1pw',
        Privileged => 1,
    );
    my $nonadmin_m = RT::Test::Web->new;
    ok( $nonadmin_m->login( $nonadmin->Name, 'pw1pw1pw' ), 'non-admin logged in' );
    $mark_external->( $get_sid->($nonadmin_m) );
    $nonadmin_m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete_all' } );
    my $self_manage = decode_json( $nonadmin_m->content );
    like( $self_manage->{error}, qr/external/i, 'non-admin self manage refuses externally-authed session' );

    my $own = RT::Passkey->new( RT->SystemUser );
    my ( $pid, $msg ) = $own->Create(
        UserId       => RT::Test->load_or_create_user( Name => 'root' )->id,
        CredentialId => "ext-root-cred-$$",
        PublicKey    => 'ext-root-pk',
        Name         => 'Root external',
    );
    ok( $pid, "created root passkey: $msg" );
    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete', id => $pid } );
    my $admin_self = decode_json( $m->content );
    ok( $admin_self->{ok}, 'externally-authed admin can delete own passkey' ) or diag $admin_self->{error};
    $own = RT::Passkey->new( RT->SystemUser );
    $own->Load($pid);
    ok( !$own->id, 'own passkey removed' );

    # Cross-user admin manage still works: root has AdminUsers and is
    # acting on a different user, which is the admin-only path.
    my $other = RT::Test->load_or_create_user(
        Name     => "ext_target_$$",
        Password => 'pw1pw1pw',
    );
    $m->post( "$baseurl/Helpers/Passkey/Manage", { action => 'delete_all', user_id => $other->id }, );
    my $admin_manage = decode_json( $m->content );
    ok( $admin_manage->{ok}, 'externally-authed admin can still manage another user' )
        or diag $admin_manage->{error};
}

# === Disabled user cannot passkey-login ===
diag 'disabled user blocked from passkey login';
{
    my $user = RT::Test->load_or_create_user(
        Name     => "disabled_$$",
        Password => 'dispw1!',
    );

    $m->login( $user->Name, 'dispw1!', logout => 1 );
    my $authn = RT::Test::Passkey->new_authenticator;
    my ( $user_handle, $verify ) = $authn->enroll( mech => $m, name => 'before disable' );
    ok( $verify->{ok}, 'registered passkey before disabling' )
        or diag $verify->{error};
    $m->logout;

    $user->SetDisabled(1);

    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' }, );
    my $opts      = decode_json( $login_mech->content );
    my $assertion = $authn->assert(
        challenge_b64   => $opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $user_handle,
    );
    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $result = decode_json( $login_mech->content );
    like(
        $result->{error},
        qr/[Pp]asskey authentication failed/,
        'disabled user gets generic error from passkey login'
    );
    ok( !$result->{ok}, 'disabled user not logged in' );
    $m->next_warning_like( qr/FAILED LOGIN for \S+ from \S+ \(passkey\)/, 'failed login logged' );

    $user->ClearPasskeys;
    $user->SetDisabled(0);
}

# === Expired challenges (registration and login) ===
diag 'expired challenges are rejected';
{
    require RT::Interface::Web::Session;

    my $tie_session = sub {
        my $sid = shift;
        my %s;
        tie %s, RT::Interface::Web::Session->Class, $sid, RT::Interface::Web::Session->Attributes;
        return \%s;
    };
    my $get_sid = sub {
        my $mech = shift;
        my ($cookie) = $mech->cookie_jar->as_string =~ /RT_SID_\S+?=([0-9a-f]+)/;
        return $cookie;
    };

    # --- Registration: expire $session{PasskeyRegistrationChallenge}{expires} ---
    my $reg_mech = RT::Test::Web->new;
    $reg_mech->login;
    $reg_mech->post( "$baseurl/Helpers/Passkey/Register", { action => 'challenge', name => 'will expire' } );
    my $reg_opts = decode_json( $reg_mech->content );
    ok( $reg_opts->{challenge}, 'registration challenge issued' );

    {
        my $s     = $tie_session->( $get_sid->($reg_mech) );
        my $entry = $s->{PasskeyRegistrationChallenge};
        ok( $entry && $entry->{expires}, 'challenge stored in session' );
        $entry->{expires}                  = time - 1;
        $s->{PasskeyRegistrationChallenge} = $entry;
        untie %$s;
    }

    my $authn = RT::Test::Passkey->new_authenticator;
    my $resp  = $authn->register(
        challenge_b64   => $reg_opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $reg_opts->{user}->{id},
    );
    $reg_mech->post(
        "$baseurl/Helpers/Passkey/Register",
        {   action             => 'verify',
            client_data_json   => $resp->{client_data_json_b64},
            attestation_object => $resp->{attestation_object_b64},
        },
    );
    my $reg_verify = decode_json( $reg_mech->content );
    like( $reg_verify->{error}, qr/expired|missing/i, 'expired registration challenge rejected' );

    # --- Login: expire $session{PasskeyLoginChallenge}{expires} ---
    # Use a separate mech so we can register cleanly first.
    my $setup_mech = RT::Test::Web->new;
    $setup_mech->login;
    my $setup_authn = RT::Test::Passkey->new_authenticator;
    my ( $setup_handle, $setup_verify ) = $setup_authn->enroll( mech => $setup_mech, name => 'login expire' );
    ok( $setup_verify->{ok}, 'set up credential for login-expire test' );

    my $login_mech = RT::Test::Web->new;
    $login_mech->post( "$baseurl/NoAuth/Helpers/Passkey/Login", { action => 'challenge' } );
    my $login_opts = decode_json( $login_mech->content );
    ok( $login_opts->{challenge}, 'login challenge issued' );

    {
        my $s     = $tie_session->( $get_sid->($login_mech) );
        my $entry = $s->{PasskeyLoginChallenge};
        ok( $entry && $entry->{expires}, 'login challenge stored in session' );
        $entry->{expires}           = time - 1;
        $s->{PasskeyLoginChallenge} = $entry;
        untie %$s;
    }

    my $assertion = $setup_authn->assert(
        challenge_b64   => $login_opts->{challenge},
        rp_id           => $rpid,
        origin          => $origin,
        user_handle_b64 => $setup_handle,
    );
    $login_mech->post(
        "$baseurl/NoAuth/Helpers/Passkey/Login",
        {   action             => 'verify',
            credential_id      => $assertion->{credential_id_b64},
            client_data_json   => $assertion->{client_data_json_b64},
            authenticator_data => $assertion->{authenticator_data_b64},
            signature          => $assertion->{signature_b64},
            user_handle        => $assertion->{user_handle_b64},
        },
    );
    my $login_result = decode_json( $login_mech->content );
    like(
        $login_result->{error},
        qr/[Pp]asskey authentication failed/,
        'expired login challenge rejected (generic error preserved)'
    );

    my $cleanup_user = RT::User->new( RT->SystemUser );
    $cleanup_user->Load('root');
    $cleanup_user->ClearPasskeys;
}

done_testing;
