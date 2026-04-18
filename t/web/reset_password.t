use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok( disable_config_cache => 1 );

# Create a test user with a password
my $user = RT::Test->load_or_create_user(
    Name         => 'pwreset_test',
    EmailAddress => 'pwreset@example.com',
    Password     => 'oldpassword',
);
ok( $user->Id,          'Created test user' );
ok( $user->HasPassword, 'User has a password' );

diag 'Request page loads';
{
    $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Request.html' );
    $m->content_contains( 'Reset your password', 'Request page title present' );
    $m->content_contains( 'Email address',       'Email field present' );
}

diag 'Forgot password link appears on login page';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->content_contains( 'Forgot password', 'Forgot password link present' );
}

diag 'Default HidePasswordResetErrors masks errors for unknown email';
{
    RT::Test->clean_caught_mails;
    $m->post_ok( $baseurl . '/NoAuth/ResetPassword/Request.html', { Email => 'nobody@example.com' }, );
    $m->content_contains( 'RT has sent you an email message', 'Generic success shown for unknown email by default' );
    $m->content_lacks( 'Unable to send new password email', 'Specific error not shown by default' );
    $m->warning_like( qr/Password reset attempted for non-existent user/, 'got expected warning for unknown email' );
    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 0, 'No email sent for unknown address' );
}

diag 'Disabling HidePasswordResetErrors shows specific errors';
{
    RT::Test->set_config( HidePasswordResetErrors => 0 );

    RT::Test->clean_caught_mails;
    $m->post_ok( $baseurl . '/NoAuth/ResetPassword/Request.html', { Email => 'nobody@example.com' }, );
    $m->content_contains( 'Unable to send new password email',
        'Error shown for unknown email when HidePasswordResetErrors is off' );
    $m->warning_like( qr/Password reset attempted for non-existent user/, 'got expected warning for unknown email' );
    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 0, 'No email sent for unknown address' );
}

diag 'Disabled user cannot request a password reset';
{
    my $disabled_user = RT::Test->load_or_create_user(
        Name         => 'disabled_pwreset',
        EmailAddress => 'disabled_pwreset@example.com',
        Password     => 'password123',
    );
    my ( $ok, $msg ) = $disabled_user->SetDisabled(1);
    ok( $ok, "Disabled user: $msg" );

    RT::Test->clean_caught_mails;
    $m->post_ok( $baseurl . '/NoAuth/ResetPassword/Request.html', { Email => 'disabled_pwreset@example.com' }, );
    $m->content_contains( "can&#39;t reset your password", 'Disabled user error shown' );
    $m->warning_like( qr/Disabled user.*attempted to reset password/, 'Disabled user warning logged' );
    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 0, 'No email sent for disabled user' );
}

diag 'Disabled user cannot use a reset link';
{
    my $user_su = RT::User->new( RT->SystemUser );
    $user_su->Load('pwreset_test');

    # Disable first, then generate token — so the token matches current state
    # but the Disabled check in the dhandler rejects it
    my ( $ok, $msg ) = $user_su->SetDisabled(1);
    ok( $ok, "Disabled user: $msg" );

    my $token = $user_su->CreateResetPasswordToken;
    ok( $token, 'Generated reset token for disabled user' );

    my $link = $baseurl . '/NoAuth/ResetPassword/Reset/' . $token . '/' . $user_su->Id;
    $m->get_ok($link);
    $m->content_contains( 'Something went wrong', 'Disabled user reset link rejected' );

    # Re-enable for remaining tests
    ( $ok, $msg ) = $user_su->SetDisabled(0);
    ok( $ok, "Re-enabled user: $msg" );
}

diag 'Submitting valid email sends reset email';
my $reset_url;
{
    RT::Test->clean_caught_mails;
    $m->post_ok( $baseurl . '/NoAuth/ResetPassword/Request.html', { Email => 'pwreset@example.com' }, );
    $m->content_contains( 'RT has sent you an email message', 'Success message shown' );

    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'One email sent' );
    if (@mails) {
        like( $mails[0], qr{NoAuth/ResetPassword/Reset/}, 'Email contains reset URL' );
        ($reset_url) = $mails[0] =~ m{(\Q$baseurl\E/NoAuth/ResetPassword/Reset/\S+)}x;
        ok( $reset_url, "Extracted reset URL from email: $reset_url" );
    } else {
        ok( 0, 'No email sent - cannot extract reset URL' );
        ok( 0, 'Extracted reset URL from email' );
    }
}

