use strict;
use warnings;
use RT::Test tests => undef;

eval { require RT::MFA::TOTP; } or do {
    plan skip_all => 'Unable to test without RT::MFA::TOTP';
};

my ( $baseurl, $m ) = RT::Test->started_ok;

# Users need ModifySelf to manage their own profile (including MFA).
# Stock RT does not grant this by default; sites typically do.
RT::Test->add_rights(
    { Principal => 'Privileged',   Right => ['ModifySelf'] },
    { Principal => 'Unprivileged', Right => ['ModifySelf'] },
);

# --- Admin MFA policy and enrollment management ---

$m->login( 'root', 'password' );

my $admin_group = RT::Test->load_or_create_group( 'mfa_admin_test_group' );

diag 'Admin can set MFA policy for a group';
{
    $m->get_ok( $baseurl . "/Admin/Groups/MFAPolicy.html?id=" . $admin_group->Id );
    $m->content_contains( 'MFA Policy', 'MFA Policy page loads' );
    $m->submit_form_ok(
        {   form_name => 'MFAPolicy',
            fields    => { Mode => 'Required', Drift => 1 },
            button    => 'Save',
        },
        'Submit MFA policy'
    );
    $m->content_contains( 'MFA policy updated', 'Success message shown' );

    $admin_group->Load( $admin_group->Id );
    my $policy = $admin_group->MFAPolicy;
    is( $policy->{Mode},  'Required', 'Mode set to Required' );
    is( $policy->{Drift}, 1,          'Drift set to 1' );
}

diag 'Admin can reset MFA enrollment for a user';
{
    my $user = RT::Test->load_or_create_user(
        Name         => 'mfa_admin_reset_user',
        EmailAddress => 'mfa_admin_reset@example.com',
        Password     => 'password',
    );

    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $user->Id );
    $user_su->SetTOTPSecret( RT::MFA::TOTP->GenerateSecret );
    $user_su->SetTOTPEnrolled(1);
    is( $user_su->TOTPEnrolled, 1, 'User is enrolled before admin reset' );

    $m->get_ok( $baseurl . "/Admin/Users/Modify.html?id=" . $user->Id );
    $m->content_contains( 'MFA Enrollment', 'MFA section shown on user modify page' );
    $m->content_contains( 'Enrolled',       'Enrollment status shown' );
    $m->submit_form_ok( { form_name => 'mfa_admin_reset' }, 'Admin resets MFA' );
    $m->content_contains( 'MFA enrollment cleared', 'Success message shown' );

    $user_su->Load( $user->Id );
    is( $user_su->TOTPEnrolled,        0,  'User is no longer enrolled after admin reset' );
    is( $user_su->TOTPSecretDecrypted, '', 'Secret cleared after admin reset' );
}

diag 'Non-admin cannot reset another user MFA';
{
    my $unpriv = RT::Test->load_or_create_user(
        Name     => 'mfa_unpriv_reset',
        Password => 'password',
    );

    $m->logout;
    ok( $m->login( 'mfa_unpriv_reset', 'password' ), 'Logged in as non-admin' );
    my $target = RT::Test->load_or_create_user(
        Name     => 'mfa_target',
        Password => 'password',
    );
    my $target_su = RT::User->new( RT->SystemUser );
    $target_su->Load( $target->Id );
    $target_su->SetTOTPEnrolled(1);

    $m->get( $baseurl . "/Admin/Users/Modify.html?id=" . $target->Id );

    # Non-admin should be redirected or see no reset button
    ok( !$m->find_link( text_regex => qr/Reset MFA/ ) || $m->uri !~ m{/Admin/},
        'Non-admin cannot access admin user modify or sees no Reset MFA button'
      );

    # Put target in a group whose MFA policy is Optional, so the DisableMFA
    # branch would fire on a successful cross-user POST.
    my $optional_group = RT::Test->load_or_create_group('mfa_optional_target');
    $optional_group->SetMFAPolicy( Mode => 'Optional', Drift => 1 );
    $optional_group->AddMember( $target->PrincipalId )
        unless $optional_group->HasMember( $target->PrincipalId );

    $m->post( $baseurl . '/Prefs/AboutMe.html', { id => $target->Id, DisableMFA => 1 }, );
    $target_su->Load( $target->Id );
    is( $target_su->TOTPEnrolled, 1,
        'Cross-user POST to Prefs/AboutMe.html?DisableMFA does not clear target enrollment' );

    # Switch to Required so RequestReset is the active branch, then confirm
    # the cross-user POST does not trigger a reset email / cooldown attribute.
    $optional_group->SetMFAPolicy( Mode => 'Required', Drift => 1 );
    $target_su->DeleteAttribute('LastMFAResetRequest');

    $m->post( $baseurl . '/Prefs/AboutMe.html', { id => $target->Id, RequestReset => 1 }, );
    $target_su->Load( $target->Id );
    ok( !$target_su->FirstAttribute('LastMFAResetRequest'),
        'Cross-user POST to Prefs/AboutMe.html?RequestReset does not send reset email' );
}

