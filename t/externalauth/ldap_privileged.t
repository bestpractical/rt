use strict;
use warnings;

use RT::Test::LDAP tests => undef;

my $test = RT::Test::LDAP->new();
my $base = $test->{'base_dn'};
my $ldap = $test->new_server();

my $username = "testuser";
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

$test->config_set_externalauth({ AutoCreate => { Privileged => 1 } });

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

