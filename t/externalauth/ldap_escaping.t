use strict;
use warnings;

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
$ldap->add(
    "cn=Smith\\, John,$users_dn",
    attr => [
        cn           => 'Smith\\, John',
        mail         => 'jsmith@example.com',
        uid          => 'jsmith',
        objectClass  => 'User',
        userPassword => 'password',
    ]
);
$ldap->add(
    "cn=John Doe,$users_dn",
    attr => [
        cn           => 'John Doe',
        mail         => 'jdoe@example.com',
        uid          => 'j(doe',
        objectClass  => 'User',
        userPassword => 'password',
    ]
);
$ldap->add(
    $group_dn,
    attr => [
        cn          => "test group",
        memberDN    => [ "cn=Smith\\, John,$users_dn", "cn=John Doe,$users_dn" ],
        objectClass => 'Group',
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

diag "comma in the DN";
{
    ok( $m->login( 'jsmith', 'password' ), 'logged in' );

    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'jsmith' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'jsmith@example.com');
}

diag "paren in the username";
{
    ok( $m->logout, 'logged out' );
    # $m->login chokes on ( in 4.0.5
    $m->get_ok($m->rt_base_url . "?user=j(doe;pass=password");
    $m->content_like(qr/Logout/i, 'contains logout link');
    $m->content_contains('<span class="current-user">j&#40;doe</span>', 'contains logged in user name');

    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'j(doe' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'jdoe@example.com');
}

$ldap->unbind();

done_testing;
