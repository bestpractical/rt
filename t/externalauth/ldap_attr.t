use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};

my $ldap_port = RT::Test->find_idle_port;
ok( my $server = Net::LDAP::Server::Test->new( $ldap_port, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port" );

my $ldap = Net::LDAP->new( "localhost:$ldap_port" );
$ldap->bind();

my $username = 'testldapuser';
my $email    = "$username\@example.com";
my $password = 'password';
my $base     = 'dc=bestpractical,dc=com';
my $dn       = "uid=$username,$base";
my $entry    = {
    cn           => $username,
    mail         => $email,
    uid          => $username,
    objectClass  => 'User',
    userPassword => $password,
};

$ldap->add( $base );
$ldap->add( $dn, attr => [%$entry] );

RT->Config->Set( ExternalAuthPriority        => ['My_LDAP'] );
RT->Config->Set( ExternalInfoPriority        => ['My_LDAP'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate  => undef );
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

# create user, but don't set the email address.
# after authentication, email address will be retrieved from LDAP and set for
# the user by CanonicalizeUserInfo.
my $testuser = RT::User->new( $RT::SystemUser );
my ( $uid, $msg ) = $testuser->Create(
    Name => $username,
);
ok( $uid, "created $username" );
$testuser->SetEmailAddress('');
ok( !$testuser->EmailAddress, "$username email address is not set" );

diag 'test login with Name';
$m->get_ok( $baseurl, 'base url' );
$m->submit_form(
    form_number => 1,
    fields      => { user => $username, pass => 'password', },
);
$m->text_contains( 'Logout', 'logged in via form' );
is( $m->uri, $baseurl . '/SelfService/' , 'selfservice page is displayed' );

my $verifyuser = RT::User->new( $RT::SystemUser );
$verifyuser->Load( $username );
is( $verifyuser->EmailAddress, $email, "$username email address was retrieved from LDAP after authentication" );

diag 'test login with EmailAddress';
$m->logout;
$m->get_ok( $baseurl, 'base url' );
$m->submit_form(
    form_number => 1,
    fields      => { user => $email, pass => 'password', },
);
is( $m->uri, $baseurl . '/SelfService/' , 'selfservice page is displayed' );

$ldap->unbind();

done_testing;
