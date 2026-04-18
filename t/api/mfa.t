use strict;
use warnings;
use RT::Test tests => undef;

eval { require RT::MFA::TOTP; 1; } or do {
    plan skip_all => 'Unable to test without RT::MFA::TOTP';
};

diag 'TOTPEnrolled column exists and defaults to 0';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_col_test',
        Password => 'password',
    );
    ok( $user->Id, 'Created test user' );
    is( $user->TOTPEnrolled,        0,  'TOTPEnrolled defaults to 0' );
    is( $user->TOTPSecretDecrypted, '', 'TOTPSecret is empty by default' );
}

diag 'SetTOTPEnrolled and SetTOTPSecret work';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_set_test',
        Password => 'password',
    );
    my ( $ok, $msg ) = $user->SetTOTPEnrolled(1);
    ok( $ok, "SetTOTPEnrolled succeeded: $msg" );
    is( $user->TOTPEnrolled, 1, 'TOTPEnrolled is now 1' );

    ( $ok, $msg ) = $user->SetTOTPSecret('JBSWY3DPEHPK3PXP');
    ok( $ok, "SetTOTPSecret succeeded: $msg" );
    like(
        $user->__Value('TOTPSecret'),
        qr/^gcm:[0-9a-f]+:[0-9a-f]+:[0-9a-f]+$/,
        'TOTPSecret is stored encrypted with AES-256-GCM'
    );
    is( $user->TOTPSecretDecrypted, 'JBSWY3DPEHPK3PXP', 'TOTPSecretDecrypted returns plaintext' );
}

diag 'GenerateSecret returns a valid base32 string';
{
    my $secret = RT::MFA::TOTP->GenerateSecret;
    ok( $secret, 'GenerateSecret returns a value' );
    like( $secret, qr/^[A-Z2-7]+=*$/, 'Secret is valid base32' );
    ok( length($secret) >= 16, 'Secret is at least 16 chars' );
}

diag 'QRCodeURI returns an otpauth:// URI';
{
    my $user = RT::Test->load_or_create_user(
        Name         => 'totp_qr_test',
        EmailAddress => 'totp_qr@example.com',
        Password     => 'password',
    );
    my $uri = RT::MFA::TOTP->QRCodeURI(
        Secret => 'JBSWY3DPEHPK3PXP',
        User   => $user,
    );
    like( $uri, qr{^otpauth://totp/},        'QRCodeURI returns otpauth URI' );
    like( $uri, qr{secret=JBSWY3DPEHPK3PXP}, 'URI contains the secret' );
}

diag 'QRCodeSVG returns inline SVG markup';
{
    my $user = RT::Test->load_or_create_user(
        Name         => 'totp_qr2_test',
        EmailAddress => 'totp_qr2@example.com',
        Password     => 'password',
    );
    my $svg = RT::MFA::TOTP->QRCodeSVG(
        Secret => 'JBSWY3DPEHPK3PXP',
        User   => $user,
    );
    like( $svg, qr{^<svg\b[^>]*>}, 'QRCodeSVG returns an <svg> element' );
    like( $svg, qr{</svg>$},       'QRCodeSVG is a complete SVG document' );
    like( $svg, qr{<rect\b},       'SVG contains module rects' );
}

diag 'VerifyCode accepts a valid code and rejects an invalid one';
{
    my $secret = 'JBSWY3DPEHPK3PXP';
    my $auth   = Auth::GoogleAuth->new( { secret32 => $secret } );
    my $code   = $auth->code;

    ok( RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => $code,
            Drift  => 0,
        ),
        'VerifyCode accepts current valid code'
      );

    ok( !RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => '000000',
            Drift  => 0,
        ),
        'VerifyCode rejects obviously wrong code'
      );
}

