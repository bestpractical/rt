use strict;
use warnings;

use RT::Test nodb => 1, tests => undef;
use Test::Warn;

# Having an LDAP in ExternalSettings implicitly loads Net::LDAP, so
# only run these tests if that loads.
eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
};

RT::Config->Set( ExternalSettings => {
    'My_LDAP'       =>  {
        'type'             =>  'ldap',
        'server'           =>  'ldap.example.com',
        # By not passing 'user' and 'pass' we are using an anonymous
        # bind, which some servers to not allow
        'base'             =>  'ou=Staff,dc=example,dc=com',
        'filter'           =>  '(objectClass=inetOrgPerson)',
        # Users are allowed to log in via email address or account
        # name
        'attr_match_list'  => [
            'Name',
            'EmailAddress',
        ],
        # Import the following properties of the user from LDAP upon
        # login
        'attr_map' => {
            'Name'         => 'sAMAccountName',
            'EmailAddress' => 'mail',
            'RealName'     => 'cn',
            'WorkPhone'    => 'telephoneNumber',
            'Address1'     => 'streetAddress',
            'City'         => 'l',
            'State'        => 'st',
            'Zip'          => 'postalCode',
            'Country'      => 'co',
        },
    },
} );


warnings_are {RT::Config->PostLoadCheck} [], "No warnings loading config";

diag "Test ExternalAuth configuration processing";
my $auth_settings = RT::Config->Get('ExternalSettings');
ok( $auth_settings, 'Got ExternalSettings');
is( $auth_settings->{'My_LDAP'}{'type'}, 'ldap', 'External Auth type is ldap');
ok( RT::Config->Get('ExternalAuth'), 'ExternalAuth activated automatically');

ok( RT::Config->Set('ExternalAuthPriority', ['My_LDAP']),'Set ExternalAuthPriority');
ok( RT::Config->Set('ExternalInfoPriority', ['My_LDAP']),'Set ExternalInfoPriority');

ok( RT::Config->Set( 'ExternalSettings', undef ), 'unset ExternalSettings' );
ok( !(RT::Config->Get('ExternalSettings')), 'ExternalSettings removed');

warnings_like {RT::Config->PostLoadCheck} [qr/ExternalSettings not defined/,
    qr/ExternalSettings not defined/],
  'Correct warnings with ExternalSettings missing';

done_testing;
