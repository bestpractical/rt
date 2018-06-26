use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::LDAPImport; require Net::LDAP::Server::Test; 1; } or do {
    plan skip_all => 'Unable to test without RT::LDAPImport and Net::LDAP::Server::Test';
};

{
    my $cf = RT::CustomField->new(RT->SystemUser);
    my ($ok, $msg) = $cf->Create(
        Name        => 'Employee Number',
        LookupType  => 'RT::User',
        Type        => 'FreeformSingle',
        Disabled    => 0,
    );
    ok $cf->Id, $msg;

    my $ocf = RT::ObjectCustomField->new(RT->SystemUser);
    ($ok, $msg) = $ocf->Create( CustomField => $cf->Id );
    ok $ocf->Id, $msg;
}

my $importer = RT::LDAPImport->new;
isa_ok($importer,'RT::LDAPImport');

my $ldap_port = RT::Test->find_idle_port;
ok( my $server = Net::LDAP::Server::Test->new( $ldap_port, auto_schema => 1 ),
    "spawned test LDAP server on port $ldap_port");

my $ldap = Net::LDAP->new("localhost:$ldap_port");
$ldap->bind();
$ldap->add("ou=foo,dc=bestpractical,dc=com");

my @ldap_entries;
for ( 0 .. 12 ) {
    my $username = "testuser$_";
    my $dn = "uid=$username,ou=foo,dc=bestpractical,dc=com";
    my $entry = {
                    cn   => "Test User $_ ".int rand(200),
                    mail => "$username\@invalid.tld",
                    uid  => $username,
                    employeeId => $_,
                    objectClass => 'User',
                };
    push @ldap_entries, { dn => $dn, %$entry };
    $ldap->add( $dn, attr => [%$entry] );
}

RT->Config->Set('LDAPHost',"ldap://localhost:$ldap_port");
RT->Config->Set('LDAPMapping',
                   {Name         => 'uid',
                    EmailAddress => 'mail',
                    RealName     => 'cn',
                    'UserCF.Employee Number' => 'employeeId',});
RT->Config->Set('LDAPBase','ou=foo,dc=bestpractical,dc=com');
RT->Config->Set('LDAPFilter','(objectClass=User)');

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
    is($user->FirstCustomFieldValue('Employee Number'), $entry->{employeeId}, "cf is good: $entry->{employeeId}");
}

# import again, check that it was cleared
{
    my $delete = $ldap_entries[0];
    $ldap->modify( $delete->{dn}, delete => ['employeeId'] );
    delete $delete->{employeeId};

    my $update = $ldap_entries[1];
    $ldap->modify( $update->{dn}, replace => ['employeeId' => 42] );
    $update->{employeeId} = 42;

    ok($importer->import_users( import => 1 ));

    for my $entry (@ldap_entries[0,1]) {
        my $user = RT::User->new($RT::SystemUser);
        $user->LoadByCols( EmailAddress => $entry->{mail},
                           Realname => $entry->{cn},
                           Name => $entry->{uid} );
        ok($user->Id, "Found $entry->{cn} as ".$user->Id);
        is($user->FirstCustomFieldValue('Employee Number'), $entry->{employeeId}, "cf is updated");
    }
}

# can't unbind earlier or the server will die
$ldap->unbind;

done_testing;