$m->logout;

# --- Enrollment flow ---

my $enroll_group = RT::Test->load_or_create_group( 'mfa_enroll_required' );
$enroll_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

my $enroll_user = RT::Test->load_or_create_user(
    Name         => 'mfa_enroll_user',
    EmailAddress => 'mfa_enroll@example.com',
    Password     => 'enroll_password',
);
$enroll_group->AddMember( $enroll_user->PrincipalId );

diag 'Enrollment page shows QR code and base32 secret';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_enroll_user', pass => 'enroll_password' },
        },
        'Submit login'
    );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html}, 'On enrollment page' );
    $m->content_contains( 'data:image/png;base64,', 'QR code image present' );
    $m->content_contains( 'base32',                 'Base32 secret shown' );
    $m->content_contains( 'Enter the 6-digit code', 'Confirmation code field shown' );
}

diag 'Incorrect confirmation code does not enroll and preserves secret';
{
    $m->submit_form_ok(
        {   form_name => 'MFAEnroll',
            fields    => { code => '000000' },
        },
        'Submit wrong code'
    );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html}, 'Still on enrollment page' );
    $m->content_contains( 'incorrect', 'Error shown for wrong code' );

    my $user_obj = RT::User->new( RT->SystemUser );
    $user_obj->Load( $enroll_user->Id );
    is( $user_obj->TOTPEnrolled, 0, 'User not enrolled after wrong code' );
}

diag 'Correct confirmation code completes enrollment and logs in';
{
    # Extract the secret from the <code> element showing the manual entry key
    my ($secret) = $m->content =~ m{<code>([A-Z2-7]+)</code>};
    ok( $secret, "Extracted TOTP secret from page: $secret" );

    my $auth = Auth::GoogleAuth->new( { secret32 => $secret } );
    my $code = $auth->code;

    $m->submit_form_ok(
        {   form_name => 'MFAEnroll',
            fields    => { code => $code },
        },
        'Submit correct code'
    );
    unlike( $m->uri, qr{/NoAuth/MFA/}, 'No longer on MFA page after enrollment' );
    $m->content_contains( 'Logout', 'User is logged in' );

    my $user_obj = RT::User->new( RT->SystemUser );
    $user_obj->Load( $enroll_user->Id );
    is( $user_obj->TOTPEnrolled, 1, 'User is now enrolled' );
}

diag 'Enrolled Optional user can disable MFA via preferences';
{
    my $opt_group = RT::Test->load_or_create_group( 'mfa_optional_web' );
    $opt_group->SetMFAPolicy( Mode => 'Optional', Drift => 0 );

    my $opt_user = RT::Test->load_or_create_user(
        Name         => 'mfa_opt_user',
        EmailAddress => 'mfa_opt@example.com',
        Password     => 'opt_password',
    );
    $opt_group->AddMember( $opt_user->PrincipalId );

    # Enroll the optional user directly
    my $opt_user_su = RT::User->new( RT->SystemUser );
    $opt_user_su->Load( $opt_user->Id );
    $opt_user_su->SetTOTPSecret( RT::MFA::TOTP->GenerateSecret );
    $opt_user_su->SetTOTPEnrolled(1);

    # Log in (will need to verify), then go to prefs
    my $auth = Auth::GoogleAuth->new( { secret32 => $opt_user_su->TOTPSecretDecrypted } );

    $m->logout;
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_opt_user', pass => 'opt_password' },
        },
        'Submit login for optional user'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'On verify page' );
    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => $auth->code },
        },
        'Submit TOTP code'
    );
    $m->content_contains( 'Logout', 'Logged in' );

    $m->get_ok( $baseurl . '/Prefs/AboutMe.html' );
    $m->content_contains( 'Disable MFA', 'Disable button shown for Optional user' );
    $m->form_name('EditAboutMe');
    $m->click_button( name => 'DisableMFA' );
    is( $m->status, 200, 'Form submitted ok' );
    $m->content_contains( 'MFA disabled', 'Success message shown' );

    $opt_user_su->Load( $opt_user->Id );
    is( $opt_user_su->TOTPEnrolled, 0, 'User is no longer enrolled' );
}

