use strict;
use warnings;

use RT::Test tests => undef;

use DBI;
use File::Temp;
use Digest::MD5;
use File::Spec;

eval { require RT::Authen::ExternalAuth; require DBD::SQLite; } or do {
    plan skip_all => 'Unable to test without DBD::SQLite';
};

my $dir    = File::Temp::tempdir( CLEANUP => 1 );
my $dbname = File::Spec->catfile( $dir, 'rtauthtest' );
my $table  = 'users';
my $dbh = DBI->connect("dbi:SQLite:$dbname");
my $password = Digest::MD5::md5_hex('password');
my $schema = <<"EOF";
CREATE TABLE users (
  username varchar(200) NOT NULL COLLATE NOCASE,
  password varchar(40) NULL,
  email varchar(16) NULL COLLATE NOCASE,
  disabled int
);
EOF
$dbh->do( $schema );
$dbh->do( <<"EOF"
INSERT INTO $table VALUES
    ( 'testuser', '$password', 'testuser\@invalid.tld', 0),
    ( 'testCASE', '$password', 'testcase\@invalid.tld', 0),
    ( 'testmail', '$password', 'testMAIL\@invalid.tld', 0)
EOF
);

RT->Config->Set( ExternalAuthPriority        => ['My_SQLite'] );
RT->Config->Set( ExternalInfoPriority        => ['My_SQLite'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate                  => undef );
RT->Config->Set(
    ExternalSettings => {
        'My_SQLite' => {
            'type'   => 'db',
            'database'        => $dbname,
            'table'           => $table,
            'dbi_driver'      => 'SQLite',
            'u_field'         => 'username',
            'p_field'         => 'password',
            'p_enc_pkg'       => 'Digest::MD5',
            'p_enc_sub'       => 'md5_hex',
            'd_field'         => 'disabled',
            'attr_match_list' => ['Name', 'EmailAddress'],
            'attr_map'        => {
                'Name'           => 'username',
                'EmailAddress'   => 'email',
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
    ok( !$m->login( 'testuser', 'wrongpassword' ), 'not logged in with wrong password' );
    $m->warning_like( qr/FAILED LOGIN for testuser/ );
    ok( $m->login( 'testuser', 'password' ), 'logged in' );

    ok( $m->logout, 'logged out' );
    ok( $m->login( 'testcase', 'password' ), 'logged in with case mismatch' );
}

diag "test user creation";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'testuser' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'testuser@invalid.tld');
}

diag "test user creation with case mismatch";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok, $msg) = $testuser->Load( 'testCASE' );
    ok( $ok, "create user: $msg" );
    is( $testuser->EmailAddress, 'testcase@invalid.tld' );
}

diag "test user creation from email with case mismatch";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok, $msg) = $testuser->LoadOrCreateByEmail( 'testmail@invalid.tld' );
    ok( $ok, "create user: $msg" );
    is( $testuser->Name, 'testmail' );
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

is( $m->uri, $baseurl . '/SelfService/', 'selfservice page' );

diag "test redirect after login";
{
    $m->logout;
    $m->get_ok( $baseurl . '/SelfService/Closed.html', 'closed tickets page' );
    $m->submit_form(
        form_number => 1,
        fields      => { user => 'testuser', pass => 'password', },
    );
    $m->text_contains( 'Logout', 'logged in' );
    is( $m->uri, $baseurl . '/SelfService/Closed.html' );
}

diag "test with user and pass in URL";
{
    $m->logout;
    $m->get_ok( $baseurl . '/SelfService/Closed.html?user=testuser;pass=password', 'closed tickets page' );
    $m->text_contains( 'Logout', 'logged in' );
    is( $m->uri, $baseurl . '/SelfService/Closed.html?user=testuser;pass=password' );
}

done_testing;
