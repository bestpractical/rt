use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};

use DBI;
use File::Temp;
use Digest::MD5;
use File::Spec;

eval { require DBD::SQLite; } or do {
    plan skip_all => 'Unable to test without DBD::SQLite';
};

my $employee_type_cf = RT::CustomField->new( RT->SystemUser );
ok( $employee_type_cf->Create(
        Name       => 'Employee Type',
        LookupType => RT::User->CustomFieldLookupType,
        Type       => 'Select',
        MaxValues  => 1,
    ),
    'created cf Employee Type'
);
ok( $employee_type_cf->AddToObject( RT::User->new( RT->SystemUser ) ), 'applied Employee Type globally' );

my $employee_id_cf = RT::CustomField->new( RT->SystemUser );
ok( $employee_id_cf->Create(
        Name       => 'Employee ID',
        LookupType => RT::User->CustomFieldLookupType,
        Type       => 'Freeform',
        MaxValues  => 1,
    ),
    'created cf Employee ID'
);
ok( $employee_id_cf->AddToObject( RT::User->new( RT->SystemUser ) ), 'applied Employee ID globally' );

my $dir    = File::Temp::tempdir( CLEANUP => 1 );
my $dbname = File::Spec->catfile( $dir, 'rtauthtest' );
my $table  = 'users';
my $dbh = DBI->connect("dbi:SQLite:$dbname");
my $password = Digest::MD5::md5_hex('password');
my $schema = <<"EOF";
CREATE TABLE users (
  username varchar(200) NOT NULL,
  password varchar(40) NULL,
  email varchar(16) NULL,
  employee_type varchar(16) NULL,
  employee_id varchar(16) NULL
);
EOF
$dbh->do( $schema );
$dbh->do(
"INSERT INTO $table VALUES ( 'testuser', '$password', 'testuser\@invalid.tld', 'engineer', '234')"
);

RT->Config->Set( ExternalAuthPriority        => ['My_SQLite'] );
RT->Config->Set( ExternalInfoPriority        => ['My_SQLite'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate                  => undef );
RT->Config->Set(
    ExternalSettings => {
        'My_SQLite' => {
            'type'            => 'db',
            'database'        => $dbname,
            'table'           => $table,
            'dbi_driver'      => 'SQLite',
            'u_field'         => 'username',
            'p_field'         => 'password',
            'p_enc_pkg'       => 'Digest::MD5',
            'p_enc_sub'       => 'md5_hex',
            'attr_match_list' => ['Name'],
            'attr_map'        => {
                'Name'                 => 'username',
                'EmailAddress'         => 'email',
                'FreeformContactInfo'  => [ 'username', 'email' ],
                'CF.Employee Type'     => 'employee_type',
                'UserCF.Employee Type' => 'employee_type',
                'UserCF.Employee ID'   => sub {
                    my %args = @_;
                    return ( $args{external_entry}->{employee_type}, $args{external_entry}->{employee_id} );
                },
            },
            additional_attrs => [ 'employee_id' ],
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
}

diag "test user creation";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'testuser' );
    ok($ok,$msg);
    is($testuser->EmailAddress,'testuser@invalid.tld');

    is( $testuser->FreeformContactInfo, 'testuser testuser@invalid.tld', 'user FreeformContactInfo' );
    is( $testuser->FirstCustomFieldValue('Employee Type'), 'engineer', 'user Employee Type value' );
    is( $testuser->FirstCustomFieldValue('Employee ID'),   'engineer 234',      'user Employee ID value' );
    is( $employee_type_cf->Values->Count,                  1,          'cf Employee Type values count' );
    is( $employee_type_cf->Values->First->Name,            'engineer', 'cf Employee Type value' );
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
