use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::LDAPImport; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without RT::LDAPImport and Net::LDAP::Server::Test';
};

my $importer = RT::LDAPImport->new;
isa_ok($importer,'RT::LDAPImport');

my $ldap_port = RT::Test->find_idle_port;
ok( my $server = Net::LDAP::Server::Test->new( $ldap_port, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port");

my $ldap = Net::LDAP->new("localhost:$ldap_port");
$ldap->bind();
$ldap->add("ou=foo,dc=bestpractical,dc=com");

my @ldap_entries;
for ( 1 .. 13 ) {
    my $username = "testuser$_";
    my $dn = "uid=$username,ou=foo,dc=bestpractical,dc=com";
    my $entry = {
                    cn   => "Test User $_ ".int rand(200),
                    mail => "$username\@invalid.tld",
                    uid  => $username,
                    objectClass => 'User',
                };
    push @ldap_entries, $entry;
    $ldap->add( $dn, attr => [%$entry] );
}
$ldap->add(
    "uid=9000,ou=foo,dc=bestpractical,dc=com",
    attr => [
        cn   => "Numeric user",
        mail => "numeric\@invalid.tld",
        uid  => 9000,
        objectclass => 'User',
    ],
);

$ldap->add(
    "uid=testdisabled,ou=foo,dc=bestpractical,dc=com",
    attr => [
        cn          => "Disabled user",
        mail        => "testdisabled\@invalid.tld",
        uid         => 'testdisabled',
        objectclass => 'User',
        disabled    => 1,
    ],
);

RT->Config->Set('LDAPHost',"ldap://localhost:$ldap_port");
RT->Config->Set('LDAPOptions', [ port => $ldap_port ]);
RT->Config->Set(
    'LDAPMapping',
    {
        Name         => 'uid',
        EmailAddress => 'mail',
        RealName     => 'cn',
        Disabled     => sub {
            my %args   = @_;
            return $args{ldap_entry}->get_value('disabled') ? 1 : 0;
        },
    }
);
RT->Config->Set('LDAPBase','ou=foo,dc=bestpractical,dc=com');
RT->Config->Set('LDAPFilter','(objectClass=User)');
RT->Config->Set('LDAPUpdateUsers', 1);

# check that we don't import
ok($importer->import_users());
{
    my $users = RT::Users->new($RT::SystemUser);
    for my $username (qw/RT_System root Nobody/) {
        $users->Limit( FIELD => 'Name', OPERATOR => '!=', VALUE => $username, ENTRYAGGREGATOR => 'AND' );
    }
    is($users->Count,0);
}

# check that we do import
ok($importer->import_users( import => 1 ));
for my $entry (@ldap_entries) {
    my $user = RT::User->new($RT::SystemUser);
    $user->LoadByCols( EmailAddress => $entry->{mail},
                       Realname => $entry->{cn},
                       Name => $entry->{uid} );
    ok($user->Id, "Found $entry->{cn} as ".$user->Id);
    ok(!$user->Privileged, "User created as Unprivileged");
}

# Check that we skipped numeric usernames
my $user = RT::User->new($RT::SystemUser);
$user->LoadByCols( EmailAddress => "numeric\@invalid.tld" );
ok(!$user->Id);
$user->LoadByCols( Name => 9000 );
ok(!$user->Id);
$user->Load( 9000 );
ok(!$user->Id);

$user->Load('testdisabled');
ok( $user->Disabled, 'User testdisabled is disabled' );
$ldap->modify( "uid=testdisabled,ou=foo,dc=bestpractical,dc=com", replace => { disabled => 0 } );
ok( $importer->import_users( import => 1 ) );
$user->Load('testdisabled');
ok( !$user->Disabled, 'User testdisabled is enabled' );

# can't unbind earlier or the server will die
$ldap->unbind;

done_testing;
