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

my $delegate_cf = RT::CustomField->new( RT->SystemUser );
ok( $delegate_cf->Create(
        Name       => 'Delegate',
        LookupType => RT::User->CustomFieldLookupType,
        Type       => 'Freeform',
        MaxValues  => 1,
    ),
    'created cf Delegate'
);
ok( $delegate_cf->AddToObject( RT::User->new( RT->SystemUser ) ), 'applied Delegate globally' );

# Just wholesale replace the default attr_map.
$test->{'externalauth'}{'My_LDAP'}{'attr_map'} = {
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
            $args{external_entry}->get_value('employeeID')   // '',
        );
    },
};

$test->config_set_externalauth();

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
    $m->text_contains( 'Employee Type: Set from external source' );
    $m->text_contains( 'Employee ID: Set from external source' );

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

    my $delegate_input = RT::Interface::Web::GetCustomFieldInputName(
        Object => RT::User->new( RT->SystemUser ),
        CustomField => $delegate_cf,
    );
    $m->submit_form(
        form_name => 'UserCreate',
        fields    => {
            Name            => '',
            EmailAddress    => "$username\@invalid.tld",
            $delegate_input => 'root',
        },
    );
    $m->text_contains( 'User created' );
    my ( $id ) = ( $m->uri =~ /id=(\d+)/ );
    my $user = RT::User->new( RT->SystemUser );
    $user->Load( $id );
    is( $user->EmailAddress, "$username\@invalid.tld", 'email is not changed' );
    is( $user->Name, $username, 'got canonicalized Name' );
    is( $user->FirstCustomFieldValue('Employee Type'), 'sale', 'Employee Type set to sale from LDAP' );
    is( $user->FirstCustomFieldValue('Delegate'), 'root', 'Delegate set to root from Web' );
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

diag 'Login with UserCF as username';

$test->stop_server();

$test->{'externalauth'}{'My_LDAP'}{'attr_match_list'}
    = [ 'UserCF.Employee ID', 'EmailAddress' ];
$test->{'externalauth'}{'My_LDAP'}{'attr_map'} = {
    'Name'                 => 'uid',
    'EmailAddress'         => 'mail',
    'FreeformContactInfo'  => [ 'uid', 'mail' ],
    'CF.Employee Type'     => 'employeeType',
    'UserCF.Employee Type' => 'employeeType',
    'UserCF.Employee ID'   => 'employeeID',
};

$test->config_set_externalauth();

( $baseurl, $m ) = RT::Test->started_ok();

diag "test uri login";
{
    my $testuser = RT::User->new($RT::SystemUser);
    my ($ok,$msg) = $testuser->Load( 'testuser' );
    ok($ok,$msg);

    # Reset employee ID to just id
    $testuser->AddCustomFieldValue( Field => 'Employee ID', Value => '234' );
    is( $testuser->FirstCustomFieldValue('Employee ID'), 234, 'Employee ID set to 234');

    # Can't use usual login method because it checks for username and for this test,
    # the username is not the user CF value we are sending

    $m->get($baseurl . "?user=234;pass=password");
    ok( $m->content =~ m/Logout/i, 'Logged in' );
    ok( $m->logged_in_as('testuser'), 'Logged in as testuser' );
}

$ldap->unbind();

done_testing;
