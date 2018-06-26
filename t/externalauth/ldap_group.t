use strict;
use warnings;

# This lets us change config during runtime without restarting
BEGIN {
    $ENV{RT_TEST_WEB_HANDLER} = 'inline';
}

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};


my $ldap_port = RT::Test->find_idle_port;
ok( my $server = Net::LDAP::Server::Test->new( $ldap_port, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port" );

my $ldap = Net::LDAP->new("localhost:$ldap_port");
$ldap->bind();

my $users_dn = "ou=users,dc=bestpractical,dc=com";
my $group_dn = "cn=test group,ou=groups,dc=bestpractical,dc=com";

$ldap->add($users_dn);
for (1 .. 3) {
    my $uid = "testuser$_";
    my $entry    = {
        cn           => "Test User $_",
        mail         => "$uid\@example.com",
        uid          => $uid,
        objectClass  => 'User',
        userPassword => 'password',
    };
    $ldap->add( "uid=$uid,$users_dn", attr => [%$entry] );
}

$ldap->add(
    $group_dn,
    attr => [
        cn          => "test group",
        memberDN    => [ "uid=testuser1,$users_dn" ],
        memberUid   => [ "testuser2" ],
        objectClass => 'Group',
    ],
);

$ldap->add(
    "cn=subgroup,$group_dn",
    attr => [
        cn          => "subgroup",
        memberUid   => [ "testuser3" ],
        objectClass => "group",
    ],
);

RT->Config->Set( ExternalAuthPriority        => ['My_LDAP'] );
RT->Config->Set( ExternalInfoPriority        => ['My_LDAP'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate  => undef );
RT->Config->Set(
    ExternalSettings => {
        'My_LDAP' => {
            'type'            => 'ldap',
            'server'          => "127.0.0.1:$ldap_port",
            'base'            => $users_dn,
            'filter'          => '(objectClass=*)',
            'd_filter'        => '()',
            'group'           => $group_dn,
            'group_attr'      => 'memberDN',
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

diag "Using DN to match group membership";
diag "test uri login";
{
    ok( !$m->login( 'fakeuser', 'password' ), 'not logged in with fake user' );
    $m->warning_like(qr/FAILED LOGIN for fakeuser/);
    
    ok( !$m->login( 'testuser2', 'password' ), 'not logged in with real user not in group' );
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/FAILED LOGIN for testuser2/);
    
    ok( $m->login( 'testuser1', 'password' ), 'logged in' );
}

diag "test user creation";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'testuser1' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'testuser1@example.com');
}

$m->logout;

diag "Using uid to match group membership";

RT->Config->Get('ExternalSettings')->{My_LDAP}{group_attr} = 'memberUid';
RT->Config->Get('ExternalSettings')->{My_LDAP}{group_attr_value} = 'uid';
diag "test uri login";
{
    ok( !$m->login( 'testuser1', 'password' ), 'not logged in with real user not in group' );
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/FAILED LOGIN for testuser1/);

    ok( $m->login( 'testuser2', 'password' ), 'logged in' );
}

$m->logout;

diag "Subgroup isn't used with default group_scope of base";
{
    local $TODO = 'Net::LDAP::Server::Test bug: https://rt.cpan.org/Ticket/Display.html?id=78612'
        if $Net::LDAP::Server::Test::VERSION <= 0.13;
    ok( !$m->login( 'testuser3', 'password' ), 'not logged in from subgroup' );
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/LDAP_NO_SUCH_OBJECT/);
    $m->next_warning_like(qr/FAILED LOGIN for testuser3/);
    $m->logout;
}

diag "Using group_scope of sub not base";

RT->Config->Get('ExternalSettings')->{My_LDAP}{group_scope} = 'sub';
diag "test uri login";
{
    ok( !$m->login( 'testuser1', 'password' ), 'not logged in with real user not in group' );
    $m->warning_like(qr/FAILED LOGIN for testuser1/);

    ok( $m->login( 'testuser2', 'password' ), 'logged in as testuser2' );
    $m->logout;

    ok( $m->login( 'testuser3', 'password' ), 'logged in as testuser3 from subgroup' );
    $m->logout;
}

$ldap->unbind();

done_testing;
