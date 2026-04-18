use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};
eval { require RT::MFA::TOTP; 1 } or do {
    plan skip_all => 'Unable to test without RT::MFA::TOTP';
};

my $ldap_port = RT::Test->find_idle_port;
ok( my $server = Net::LDAP::Server::Test->new( $ldap_port, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port" );

my $ldap = Net::LDAP->new("localhost:$ldap_port");
$ldap->bind();

my $base     = 'dc=bestpractical,dc=com';
my $username = 'testuser';
$ldap->add($base);
$ldap->add(
    "uid=$username,$base",
    attr => [
        cn           => $username,
        mail         => "$username\@invalid.tld",
        uid          => $username,
        objectClass  => 'User',
        userPassword => 'password',
    ]
);

RT->Config->Set( ExternalAuthPriority => ['My_LDAP'] );
RT->Config->Set( ExternalInfoPriority => ['My_LDAP'] );
RT->Config->Set( AutoCreate           => undef );
RT->Config->Set(
    ExternalSettings => {
        'My_LDAP' => {
            'type'            => 'ldap',
            'server'          => "127.0.0.1:$ldap_port",
            'base'            => $base,
            'filter'          => '(objectClass=*)',
            'd_filter'        => '()',
            'tls'             => 0,
            'net_ldap_args'   => [ version => 3 ],
            'attr_match_list' => [ 'Name', 'EmailAddress' ],
            'attr_map'        => {
                'Name'         => 'uid',
                'EmailAddress' => 'mail',
            }
        },
    }
);
RT->Config->PostLoadCheck;

my ( $baseurl, $m ) = RT::Test->started_ok();

my $testuser = RT::Test->load_or_create_user(
    Name         => $username,
    EmailAddress => "$username\@invalid.tld",
    Privileged   => 0,
);
ok( $testuser->Id, 'created user testuser' );

my $mfa_group = RT::Test->load_or_create_group('ldap_mfa_group');
my ( $ret, $msg ) = $mfa_group->AddMember( $testuser->Id );
ok( $ret, "added testuser to ldap_mfa_group: $msg" );
( $ret, $msg ) = $mfa_group->SetMFAPolicy( Mode => 'Required', Drift => 0 );
ok( $ret, "set MFA policy to Required: $msg" );

diag 'LDAP login of an unenrolled user goes to MFA enrollment';
{
    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => $username, pass => 'password' },
        },
        'submit LDAP login'
    );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html$}, 'redirected to MFA enrollment' );
    ok( $m->form_name('MFAEnroll'), 'enrollment form shown' );

    $m->get_ok( $baseurl . '/SelfService/' );
    like( $m->uri, qr{/NoAuth/MFA/Enroll\.html$}, 'other pages redirect to MFA enrollment' );
}

my $secret = RT::MFA::TOTP->GenerateSecret;
( $ret, $msg ) = $testuser->SetTOTPSecret($secret);
ok( $ret, "set TOTP secret: $msg" );
( $ret, $msg ) = $testuser->SetTOTPEnrolled(1);
ok( $ret, "enrolled testuser: $msg" );

diag 'LDAP login of an enrolled user requires a TOTP code';
{
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->get_ok( $baseurl . '/SelfService/Closed.html', 'closed tickets page' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => $username, pass => 'password' },
        },
        'submit LDAP login'
    );
    like( $m->uri, qr{/NoAuth/MFA/Verify\.html$}, 'redirected to MFA verification' );
    ok( !$m->logged_in_as($username), 'not logged in before TOTP verification' );

    $m->submit_form_ok(
        {   form_name => 'MFAVerify',
            fields    => { code => Auth::GoogleAuth->new( { secret32 => $secret } )->code },
        },
        'submit TOTP code'
    );
    is( $m->uri, $baseurl . '/SelfService/Closed.html', 'redirected to the requested page' );
    ok( $m->logged_in_as($username), 'logged in as testuser' );
}

diag 'REST 1.0 LDAP login is rejected when MFA is required';
{
    $m->get_ok( $baseurl . '/NoAuth/Logout.html' );
    $m->post( "$baseurl/REST/1.0/ticket/new", [ user => $username, pass => 'password', format => 'l' ] );
    like(
        $m->content,
        qr{\ART/\S+ 401 Credentials required\n\nMFA is required for your account\. Use an authentication token for API access\.\n\z},
        'REST 1.0 login rejected with MFA message'
    );
    $m->warning_like( qr/REST login rejected for testuser: MFA required/, 'MFA rejection logged once' );
}

diag 'LDAP login of an MFA-locked user is refused once';
{
    $testuser->ReserveMFAAttempt for 1 .. $RT::MFA::TOTP::MAX_VERIFY_ATTEMPTS;
    ok( ( $testuser->IsMFALockedOut )[0], 'testuser is locked out of MFA' );

    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => $username, pass => 'password' },
        },
        'submit LDAP login'
    );
    like( $m->uri, qr{/NoAuth/Login\.html}, 'stays on the login page' );
    $m->text_contains( 'Your username or password is incorrect', 'generic login error shown' );
    $m->warning_like( qr/Login blocked for testuser from .*: MFA lockout active/, 'only the lockout is logged' );

    ok( $testuser->ClearMFAFailedAttempts, 'cleared MFA failed attempts' );
}

diag 'LDAP login skips MFA when the policy is Optional and the user is not enrolled';
{
    ( $ret, $msg ) = $mfa_group->SetMFAPolicy( Mode => 'Optional', Drift => 0 );
    ok( $ret, "set MFA policy to Optional: $msg" );
    ( $ret, $msg ) = $testuser->ClearTOTPEnrollment;
    ok( $ret, "cleared TOTP enrollment: $msg" );

    $m->get_ok( $baseurl . '/NoAuth/Login.html' );
    $m->submit_form_ok(
        {   form_name => 'login',
            fields    => { user => $username, pass => 'password' },
        },
        'submit LDAP login'
    );
    is( $m->uri, $baseurl . '/SelfService/', 'logged in without MFA' );
    ok( $m->logged_in_as($username), 'logged in as testuser' );
}

$ldap->unbind();

done_testing;
