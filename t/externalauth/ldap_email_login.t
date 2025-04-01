use strict;
use warnings;

use RT::Test::LDAP tests => undef;

my $test = RT::Test::LDAP->new();
my $base = $test->{'base_dn'};
my $ldap = $test->new_server();

$test->config_set_externalauth();

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