diag 'VerifyCode respects Drift';
{
    my $secret = 'JBSWY3DPEHPK3PXP';
    my $auth   = Auth::GoogleAuth->new( { secret32 => $secret } );

    # Code for 90 seconds ago (3 windows back)
    my $old_code = $auth->code( undef, time() - 90 );

    ok( RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => $old_code,
            Drift  => 3,           # ±3 windows, covers 3 windows back
        ),
        'VerifyCode accepts code within Drift'
      );

    ok( !RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => $old_code,
            Drift  => 0,           # current window only, won't cover 3 windows back
        ),
        'VerifyCode rejects code outside Drift'
      );
}

diag 'EffectiveMFAPolicy falls back to global config';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_policy_test',
        Password => 'password',
    );

    # No group policies set; global default is Off/1
    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Off', 'Default mode is Off' );
    is( $policy->{Drift}, 0,     'Default Drift is 0' );
}

diag 'EffectiveMFAPolicy uses most restrictive group policy';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_policy_merge',
        Password => 'password',
    );

    my $group_opt = RT::Test->load_or_create_group('mfa_optional_group');
    $group_opt->SetMFAPolicy( Mode => 'Optional', Drift => 1 );
    $group_opt->AddMember( $user->PrincipalId );

    my $group_req = RT::Test->load_or_create_group('mfa_required_group');
    $group_req->SetMFAPolicy( Mode => 'Required', Drift => 0 );
    $group_req->AddMember( $user->PrincipalId );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Required', 'Required beats Optional' );
    is( $policy->{Drift}, 0,          'Minimum Drift wins (0 < 1)' );

    # Disable the Required group; only the Optional group's policy should remain.
    $group_req->SetDisabled(1);
    $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Optional', 'Disabled group policy is excluded from merge' );
    is( $policy->{Drift}, 1,          'Drift comes from the remaining enabled group' );
    $group_req->SetDisabled(0);
}

diag 'ClearTOTPEnrollment clears both columns';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_clear_test',
        Password => 'password',
    );
    $user->SetTOTPSecret('JBSWY3DPEHPK3PXP');
    $user->SetTOTPEnrolled(1);
    is( $user->TOTPEnrolled,        1,                  'TOTPEnrolled is 1 before clear' );
    is( $user->TOTPSecretDecrypted, 'JBSWY3DPEHPK3PXP', 'TOTPSecret set before clear' );

    my ( $ok, $msg ) = $user->ClearTOTPEnrollment;
    ok( $ok, "ClearTOTPEnrollment succeeded: $msg" );
    is( $user->TOTPEnrolled,          0,  'TOTPEnrolled is 0 after clear' );
    is( $user->__Value('TOTPSecret'), '', 'TOTPSecret is empty after clear' );
}

diag 'VerifyCode replay protection rejects reused code';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_replay_test',
        Password => 'password',
    );
    my $secret = 'JBSWY3DPEHPK3PXP';
    $user->SetTOTPSecret($secret);
    $user->SetTOTPEnrolled(1);

    my $auth = Auth::GoogleAuth->new( { secret32 => $secret } );
    my $code = $auth->code;

    ok( RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => $code,
            Drift  => 0,
            User   => $user,
        ),
        'First use of code succeeds'
      );

    ok( !RT::MFA::TOTP->VerifyCode(
            Secret => $secret,
            Code   => $code,
            Drift  => 0,
            User   => $user,
        ),
        'Second use of same code is rejected (replay protection)'
      );
}

diag 'ClearTOTPEnrollment clears TOTPLastUsedWindow attribute';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_clear_window_test',
        Password => 'password',
    );
    my $secret = 'JBSWY3DPEHPK3PXP';
    $user->SetTOTPSecret($secret);
    $user->SetTOTPEnrolled(1);

    my $auth = Auth::GoogleAuth->new( { secret32 => $secret } );
    my $code = $auth->code;

    RT::MFA::TOTP->VerifyCode(
        Secret => $secret,
        Code   => $code,
        Drift  => 0,
        User   => $user,
    );

    my $attr = $user->FirstAttribute('TOTPLastUsedWindow');
    ok( $attr && defined $attr->Content, 'TOTPLastUsedWindow set after verify' );

    $user->ClearTOTPEnrollment;

    $attr = $user->FirstAttribute('TOTPLastUsedWindow');
    ok( !$attr, 'TOTPLastUsedWindow cleared after ClearTOTPEnrollment' );
}

