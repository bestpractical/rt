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
my $username = "testuser";
my $base     = "dc=bestpractical,dc=com";
my $dn       = "uid=$username,$base";
my $entry    = {
    cn           => $username,
    mail         => "$username\@invalid.tld",
    uid          => $username,
    objectClass  => 'User',
    userPassword => 'password',
    employeeType => 'engineer',
    employeeID   => '234',
};
$ldap->add( $base );
$ldap->add( $dn, attr => [%$entry] );

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

RT->Config->Set( ExternalAuthPriority        => ['My_LDAP'] );
RT->Config->Set( ExternalInfoPriority        => ['My_LDAP'] );
RT->Config->Set( AutoCreateNonExternalUsers  => 0 );
RT->Config->Set( AutoCreate  => undef );
RT->Config->Set(
    ExternalSettings => {    # AN EXAMPLE DB SERVICE
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
                'Name'                 => 'uid',
                'EmailAddress'         => 'mail',
                'FreeformContactInfo'  => [ 'uid', 'mail' ],
                'CF.Employee Type'     => 'employeeType',
                'UserCF.Employee Type' => 'employeeType',
                'UserCF.Employee ID'   => sub {
                    my %args = @_;
                    return ( 'employeeType', 'employeeID' ) unless $args{external_entry};
                    return (
                        $args{external_entry}->get_value('employeeType') // '',
                        $args{external_entry}->get_value('employeeID') // '',
                    );
                },
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

is( $m->uri, $baseurl . '/SelfService/' , 'selfservice page' );

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

diag "test admin user create";
{
    $m->logout;
    ok( $m->login );
    $m->get_ok( $baseurl . '/Admin/Users/Modify.html?Create=1', 'user create page' );

    my $username = 'testuser2';
    $m->submit_form(
        form_name => 'UserCreate',
        fields    => { Name => $username },
    );
    $m->text_contains( 'User could not be created: Could not set user info' );
    $m->text_lacks( 'User could not be created: Name in use' );

    my $entry = {
        cn           => $username,
        mail         => "$username\@invalid.tld",
        uid          => $username,
        objectClass  => 'User',
        userPassword => 'password',
        employeeType => 'sale',
        employeeID   => '345',
    };
    $ldap->add( $base );
    my $dn = "uid=$username,$base";
    $ldap->add( $dn, attr => [ %$entry ] );

    $m->submit_form(
        form_name => 'UserCreate',
        fields    => { Name => '', EmailAddress => "$username\@invalid.tld" },
    );
    $m->text_contains( 'User created' );
    my ( $id ) = ( $m->uri =~ /id=(\d+)/ );
    my $user = RT::User->new( RT->SystemUser );
    $user->Load( $id );
    is( $user->EmailAddress, "$username\@invalid.tld", 'email is not changed' );
    is( $user->Name, $username, 'got canonicalized Name' );
    is( $user->FirstCustomFieldValue('Employee Type'), 'sale', 'Employee Type set to sale from LDAP' );
}

diag "test user update via login";
{
    $m->logout;
    ok( $m->login( 'testuser2', 'password' ), 'logged in' );

    my $user = RT::User->new( RT->SystemUser );
    ok( $user->Load('testuser2'), 'load user testuser2' );
    is( $user->FreeformContactInfo, 'testuser2 testuser2@invalid.tld', 'user FreeformContactInfo' );
    is( $user->FirstCustomFieldValue('Employee Type'), 'sale',    'user Employee Type value' );
    is( $user->FirstCustomFieldValue('Employee ID'),   'sale 345', 'user Employee ID value' );
    is( $employee_type_cf->Values->Count,              2,         'cf Employee Type values count' );
    is_deeply(
        [ map { $_->Name } @{ $employee_type_cf->Values->ItemsArrayRef } ],
        [ 'engineer', 'sale' ],
        'cf Employee Type values'
    );
}

$ldap->unbind();

done_testing;
