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
my $username = "testuser";
my $base     = "dc=bestpractical,dc=com";
my $dn       = "uid=$username,$base";
my $entry    = {
    cn           => $username,
    mail         => "$username\@invalid.tld",
    uid          => $username,
    objectClass  => 'User',
    userPassword => 'password',
};
$ldap->add( $base );
$ldap->add( $dn, attr => [%$entry] );

RT->Config->Set( ExternalAuthPriority        => ['My_LDAP'] );
RT->Config->Set( ExternalInfoPriority        => ['My_LDAP'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate                  => { Privileged => 1 } );
RT->Config->Set(
    ExternalSettings => {    # AN EXAMPLE DB SERVICE
        'My_LDAP' => {
            'type'            => 'ldap',
            'server'          => "127.0.0.1:$ldap_port",
            'base'            => $base,
            'filter'          => '(objectClass=*)',
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

diag "test uri login";
{
    ok( !$m->login( 'fakeuser', 'password' ), 'not logged in with fake user' );
    $m->warning_like( qr/FAILED LOGIN for fakeuser/ );
    ok( $m->login( 'testuser', 'password' ), 'logged in' );
}

diag "test user creation";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'testuser' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'testuser@invalid.tld');
}


diag "test form login";
{
    $m->logout;
    $m->get_ok( $baseurl, 'base url' );
    $m->submit_form(
        form_number => 1,
        fields      => { user => 'testuser', pass => 'password', },
    );
    $m->text_contains( 'Logout', 'logged in via form' );
}

like( $m->uri, qr!$baseurl/(index\.html)?!, 'privileged home page' );

$ldap->unbind();

done_testing;