diag 'ValidateMFAResetToken validates token';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_validate_token_test',
        Password => 'password',
    );
    $user->SetTOTPSecret('JBSWY3DPEHPK3PXP');
    $user->SetTOTPEnrolled(1);

    my $token = $user->CreateMFAResetToken;
    ok( $user->ValidateMFAResetToken( Token  => $token ),  'Current token validates' );
    ok( !$user->ValidateMFAResetToken( Token => 'bogus' ), 'Bogus token rejected' );
    ok( !$user->ValidateMFAResetToken( Token => undef ),   'Undef token rejected' );
}

diag 'CreateMFAResetToken returns a token that changes after enrollment is cleared';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'totp_token_test',
        Password => 'password',
    );
    $user->SetTOTPSecret('JBSWY3DPEHPK3PXP');
    $user->SetTOTPEnrolled(1);

    my $token1 = $user->CreateMFAResetToken;
    ok( $token1, 'CreateMFAResetToken returns a token' );
    like( $token1, qr/^[0-9a-f]{64}$/, 'Token is a sha256 hex string' );

    $user->ClearTOTPEnrollment;
    my $token2 = $user->CreateMFAResetToken;
    isnt( $token1, $token2, 'Token changes after enrollment is cleared' );
}

# --- Group MFA policy tests ---

my $group = RT::Test->load_or_create_group('mfa_policy_test');

diag 'MFAPolicy returns undef when not set';
{
    is( $group->MFAPolicy, undef, 'MFAPolicy is undef by default' );
}

diag 'SetMFAPolicy stores the policy';
{
    my ( $ok, $msg ) = $group->SetMFAPolicy( Mode => 'Required', Drift => 1 );
    ok( $ok, "SetMFAPolicy succeeded: $msg" );

    my $policy = $group->MFAPolicy;
    ok( $policy, 'MFAPolicy returns a hashref' );
    is( $policy->{Mode},  'Required', 'Mode is Required' );
    is( $policy->{Drift}, 1,          'Drift is 1' );
}

diag 'SetMFAPolicy rejects invalid Mode';
{
    my ( $ok, $msg ) = $group->SetMFAPolicy( Mode => 'Invalid', Drift => 0 );
    ok( !$ok, 'SetMFAPolicy rejects invalid Mode' );
    like( $msg, qr/invalid mode/i, 'Error message mentions invalid mode' );
}

diag 'SetMFAPolicy rejects out-of-range values';
{
    my ( $ok, $msg ) = $group->SetMFAPolicy( Mode => 'Required', Drift => 6 );
    ok( !$ok, 'SetMFAPolicy rejects Drift > 5' );
    like( $msg, qr/drift/i, 'Error message mentions Drift' );

    ( $ok, $msg ) = $group->SetMFAPolicy( Mode => 'Required', Drift => -1 );
    ok( !$ok, 'SetMFAPolicy rejects negative Drift' );
}

diag 'SetMFAPolicy requires AdminGroup right';
{
    my $unpriv_user = RT::Test->load_or_create_user(
        Name     => 'mfa_unpriv',
        Password => 'password',
    );
    my $unpriv_group = RT::Group->new( RT::CurrentUser->new($unpriv_user) );
    $unpriv_group->Load( $group->Id );

    my ( $ok, $msg ) = $unpriv_group->SetMFAPolicy( Mode => 'Off', Drift => 0 );
    ok( !$ok, 'SetMFAPolicy denied without AdminGroup right' );
    like( $msg, qr/permission denied/i, 'Permission denied error' );
}

diag 'ResetMFAPolicy removes the policy';
{
    my ( $ok, $msg ) = $group->ResetMFAPolicy;
    ok( $ok, "ResetMFAPolicy succeeded: $msg" );
    is( $group->MFAPolicy, undef, 'MFAPolicy is undef after reset' );
}