$m->logout;

# --- Verify flow ---

my $verify_group = RT::Test->load_or_create_group( 'mfa_required_web' );
$verify_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

my $verify_user = RT::Test->load_or_create_user(
    Name         => 'mfa_verify_user',
    EmailAddress => 'mfa_verify@example.com',
    Password     => 'correct_password',
);
$verify_group->AddMember( $verify_user->PrincipalId );

diag 'Unenrolled user in Required group is redirected to enrollment after login';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login form'
    );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html}, 'Redirected to enrollment page' );
    $m->content_contains( 'Set up', 'Enrollment page shown' );
}

# Enroll the user
my $verify_secret = RT::MFA::TOTP->GenerateSecret;
{
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    $user_su->SetTOTPSecret($verify_secret);
    $user_su->SetTOTPEnrolled(1);
}

diag 'Enrolled user is shown TOTP verification page after login';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login form'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'Redirected to verify page' );
    $m->content_contains( 'Enter authentication code', 'Verify page shown' );
}

diag 'Wrong TOTP code stays on verify page with error';
{
    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => '000000' },
        },
        'Submit wrong TOTP code'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'Still on verify page' );
    $m->content_contains( 'incorrect', 'Error message shown' );
}

diag 'Correct TOTP code completes login';
{
    my $auth = Auth::GoogleAuth->new( { secret32 => $verify_secret } );
    my $code = $auth->code;
    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => $code },
        },
        'Submit correct TOTP code'
    );
    unlike( $m->uri, qr{/NoAuth/MFA/}, 'No longer on MFA page' );
    $m->content_contains( 'Logout', 'User is logged in' );
}

diag 'MFA lockout persists across new login session';
{
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login form'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'On verify page' );

    for my $n ( 1 .. $RT::MFA::TOTP::MAX_VERIFY_ATTEMPTS ) {
        $m->submit_form(
            form_name => 'MFAVerify',
            fields    => { code => '000000' },
        );
    }

    unlike( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'Redirected away after lockout' );
    $m->next_warning_like( qr/MFA lockout for user mfa_verify_user/, 'Lockout warning logged' );

    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    my ( $locked, $remaining ) = $user_su->IsMFALockedOut;
    ok( $locked,        'User row records lockout' );
    cmp_ok( $remaining, '>', 0, 'Remaining seconds reported' );

    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form(
        form_name => 'login',
        fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
    );
    $m->content_contains( 'username or password is incorrect',
        'Re-login refused while locked out (generic message)' );
    unlike( $m->uri, qr{/NoAuth/MFA/}, 'Not redirected to MFA page while locked' );
    $m->next_warning_like( qr/MFA lockout active/, 'Re-login block warning logged' );

    $user_su->ClearMFAFailedAttempts;
}

diag 'Nonce mismatch counts toward lockout';
{
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login form'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'On verify page' );

    $m->submit_form(
        form_name => 'MFAVerify',
        fields    => { code => '000000', nonce => 'forged-nonce' },
    );
    $m->content_contains( 'Invalid request', 'Nonce mismatch shown to user' );

    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    my $attr = $user_su->FirstAttribute('MFAFailedAttempts');
    ok( $attr && $attr->Content->{Count} >= 1, 'Failure count incremented on nonce mismatch' );

    $user_su->ClearMFAFailedAttempts;
}

diag 'Direct navigation to protected page with MFAPending redirects to verify';
{
    # Log out first so we start from a clean session
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );

    # Start fresh session with MFA pending
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login form'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'On verify page' );

    # Try to navigate away
    $m->get( $baseurl . '/index.html' );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'Redirected back to verify page' );
}

