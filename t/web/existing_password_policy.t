use strict;
use warnings;
use RT::Test tests => undef;
use Test::Warn;

my ( $baseurl, $m ) = RT::Test->started_ok( disable_config_cache => 1 );

# Reset a user's password without going through ValidatePassword. Used to
# put noncompliant passwords back in place after compliance-change tests
# without flipping PasswordPolicy off and on around every assignment.
sub reset_password {
    my ( $name, $pass ) = @_;
    my $u = RT::User->new( RT->SystemUser );
    $u->Load($name);
    $u->_Set( Field => 'Password', Value => $u->_GeneratePassword($pass) );
}

# Users used across blocks. Created before PasswordPolicy is in effect so
# the noncompliant 'weakpass' is accepted during creation; later blocks
# rely on reset_password to restore it after a compliance change.
my $weak_user = RT::Test->load_or_create_user(
    Name         => 'weak_pw_user',
    EmailAddress => 'weak@example.com',
    Password     => 'weakpass',           # 8 chars, no upper/digit/symbol
    Privileged   => 1,
);
ok( $weak_user->Id, 'Created weak-password user' );

my $strong_user = RT::Test->load_or_create_user(
    Name         => 'strong_pw_user',
    EmailAddress => 'strong@example.com',
    Password     => 'StrongPass1A',         # meets the policy below
    Privileged   => 1,
);

# The policy used by every block except the bogus-action and group-policy
# blocks, which override it. Set once and left alone.
RT::Test->set_config(
    PasswordPolicy => { Default => { MinLength => 10, RequireUpper => 1, RequireDigit => 1 } } );

# === ignore ===
RT::Test->set_config( ExistingPasswordPolicyAction => 'ignore' );

diag 'ignore (default): noncompliant login produces no flash, no marker';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => 'weak_pw_user', pass => 'weakpass' },
        },
        'Login as weak_pw_user under ignore'
    );
    $m->content_lacks( 'no longer meets the current password policy', 'No flash shown under ignore' );
}

diag 'invalid action value is rejected at startup and falls back to ignore';
{
    # set_config triggers ApplyConfigChangeToAllServerProcesses ->
    # LoadConfigFromDatabase -> PostLoadCheck. For an invalid value the
    # PostLoadCheck logs a warning and normalizes the value to 'ignore',
    # so wrap the call to capture the warning.
    warning_like {
        RT::Test->set_config( ExistingPasswordPolicyAction => 'bogus' );
    }
    qr/Invalid \$ExistingPasswordPolicyAction value 'bogus'/, 'PostLoadCheck warns about invalid action value';
    is( RT->Config->Get('ExistingPasswordPolicyAction'),
        'ignore', 'Invalid value normalized to ignore by PostLoadCheck' );

    # Reset the DB row so the running server doesn't re-encounter 'bogus'
    # on its next config refresh and emit the same warning again.
    RT::Test->set_config( ExistingPasswordPolicyAction => 'ignore' );

    $m->login( weak_pw_user => 'weakpass', logout => 1 );
    $m->content_lacks( 'no longer meets the current password policy', 'No flash after normalization to ignore' );
}

# === notify ===
RT::Test->set_config( ExistingPasswordPolicyAction => 'notify' );

diag 'notify: noncompliant login produces a flash on the first page';
{
    $m->login( weak_pw_user => 'weakpass', logout => 1 );
    $m->content_contains( 'no longer meets the current password policy', 'Flash shown under notify' );
}

diag 'notify: compliant login produces no flash';
{
    $m->login( strong_pw_user => 'StrongPass1A', logout => 1 );
    $m->content_lacks( 'no longer meets the current password policy', 'No flash for compliant password' );
}