diag 'SetMFAPolicy is a no-op when nothing changed and records transactions otherwise';
{
    my $g = RT::Test->load_or_create_group('MFAPolicyTxnGroup');

    my $count_txns = sub {
        my $txns = $g->Transactions;
        $txns->Limit( FIELD => 'Type',  VALUE => 'Set' );
        $txns->Limit( FIELD => 'Field', VALUE => 'MFAPolicy' );
        return $txns->Count;
    };

    is( $count_txns->(), 0, 'No MFAPolicy transactions yet' );

    my ( $ok, $msg ) = $g->SetMFAPolicy( Mode => 'Optional', Drift => 1 );
    ok( $ok, "First SetMFAPolicy succeeded: $msg" );
    like( $msg, qr/updated/i, 'Message mentions updated on first set' );
    is( $count_txns->(), 1, 'One transaction recorded after first set' );

    ( $ok, $msg ) = $g->SetMFAPolicy( Mode => 'Optional', Drift => 1 );
    ok( $ok, 'Repeated SetMFAPolicy with same values returned ok' );
    like( $msg, qr/Nothing changed/i, 'Message says Nothing changed when no diff' );
    is( $count_txns->(), 1, 'No new transaction when nothing changed' );

    ( $ok, $msg ) = $g->SetMFAPolicy( Mode => 'Required', Drift => 1 );
    ok( $ok, "Changed SetMFAPolicy succeeded: $msg" );
    is( $count_txns->(), 2, 'New transaction recorded on actual change' );

    ( $ok, $msg ) = $g->ResetMFAPolicy;
    ok( $ok, "ResetMFAPolicy succeeded: $msg" );
    like( $msg, qr/reset/i, 'Message mentions reset' );
    is( $count_txns->(), 3, 'Transaction recorded on reset' );

    ( $ok, $msg ) = $g->ResetMFAPolicy;
    ok( $ok, 'ResetMFAPolicy on no-policy returned ok' );
    like( $msg, qr/Nothing changed/i, 'Message says Nothing changed when no policy to reset' );
    is( $count_txns->(), 3, 'No new transaction on redundant reset' );
}

