use strict;
use warnings;
use RT;
my $config;
BEGIN{
    $config = <<'END';
Set($ExternalSettings, {
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

END

}

BEGIN {
  # $config above implicitly loads Net::LDAP because of type ldap
  eval { require RT::Authen::ExternalAuth; require Net::LDAP::Server::Test; 1; } or do {
    use RT::Test tests => undef;
    plan skip_all => 'Unable to test without Net::LDAP and Net::LDAP::Server::Test';
  };
}

use RT::Test nodb => 1, tests => undef, config => $config;
use Test::Warn;

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