diag 'Lost access link sends reset email';
{
    RT::Test->clean_caught_mails;

    # Get to verify page with pending session
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'mfa_verify_user', pass => 'correct_password' },
        },
        'Submit login'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'On verify page' );

    $m->follow_link_ok( { text_regex => qr/Lost access/ }, 'Click lost access link' );
    like( $m->uri, qr{/NoAuth/MFA/Reset/Request\.html}, 'On reset request page' );
    $m->submit_form_ok( { form_name => 'MFAResetRequest' }, 'Submit reset request' );
    $m->content_contains( 'email', 'Confirmation message shown' );

    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'One reset email sent' );
    my ($reset_url) = $mails[0] =~ m{(\Q$baseurl\E/NoAuth/MFA/Reset/\S+)}x;
    ok( $reset_url, "Extracted reset URL: $reset_url" );

    $m->get_ok($reset_url);
    $m->content_contains( 'Confirm reset', 'Reset confirmation page shown' );
    $m->submit_form_ok( {}, 'Submit reset confirmation' );
    $m->content_contains( 'MFA enrollment has been cleared', 'Reset success shown' );

    my $user_obj = RT::User->new( RT->SystemUser );
    $user_obj->Load( $verify_user->Id );
    is( $user_obj->TOTPEnrolled,        0,  'Enrollment cleared after reset' );
    is( $user_obj->TOTPSecretDecrypted, '', 'Secret cleared after reset' );
}

diag 'Expired MFA reset token is rejected';
{
    # Re-enroll the user
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    $user_su->SetTOTPSecret($verify_secret);
    $user_su->SetTOTPEnrolled(1);

    # Generate the token directly (bypasses cooldown and email)
    my $token = $user_su->CreateMFAResetToken;
    ok( $token, 'Generated MFA reset token' );

    # Set a very short expiry so we can test token rejection
    RT::Test->set_config( ResetLinkExpirySeconds => 1 );

    # Wait for the token to expire
    sleep 2;

    my $reset_url = $baseurl . '/NoAuth/MFA/Reset/' . $token . '/' . $user_su->Id;
    $m->get_ok($reset_url);
    $m->content_contains( 'Invalid or expired', 'Expired token is rejected' );
    $m->next_warning_like( qr/Invalid or expired/, 'Expiry warning logged' );

    # Restore default expiry
    RT::Test->set_config( ResetLinkExpirySeconds => undef );
}

diag 'Disabled user cannot use an MFA reset link';
{
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    $user_su->SetTOTPSecret($verify_secret);
    $user_su->SetTOTPEnrolled(1);

    # Disable first, then generate token — so the token matches current state
    # but the Disabled check in the dhandler rejects it.
    my ( $ok, $msg ) = $user_su->SetDisabled(1);
    ok( $ok, "Disabled user: $msg" );

    my $token = $user_su->CreateMFAResetToken;
    ok( $token, 'Generated MFA reset token for disabled user' );

    my $reset_url = $baseurl . '/NoAuth/MFA/Reset/' . $token . '/' . $user_su->Id;
    $m->get_ok($reset_url);
    $m->content_contains( 'Invalid or expired', 'Disabled user reset link rejected' );
    $m->next_warning_like( qr/Invalid or expired/, 'Rejection warning logged' );

    # Re-enable for remaining tests
    ( $ok, $msg ) = $user_su->SetDisabled(0);
    ok( $ok, "Re-enabled user: $msg" );
}

diag 'REST 1.0 login is rejected when MFA is required';
{
    # Re-enroll the user so MFA is active
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $verify_user->Id );
    $user_su->SetTOTPSecret($verify_secret);
    $user_su->SetTOTPEnrolled(1);

    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->post( "$baseurl/REST/1.0/ticket/new", [
        user   => 'mfa_verify_user',
        pass   => 'correct_password',
        format => 'l',
    ]);
    $m->content_contains( 'MFA is required', 'REST 1.0 login rejected with MFA message' );
    $m->content_contains( 'authentication token', 'Suggests using auth token' );
    $m->warning_like( qr/REST login rejected.*MFA required/, 'REST 1.0 rejection logged' );
}

diag 'REST 2.0 login is rejected when MFA is required';
{
    require MIME::Base64;
    my $auth = 'Basic ' . MIME::Base64::encode_base64( 'mfa_verify_user:correct_password', '' );

    # Use a fresh mech without any session cookies
    my $m2 = RT::Test::Web->new;
    $m2->get( "$baseurl/REST/2.0/rt", 'Authorization' => $auth );
    is( $m2->status, 401, 'REST 2.0 returns 401' );
    $m2->warning_like( qr/REST login rejected.*MFA required/, 'REST 2.0 rejection logged' );
}

# --- Self-service flow ---

my $ss_group = RT::Test->load_or_create_group( 'mfa_selfservice_group' );
$ss_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

my $ss_user = RT::Test->load_or_create_user(
    Name         => 'mfa_ss_unpriv',
    EmailAddress => 'mfa_ss_unpriv@example.com',
    Password     => 'unpriv_pass',
    Privileged   => 0,
);
$ss_group->AddMember( $ss_user->PrincipalId );