diag 'Default-only MFAPolicy config works for all users';
{
    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Required', Drift => 1 } } );

    my $priv_user = RT::Test->load_or_create_user(
        Name       => 'mfa_default_priv',
        Privileged => 1
    );

    my $unpriv_user = RT::Test->load_or_create_user(
        Name       => 'mfa_default_unpriv',
        Privileged => 0
    );

    my $policy = $priv_user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Required', 'Privileged user gets Default Mode when no Privileged key' );
    is( $policy->{Drift}, 1,          'Privileged user gets Default Drift' );

    $policy = $unpriv_user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Required', 'Unprivileged user gets Default Mode when no Unprivileged key' );
    is( $policy->{Drift}, 1,          'Unprivileged user gets Default Drift' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'Privileged MFAPolicy config key applied to privileged user';
{
    RT->Config->Set(
        'MFAPolicy',
        {   Default    => { Mode => 'Off',      Drift => 0 },
            Privileged => { Mode => 'Required', Drift => 1 },
        }
    );

    my $user = RT::Test->load_or_create_user(
        Name       => 'mfa_priv_user',
        Privileged => 1
    );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Required', 'Privileged user gets Privileged Mode' );
    is( $policy->{Drift}, 1,          'Privileged user gets Privileged Drift' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'Unprivileged MFAPolicy config key applied to unprivileged user';
{
    RT->Config->Set(
        'MFAPolicy',
        {   Default      => { Mode => 'Off',      Drift => 0 },
            Unprivileged => { Mode => 'Optional', Drift => 1 },
        }
    );

    my $user = RT::Test->load_or_create_user(
        Name       => 'mfa_unpriv_user',
        Privileged => 0
    );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Optional', 'Unprivileged user gets Unprivileged Mode' );
    is( $policy->{Drift}, 1,          'Unprivileged user gets Unprivileged Drift' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'Privileged user falls back to Default MFAPolicy when Privileged key absent';
{
    RT->Config->Set(
        'MFAPolicy',
        {   Default      => { Mode => 'Optional', Drift => 1 },
            Unprivileged => { Mode => 'Off',      Drift => 0 },
        }
    );

    my $user = RT::Test->load_or_create_user(
        Name       => 'mfa_priv_fallback',
        Privileged => 1
    );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Optional', 'Privileged user falls back to Default Mode' );
    is( $policy->{Drift}, 1,          'Privileged user falls back to Default Drift' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'Hardcoded MFAPolicy fallback when no matching key and no Default';
{
    RT->Config->Set( 'MFAPolicy', { Unprivileged => { Mode => 'Required', Drift => 1 }, } );

    my $user = RT::Test->load_or_create_user(
        Name       => 'mfa_no_default',
        Privileged => 1
    );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Off', 'Falls back to hardcoded Mode Off' );
    is( $policy->{Drift}, 0,     'Falls back to hardcoded Drift 0' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'Group MFA policy takes precedence over Privileged config';
{
    RT->Config->Set(
        'MFAPolicy',
        {   Default    => { Mode => 'Off',      Drift => 0 },
            Privileged => { Mode => 'Optional', Drift => 1 },
        }
    );

    my $mfa_group = RT::Test->load_or_create_group('MFAOverrideGroup');
    $mfa_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

    my $user = RT::Test->load_or_create_user(
        Name       => 'mfa_group_override',
        Privileged => 1
    );
    $mfa_group->AddMember( $user->PrincipalId );

    my $policy = $user->EffectiveMFAPolicy;
    is( $policy->{Mode},  'Required', 'Group policy Mode overrides Privileged config' );
    is( $policy->{Drift}, 0,          'Group policy Drift overrides Privileged config' );

    RT->Config->Set( 'MFAPolicy', { Default => { Mode => 'Off', Drift => 0 } } );
}

diag 'MFA failed-attempt counter persists and time-elapsed unlock';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'mfa_lockout_api',
        Password => 'password',
    );

    my ( $count, $locked );

    for my $n ( 1 .. $RT::MFA::TOTP::MAX_VERIFY_ATTEMPTS - 1 ) {
        ( $count, $locked ) = $user->RecordFailedMFAAttempt;
        is( $count, $n, "Attempt $n recorded" );
        ok( !$locked, "Not yet locked at attempt $n" );
    }

    ( $count, $locked ) = $user->RecordFailedMFAAttempt;
    is( $count, $RT::MFA::TOTP::MAX_VERIFY_ATTEMPTS, 'Reached MAX_VERIFY_ATTEMPTS' );
    ok( $locked, 'Locked at MAX_VERIFY_ATTEMPTS' );

    my ( $is_locked, $remaining ) = $user->IsMFALockedOut;
    ok( $is_locked, 'IsMFALockedOut returns locked' );
    cmp_ok( $remaining, '>', 0, 'Remaining seconds reported' );

    # Backdate the most-recent-failure timestamp past the lockout window
    # to simulate the interval elapsing without sleeping in tests.
    $user->SetAttribute(
        Name    => 'MFAFailedAttempts',
        Content => {
            Count => $count,
            At    => time - $RT::MFA::TOTP::LOCKOUT_INTERVAL - 1
        },
    );

    ( $is_locked, $remaining ) = $user->IsMFALockedOut;
    ok( !$is_locked, 'Lockout auto-clears after interval' );
    is( $remaining, 0, 'Remaining is 0' );

    ok( !$user->FirstAttribute('MFAFailedAttempts'), 'Attribute cleared as side effect' );
}

diag 'ClearTOTPEnrollment also clears failed-attempt state';
{
    my $user = RT::Test->load_or_create_user(
        Name     => 'mfa_clear_lockout',
        Password => 'password',
    );

    $user->RecordFailedMFAAttempt;
    ok( $user->FirstAttribute('MFAFailedAttempts'), 'Failure recorded' );

    $user->ClearTOTPEnrollment;
    ok( !$user->FirstAttribute('MFAFailedAttempts'), 'ClearTOTPEnrollment clears failure state' );
}

done_testing;