diag 'Reset URL sets cookie and redirects';
{
    $m->max_redirect(0);
    $m->get($reset_url);
    is( $m->status, 302, 'Reset URL with token redirects' );
    $m->max_redirect(7);
}

diag 'Following redirect shows the password form';
{
    $m->get_ok($reset_url);
    $m->content_contains( 'New password',    'Password form shown' );
    $m->content_contains( 'Retype Password', 'Retype field shown' );
}

diag 'Mismatched passwords show error';
{
    $m->submit_form_ok(
        {   fields => {
                password  => 'newpassword1',
                password2 => 'DIFFERENT',
            },
        },
        'Submit mismatched passwords'
    );
    $m->content_contains( 'didn&#39;t match', 'Mismatch error shown' );
}

diag 'Correct passwords update the password';
{
    $m->get_ok($reset_url);
    $m->submit_form_ok(
        {   fields => {
                password  => 'newpassword123',
                password2 => 'newpassword123',
            },
        },
        'Submit matching passwords'
    );
    $m->content_contains( 'Password changed', 'Success message shown' );
    $m->content_lacks( 'New password', 'Form is gone after success' );

    # Verify new password works
    ok( $m->login( 'pwreset_test', 'newpassword123' ), 'Can log in with new password' );
    $m->logout;
}

diag 'Old password no longer works';
{
    ok( !$m->login( 'pwreset_test', 'oldpassword' ), 'Old password rejected' );
    $m->next_warning_like( qr/FAILED LOGIN for pwreset_test/, 'got expected warning for failed login' );
}

diag 'Admin: UnsetPassword and SendPasswordResetEmail via Modify.html';
{
    ok( $m->login, 'Logged in as root' );

    # Reload user to get current state
    $user = RT::User->new( RT->SystemUser );
    $user->Load('pwreset_test');
    ok( $user->HasPassword, 'User has password' );

    # Delete password via admin UI
    $m->get_ok( $baseurl . '/Admin/Users/Modify.html?id=' . $user->Id );
    $m->content_contains( 'Password is set', 'Password status shown' );
    $m->submit_form_ok(
        {   form_name => 'UserModify',
            fields    => { DeleteUserPassword => 1 },
        },
        'Submit DeleteUserPassword'
    );
    $m->content_contains( 'Password unset', 'Password deleted message shown' );

    $user = RT::User->new( RT->SystemUser );
    $user->Load('pwreset_test');
    ok( !$user->HasPassword, 'User password is cleared' );

    # Send reset email via admin UI
    RT::Test->clean_caught_mails;
    $m->get_ok( $baseurl . '/Admin/Users/Modify.html?id=' . $user->Id );
    $m->content_contains( 'No password set', 'Password status updated' );
    $m->submit_form_ok(
        {   form_name => 'UserModify',
            fields    => { SendPasswordResetEmail => 1 },
        },
        'Submit SendPasswordResetEmail'
    );
    $m->content_contains( 'Password reset email sent', 'Reset email sent message shown' );
    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'One email sent via admin reset' );
}

diag 'Admin Users index: password filter';
{
    $m->get_ok( $baseurl . '/Admin/Users/index.html' );
    $m->content_contains( 'List users with a password set', 'Password filter checkbox present' );
    $m->logout;
}

diag 'Tampered token is rejected';
{
    my $u = RT::Test->load_or_create_user(
        Name         => 'tamper_test',
        EmailAddress => 'tamper@example.com',
        Password     => 'oldpassword',
    );

    my $token = $u->CreateResetPasswordToken;
    ok( $token, 'Generated reset token' );

    # Flip one hex digit so the resulting string is still a plausible token
    my $tampered = $token;
    my $flip     = substr( $tampered, 0, 1 ) eq 'a' ? 'b' : 'a';
    substr( $tampered, 0, 1 ) = $flip;
    isnt( $tampered, $token, 'Tampered token differs' );

    $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Reset/' . $tampered . '/' . $u->Id );
    $m->content_contains( 'Invalid or expired', 'Tampered token rejected' );
    $m->next_warning_like( qr/Invalid or expired/, 'Rejection warning logged' );
}

