use strict;
use warnings;

use RT::Test::LDAP tests => undef;

my $test = RT::Test::LDAP->new();
my $base = $test->{'base_dn'};
my $ldap = $test->new_server();

my $users_dn = "ou=users,$base";
my $group_dn = "cn=test group,ou=groups,$base";

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

$test->config_set_externalauth();

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