diag 'priv compliance page: no marker -> silent redirect away';
{
    # Compliant user has no violation marker; hitting the page should
    # silently redirect away.
    $m->login( strong_pw_user => 'StrongPass1A', logout => 1 );
    unlike( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Compliant user silently redirected away' );
    $m->content_lacks( 'meets the current password policy', 'No revealing message on silent redirect' );
}

diag 'priv compliance page: marker set -> form shown, valid POST clears marker';
{
    $m->login( weak_pw_user => 'weakpass', logout => 1 );
    $m->get_ok( $baseurl . '/Prefs/ExistingPasswordChange.html' );
    $m->content_contains( 'New password', 'Form shown when marker set' );

    # Invalid new password keeps the marker
    $m->submit_form_ok(
        {   form_name => 'ExistingPasswordChange',
            fields    => { Password => 'short', PasswordConfirm => 'short' },
        },
        'Submit noncompliant new password'
    );
    $m->content_contains( 'Password needs to be at least', 'Policy error shown for noncompliant new password' );

    # Valid new password clears the marker and redirects
    $m->submit_form_ok(
        {   form_name => 'ExistingPasswordChange',
            fields    => { Password => 'NewStrong1Pass', PasswordConfirm => 'NewStrong1Pass' },
        },
        'Submit compliant new password'
    );
    unlike( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Redirected away after compliant change' );

    # Re-fetching the page should now silently redirect (marker cleared)
    $m->get( $baseurl . '/Prefs/ExistingPasswordChange.html' );
    unlike( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Marker cleared after compliant change' );

    # Verify the new password actually took
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('weak_pw_user');
    ok( $u->IsPassword('NewStrong1Pass'), 'New password persisted' );

    reset_password( weak_pw_user => 'weakpass' );
}

# Unprivileged users used in the next several blocks. Create with a
# compliant password (so the policy doesn't reject creation) and then
# reset to 'weakpass' for tests that need a noncompliant password.
my $unpriv_weak = RT::Test->load_or_create_user(
    Name         => 'unpriv_weak',
    EmailAddress => 'unpriv_weak@example.com',
    Password     => 'StrongPass1A',
    Privileged   => 0,
);
ok( $unpriv_weak->Id, 'Created unprivileged user' );
reset_password( unpriv_weak => 'weakpass' );

my $unpriv_strong = RT::Test->load_or_create_user(
    Name         => 'unpriv_strong',
    EmailAddress => 'unpriv_strong@example.com',
    Password     => 'StrongPass1A',
    Privileged   => 0,
);

diag 'unpriv compliance page: marker set -> form shown, valid POST clears marker';
{
    $m->login( unpriv_weak => 'weakpass', logout => 1 );

    $m->get_ok( $baseurl . '/SelfService/ExistingPasswordChange.html' );
    $m->content_contains( 'New password', 'Form shown for unpriv user' );

    $m->submit_form_ok(
        {   form_name => 'ExistingPasswordChange',
            fields    => { Password => 'NewStrong1Pass', PasswordConfirm => 'NewStrong1Pass' },
        },
        'Submit compliant new password'
    );
    unlike( $m->uri, qr{/SelfService/ExistingPasswordChange\.html}, 'Redirected away after compliant change' );

    reset_password( unpriv_weak => 'weakpass' );
}

diag 'unpriv compliance page: no marker -> silent redirect';
{
    $m->login( unpriv_strong => 'StrongPass1A', logout => 1 );
    $m->get( $baseurl . '/SelfService/ExistingPasswordChange.html' );
    unlike(
        $m->uri,
        qr{/SelfService/ExistingPasswordChange\.html},
        'Compliant unpriv user silently redirected away'
    );
}

diag 'notify flash links to per-privilege compliance page';
{
    # Privileged
    $m->login( weak_pw_user => 'weakpass', logout => 1 );

    ok( $m->find_link( url_regex => qr{/Prefs/ExistingPasswordChange\.html} ),
        'Notify flash links to /Prefs/ExistingPasswordChange.html for priv user'
    );

    # Unprivileged
    $m->login( unpriv_weak => 'weakpass', logout => 1 );

    ok( $m->find_link( url_regex => qr{/SelfService/ExistingPasswordChange\.html} ),
        'Notify flash links to /SelfService/ExistingPasswordChange.html for unpriv user'
    );
}

diag 'notify: REST is unaffected';
{
    $m->get_ok( $baseurl . '/REST/1.0/?user=weak_pw_user&pass=weakpass', 'REST/1.0 succeeds under notify' );

    # The REST/1.0 URL-param login above tagged the session as a REST
    # client (session{REST}=1), which would block any later browser-style
    # login on this same $m. Drop the cookie so following blocks start
    # fresh.
    $m->cookie_jar->clear;
}

# === force ===
RT::Test->set_config( ExistingPasswordPolicyAction => 'force' );

diag 'force: bypass list reaches compliance page, NoAuth paths, and static assets';
{
    $m->login( weak_pw_user => 'weakpass', logout => 1 );
    like(
        $m->uri,
        qr{/Prefs/ExistingPasswordChange\.html},
        'Compliance page reachable under force (no redirect loop)'
    );
    $m->content_contains( 'New password', 'Change-password form rendered' );

    # Static assets must not be intercepted; the compliance form needs them.
    $m->get_ok(
        $baseurl . '/static/images/bpslogo.png',
        'Static asset reachable under force'
    );
    like(
        $m->uri,
        qr{/static/images/bpslogo\.png},
        'Static asset URL not redirected'
    );

    # Other NoAuth paths must reach their handler rather than the compliance page.
    $m->get( $baseurl . '/NoAuth/iCal/foo' );
    unlike(
        $m->uri,
        qr{/Prefs/ExistingPasswordChange\.html},
        'NoAuth path not redirected to compliance page'
    );
}

diag 'force: unprivileged user reaches SelfService compliance page directly';
{
    my $force_unpriv = RT::Test->load_or_create_user(
        Name         => 'force_unpriv',
        EmailAddress => 'force_unpriv@example.com',
        Password     => 'StrongPass1A',
        Privileged   => 0,
    );
    reset_password( force_unpriv => 'weakpass' );

    $m->login( force_unpriv => 'weakpass', logout => 1 );

    like(
        $m->uri,
        qr{/SelfService/ExistingPasswordChange\.html},
        'SelfService compliance page reachable under force (no redirect loop)'
    );
    $m->content_contains( 'New password', 'SelfService change-password form rendered' );
}

diag 'force: priv user redirected to compliance page on every request';
{
    $m->login( weak_pw_user => 'weakpass', logout => 1 );

    # Try to navigate elsewhere; the gate should bounce us back
    $m->get( $baseurl . '/Search/Build.html' );
    like(
        $m->uri,
        qr{/Prefs/ExistingPasswordChange\.html},
        'Force gate redirects arbitrary navigation to compliance page'
    );

    # Logout still works
    $m->get_ok( $baseurl . '/NoAuth/Logout.html', 'Logout reachable under force' );
}

diag 'force: compliant change releases the gate';
{
    $m->login( weak_pw_user => 'weakpass', logout => 1 );

    # Navigate somewhere -> redirected to compliance
    $m->get( $baseurl . '/Search/Build.html' );
    like( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Gate engaged' );

    # Submit a compliant new password
    $m->submit_form_ok(
        {   form_name => 'ExistingPasswordChange',
            fields    => { Password => 'NewStrong1Pass', PasswordConfirm => 'NewStrong1Pass' },
        },
        'Compliant change'
    );

    # Now navigation should be unimpeded
    $m->get_ok( $baseurl . '/Search/Build.html', 'Gate released after compliant change' );
    unlike( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Not redirected anymore' );

    reset_password( weak_pw_user => 'weakpass' );
}

diag 'force: REST/1.0 username+password rejected with policy message';
{
    $m->logout;
    $m->get( $baseurl . '/REST/1.0/?user=weak_pw_user&pass=weakpass' );
    $m->content_contains( 'RT/' . $RT::VERSION . ' 401 Credentials required',
        'REST/1.0 reply is the standard 401 body' );
    $m->content_contains( 'no longer meets the current password policy', 'REST/1.0 reply mentions policy' );
    $m->warning_like( qr/REST login rejected.*existing password violates policy/,
        'REST/1.0 policy rejection logged' );
}

diag 'force: REST/2.0 username+password rejected';
{
    $m->logout;
    # Clear the post-logout session cookie so the request looks like a
    # plain API client; otherwise REST/2.0 unauthorized() sees HTTP_COOKIE
    # and returns a browser 302 instead of a 401.
    $m->cookie_jar->clear;
    $m->auth( 'weak_pw_user', 'weakpass' );
    $m->get( $baseurl . '/REST/2.0/queues/all' );
    is( $m->status, 401, 'REST/2.0 returns 401 under force' );
    $m->warning_like( qr/REST login rejected.*existing password violates policy/, 'REST/2.0 force-reject logged' );
}

diag 'force: REST/2.0 with a web session cookie is rejected';
{
    # Clear the Basic-Auth header left by $m->auth in the previous block;
    # otherwise REST/2.0 would fall through cookie auth into Basic auth and
    # log a second rejection warning.
    $m->default_headers->remove_header('Authorization');

    $m->login( weak_pw_user => 'weakpass', logout => 1 );

    # Confirm the gate is engaged for normal web traffic (proves the marker
    # + cookie are in place) before trying REST/2.0.
    $m->get( $baseurl . '/Search/Build.html' );
    like( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'Web gate engaged (confirms cookie+marker state)' );

    # Reuse the same cookie against REST/2.0; must not grant API access.
    $m->requests_redirectable( [] );
    $m->get( $baseurl . '/REST/2.0/queues/all' );
    is( $m->status, 401, 'REST/2.0 cookie-auth returns 401 under force + violation' );
    $m->warning_like( qr{REST/2\.0 cookie auth rejected.*existing password violates policy},
        'REST/2.0 cookie-auth rejection logged' );

    # Same thing against REST/1.0: instead of redirecting an API client to
    # the HTML compliance page, the force gate should respond with a
    # plain-text 401 carrying the policy message.
    $m->get( $baseurl . '/REST/1.0/user/weak_pw_user' );
    is( $m->status, 401, 'REST/1.0 cookie-auth returns 401 under force + violation' );
    $m->content_contains( 'RT/' . $RT::VERSION . ' 401 Credentials required',
        'REST/1.0 cookie-auth reply is the standard 401 body' );
    $m->content_contains( 'no longer meets the current password policy',
        'REST/1.0 cookie-auth reply mentions policy' );
    $m->warning_like( qr{REST request rejected.*existing password violates policy},
        'REST/1.0 cookie-auth rejection logged' );

    # Restore default redirect-following so later blocks don't see the 302s
    # the cookie/REST cases above intentionally suppressed.
    $m->requests_redirectable( [ 'GET', 'HEAD', 'POST' ] );
}

diag 'force: REST/2.0 auth-token access is unaffected';
{
    # Auth tokens are intentionally NOT gated by the existing-password
    # policy: a token isn't a password, so routing through the compliance
    # page doesn't apply. Pin that contract here.
    #
    # Clear the gated cookie left by the previous block; otherwise REST/2.0
    # tries cookie auth first, logs a (correct) rejection, and only then
    # falls through to the token. The token still works, but the unconsumed
    # warning trips the end-of-test no-warnings check.
    $m->cookie_jar->clear;

    my $token = RT::AuthToken->new( RT->SystemUser );
    my ( $ok, $msg, $authstring ) = $token->Create(
        Owner       => $weak_user->Id,
        Description => 'existing-password-policy test token',
    );
    ok( $ok, "Created auth token: $msg" );
    ok( $authstring, 'Got an authstring' );

    $m->get( $baseurl . '/REST/2.0/rt', 'Authorization' => "token $authstring" );
    is( $m->status, 200, 'REST/2.0 auth-token request succeeds under force + violation' );
}

# === MFA + force ===
diag 'MFA + force: violation survives MFA verification';

SKIP: {
    eval { require RT::MFA::TOTP; } or skip 'No RT::MFA::TOTP', 4;

    RT::Test->set_config( MFAPolicy => { Default => { Mode => 'Required', Drift => 1 } } );

    my $u = RT::User->new( RT->SystemUser );
    $u->Load('weak_pw_user');
    my $secret = RT::MFA::TOTP->GenerateSecret;
    $u->SetTOTPSecret($secret);
    $u->SetTOTPEnrolled(1);

    $m->login( weak_pw_user => 'weakpass', logout => 1 );
    like( $m->uri, qr{/NoAuth/MFA/Verify}, 'Routed to MFA verify' );

    my $auth = Auth::GoogleAuth->new( { secret32 => $u->TOTPSecretDecrypted } );
    my $code = $auth->code;

    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => $code },
        },
        'Verify TOTP'
    );
    like( $m->uri, qr{/Prefs/ExistingPasswordChange\.html}, 'After MFA, force gate routes to compliance page' );

    # Reset enrollment for the next block (re-enrolls there)
    $u->SetTOTPEnrolled(0);
    $u->SetTOTPSecret('');
}

# === MFA + notify ===
RT::Test->set_config( ExistingPasswordPolicyAction => 'notify' );

diag 'notify + MFA: flash shown after MFA verification';

SKIP: {
    eval { require RT::MFA::TOTP; } or skip 'No RT::MFA::TOTP', 4;

    # MFAPolicy still 'Required' from the previous block.
    my $u = RT::User->new( RT->SystemUser );
    $u->Load('weak_pw_user');
    my $secret = RT::MFA::TOTP->GenerateSecret;
    $u->SetTOTPSecret($secret);
    $u->SetTOTPEnrolled(1);
    $u->DeleteAttribute('TOTPLastUsedWindow');

    $m->login( weak_pw_user => 'weakpass', logout => 1 );

    my $auth = Auth::GoogleAuth->new( { secret32 => $u->TOTPSecretDecrypted } );
    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => $auth->code },
        },
        'Verify TOTP'
    );
    $m->content_contains( 'no longer meets the current password policy',
        'Flash shown after MFA verification under notify' );
    ok( $m->find_link( url_regex => qr{/Prefs/ExistingPasswordChange\.html} ),
        'Flash includes link to compliance page' );

    $u->SetTOTPEnrolled(0);
    $u->SetTOTPSecret('');
}

# === group policy ===
RT::Test->set_config( MFAPolicy => { Default => { Mode => 'Off', Drift => 1 } } );

diag 'group policy triggers existing-password enforcement';
{
    # Lax global policy so only the group's policy is restrictive.
    RT::Test->set_config( PasswordPolicy => { Default => { MinLength => 5 } } );
    # ExistingPasswordPolicyAction is already 'notify' from the previous block.

    my $group = RT::Test->load_or_create_group('strict_pw_group');
    $group->SetPasswordPolicy(
        MinLength    => 12,
        RequireUpper => 1,
        RequireDigit => 1,
    );

    my $user = RT::Test->load_or_create_user(
        Name         => 'group_weak_user',
        EmailAddress => 'group_weak@example.com',
        Password     => 'short1A',                  # 7 chars: fails 12-char min
        Privileged   => 1,
    );
    $group->AddMember( $user->PrincipalId );

    $m->login( group_weak_user => 'short1A', logout => 1 );
    $m->content_contains( 'no longer meets the current password policy',
        'Group policy triggers notify enforcement' );
}

done_testing;
