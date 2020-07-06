use strict;
use warnings;
use IO::Socket::INET;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};

my $ldap_port = RT::Test->find_idle_port;
my $ldap_socket = IO::Socket::INET->new(
    Listen    => 5,
    Proto     => 'tcp',
    Reuse     => 1,
    LocalPort => $ldap_port,
);
ok( my $server = Net::LDAP::Server::Test->new( $ldap_socket, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port" );

my $ldap = Net::LDAP->new("localhost:$ldap_port") || die "Failed to connect to LDAP server: $@";
$ldap->bind();

my $base = 'dc=bestpractical,dc=com';

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
                'RealName'     => 'cn',
                'Gecos'        => 'uid',
                'NickName'     => 'nick',
            }
        },
    }
);
RT->Config->PostLoadCheck;

my ( $baseurl, $m ) = RT::Test->started_ok();

my $username = 'testuser';
my $email    = "$username\@example.com";
my $name     = 'Test LDAP User';
my $nick     = 'test';
my $password = 'password';
my $dn       = "uid=$username,$base";
my $entry    = {
    cn           => $name,
    mail         => $email,
    uid          => $username,
    objectClass  => 'User',
    userPassword => $password,
    nick         => $nick,
};

$ldap->add($base);
$ldap->add( $dn, attr => [%$entry] );

diag 'test autocreate';

ok( $m->login( $email, 'password' ), 'Logged in with auto-created user' );
is( $m->uri, $baseurl . '/SelfService/', 'selfservice page is displayed' );

my $user = RT::User->new($RT::SystemUser);
$user->Load($username);

is( $user->Name,         $username, "$username was autocreated with Name retrieved from LDAP" );
is( $user->EmailAddress, $email,    "$username was autocreated with EmailAddress retrieved from LDAP" );
is( $user->RealName,     $name,     "$username was autocreated with RealName retrieved from LDAP" );
is( $user->Gecos,        $username, "$username was autocreated with Gecos retrieved from LDAP" );
is( $user->NickName,     $nick,     "$username was autocreated with NickName retrieved from LDAP" );

diag "test user update on login";

ok( $user->SetName("testldapuser") );
ok( $user->SetNickName("testldapuser") );

ok( $m->login( $email, 'password', logout => 1 ), 'Logged in again' );
ok( $m->logout, 'logged out' );

$user->Load( $user->Id );
is( $user->Name, $username, 'Username is updated' );
is( $user->NickName, $nick, 'Username is updated' );

$ldap->unbind();

done_testing;