RT::Test->set_config( SelfServiceUserPrefs => 'edit-prefs' );

diag 'Unprivileged user with Required MFA is redirected to enrollment on login';
{
    $m->login( 'mfa_ss_unpriv', 'unpriv_pass' );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html}, 'Redirected to enrollment page' );
}

diag 'Unprivileged user can complete MFA enrollment';
{
    my ($secret) = $m->content =~ m{<code>([A-Z2-7]+)</code>};
    ok( $secret, "Extracted TOTP secret: $secret" );

    my $auth = Auth::GoogleAuth->new( { secret32 => $secret } );
    $m->submit_form_ok(
        {   form_name => 'MFAEnroll',
            fields    => { code => $auth->code },
        },
        'Submit correct enrollment code'
    );
    unlike( $m->uri, qr{/NoAuth/MFA/}, 'No longer on MFA page' );
    like( $m->uri, qr{/SelfService/}, 'Redirected to SelfService' );
}

diag 'Unprivileged user sees MFA status on SelfService prefs';
{
    $m->get_ok( $baseurl . '/SelfService/Prefs.html' );
    $m->content_contains( 'Two-Factor Authentication', 'MFA section shown' );
    $m->content_contains( 'Enrolled',                  'Enrollment status shown' );
}

diag 'Unprivileged user can request MFA reset from SelfService prefs';
{
    RT::Test->clean_caught_mails;

    $m->get_ok( $baseurl . '/SelfService/Prefs.html' );
    $m->content_contains( 'Reset MFA enrollment via email', 'Reset button shown for Required enrolled user' );

    $m->post_ok( $baseurl . '/SelfService/Prefs.html', { RequestReset => 'Reset MFA enrollment via email' } );
    $m->content_contains( 'reset link has been sent', 'Success message shown' );

    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'One reset email sent' );
}

# --- REMOTE_USER tests (requires server restart with different config) ---

RT::Test->stop_server;

RT->Config->Set( WebRemoteUserAuth       => 1 );
RT->Config->Set( WebRemoteUserContinuous => 1 );
RT->Config->Set( WebFallbackToRTLogin    => 1 );
RT->Config->Set( WebRemoteUserAutocreate => 0 );

( $baseurl, $m ) = RT::Test->started_ok( basic_auth => 'anon' );

my $remote_group = RT::Test->load_or_create_group( 'mfa_remote_group' );
$remote_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );

my $remote_user = RT::Test->load_or_create_user(
    Name         => 'mfa_remote_user',
    EmailAddress => 'mfa_remote@example.com',
    Password     => 'test_password',
);
$remote_group->AddMember( $remote_user->PrincipalId );

diag 'REMOTE_USER login bypasses MFA enforcement even with Required policy';
{
    $m->auth('mfa_remote_user');
    $m->get_ok($baseurl);
    $m->content_contains( 'Logout', 'Logged in via REMOTE_USER' );
    unlike $m->uri, qr{/NoAuth/MFA/}, 'Not redirected to MFA page';
}

diag 'REMOTE_USER login bypasses MFA even when user is enrolled';
{
    my $secret  = RT::MFA::TOTP->GenerateSecret;
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load( $remote_user->Id );
    $user_su->SetTOTPSecret($secret);
    $user_su->SetTOTPEnrolled(1);

    $m->auth('');
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );

    $m->auth('mfa_remote_user');
    $m->get_ok($baseurl);
    $m->content_contains( 'Logout', 'Logged in via REMOTE_USER with TOTP enrolled' );
    unlike $m->uri, qr{/NoAuth/MFA/}, 'Not redirected to MFA verify page';
}

diag 'MFA controls are hidden on About Me page for REMOTE_USER session';
{
    $m->get_ok( $baseurl . '/Prefs/AboutMe.html' );
    $m->content_lacks( 'Two-Factor Authentication', 'MFA section not shown' );
    $m->content_lacks( 'Disable MFA',               'No MFA controls shown' );
    $m->content_lacks( 'Set up MFA',                'No enrollment link shown' );
}

diag 'Password login still enforces MFA for the same user';
{
    $m->auth('');
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );

    $m->login( 'mfa_remote_user', 'test_password', no_redirect => 1 );
    like $m->uri, qr{/NoAuth/MFA/Verify\.html}, 'Password login redirects to MFA verify';
}

# Ensure we're logged in for the final warnings check
$m->auth("root");
undef $m;
RT::Test->stop_server;

done_testing;