diag 'Expired token is rejected';
{
    my $u = RT::Test->load_or_create_user(
        Name         => 'expired_token_test',
        EmailAddress => 'expired_token@example.com',
        Password     => 'oldpassword',
    );

    my $token = $u->CreateResetPasswordToken;
    ok( $token, 'Generated reset token' );

    # Set a very short expiry so we can test token rejection
    RT::Test->set_config( ResetLinkExpirySeconds => 1 );
    sleep 2;

    $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Reset/' . $token . '/' . $u->Id );
    $m->content_contains( 'Invalid or expired', 'Expired token rejected' );
    $m->next_warning_like( qr/Invalid or expired/, 'Rejection warning logged' );

    # Restore default expiry
    RT::Test->set_config( ResetLinkExpirySeconds => undef );
}

diag 'Replay after success: reused URL is rejected';
{
    my $u = RT::Test->load_or_create_user(
        Name         => 'replay_test',
        EmailAddress => 'replay@example.com',
        Password     => 'oldpassword',
    );

    my $token = $u->CreateResetPasswordToken;
    my $url   = $baseurl . '/NoAuth/ResetPassword/Reset/' . $token . '/' . $u->Id;

    $m->get_ok($url);
    $m->submit_form_ok(
        { fields => { password => 'newpassword456', password2 => 'newpassword456' } },
        'Submit matching passwords'
    );
    $m->content_contains( 'password has been changed', 'First use succeeds' );

    # SetPassword bumps LastUpdated, so the same URL no longer matches.
    my $m2 = RT::Test::Web->new;
    $m2->get_ok($url);
    $m2->content_contains( 'Invalid or expired', 'Reused URL rejected after success' );
    $m2->next_warning_like( qr/Invalid or expired/, 'Rejection warning logged' );
}

diag 'Mismatched user-id-vs-token is rejected';
{
    my $userA = RT::Test->load_or_create_user(
        Name         => 'mismatch_a',
        EmailAddress => 'mismatch_a@example.com',
        Password     => 'oldpassword',
    );
    my $userB = RT::Test->load_or_create_user(
        Name         => 'mismatch_b',
        EmailAddress => 'mismatch_b@example.com',
        Password     => 'oldpassword',
    );

    my $token_a = $userA->CreateResetPasswordToken;

    # Use userA's token but userB's ID — token won't match userB's state
    $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Reset/' . $token_a . '/' . $userB->Id );
    $m->content_contains( 'Invalid or expired', 'Cross-user token rejected' );
    $m->next_warning_like( qr/Invalid or expired/, 'Rejection warning logged' );
}

diag 'Throttle: rapid double request only sends one email';
{
    RT::Test->load_or_create_user(
        Name         => 'throttle_test',
        EmailAddress => 'throttle@example.com',
        Password     => 'oldpassword',
    );

    RT::Test->clean_caught_mails;

    my $m = RT::Test::Web->new;
    for my $n ( 1 .. 2 ) {
        $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Request.html' );
        $m->submit_form_ok(
            {   form_name => 'ResetPasswordRequest',
                fields    => { Email => 'throttle@example.com' },
            },
            "Reset request $n"
        );
        $m->content_contains( 'RT has sent you an email message', "Generic success $n" );
    }

    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'Only one email sent for rapid double request (cooldown enforced)' );
}

diag 'ResetPasswordCreateNewUserAndSetPassword creates user for unknown email';
{
    RT::Test->set_config( ResetPasswordCreateNewUserAndSetPassword => 1 );

    RT::Test->clean_caught_mails;

    $m->get_ok( $baseurl . '/NoAuth/ResetPassword/Request.html' );
    $m->submit_form_ok(
        {   form_name => 'ResetPasswordRequest',
            fields    => { Email => 'newaccount@example.com' },
        },
        'Reset request for previously-unknown email'
    );
    $m->content_contains( 'RT has sent you an email message', 'Success shown' );
    $m->logout;
    my $new_user = RT::User->new( RT->SystemUser );
    $new_user->LoadByEmail('newaccount@example.com');
    ok( $new_user->Id, 'New user created for previously-unknown email' );

    my @mails = RT::Test->fetch_caught_mails;
    is( scalar @mails, 1, 'Reset email sent to new user' );

}

diag 'DisableResetPasswordOnLogin hides link and blocks request page';
{
    RT::Test->set_config( DisableResetPasswordOnLogin => 1 );

    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->content_lacks( 'Forgot password', 'Forgot password link hidden' );

    $m->get( $baseurl . '/NoAuth/ResetPassword/Request.html' );
    unlike( $m->uri, qr{ResetPassword/Request}, 'Request page redirects when disabled' );

    RT::Test->set_config( DisableResetPasswordOnLogin => undef );
}

done_testing;
