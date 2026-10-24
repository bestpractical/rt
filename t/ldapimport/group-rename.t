use strict;
use warnings;

use RT::Test::LDAP tests => undef;

my $test = RT::Test::LDAP->new();
my $base = $test->{'base_dn'};
my $ldap = $test->new_server();

my $importer = RT::LDAPImport->new;
isa_ok($importer,'RT::LDAPImport');

my @ldap_user_entries;
for ( 1 .. 12 ) {
    my $username = "testuser$_";
    my $dn = "uid=$username,ou=foo,$base";
    my $entry = {
                    dn   => $dn,
                    cn   => "Test User $_",
                    mail => "$username\@invalid.tld",
                    uid  => $username,
                    objectClass => 'User',
                };
    push @ldap_user_entries, $entry;
    $ldap->add( $dn, attr => [%$entry] );
}

my @ldap_group_entries;
for ( 1 .. 4 ) {
    my $groupname = "Test Group $_";
    my $dn = "cn=$groupname,ou=groups,$base";
    my $entry = {
        cn          => $groupname,
        gid         => $_,
        members     => [ map { $_->{dn} } @ldap_user_entries[($_-1),($_+3),($_+7)] ],
        objectClass => 'Group',
    };
    $ldap->add( $dn, attr => [%$entry] );
    push @ldap_group_entries, $entry;
}

$test->config_set_ldapimport();
$test->config_set_ldapimport_group({
    'LDAPGroupMapping' => {
        Name         => 'cn',
        Member_Attr  => 'members',
    },
});

ok( $importer->import_users( import => 1 ), 'imported users');
# no id mapping
{
    ok( $importer->import_groups( import => 1 ), "imported groups" );

    is_member_of('testuser1', 'Test Group 1');
    ok !get_group('Test Group 1')->FirstAttribute('LDAPImport-gid-1');
}

# map id
{
    RT->Config->Get('LDAPGroupMapping')->{'id'} = 'gid';
    ok( $importer->import_groups( import => 1 ), "imported groups" );

    is_member_of('testuser1', 'Test Group 1');
    ok get_group('Test Group 1')->FirstAttribute('LDAPImport-gid-1');
}

# rename a group
{
    $ldap->modify(
        "cn=Test Group 1,ou=groups,$base",
        replace => { 'cn' => 'Test Group 1 Renamed' },
    );
    ok( $importer->import_groups( import => 1 ), "imported groups" );
    ok !get_group('Test Group 1')->id;
    is_member_of('testuser1', 'Test Group 1 Renamed');
    ok get_group('Test Group 1 Renamed')->FirstAttribute('LDAPImport-gid-1');
}

# swap two groups
{
    is_member_of('testuser2', 'Test Group 2');
    is_member_of('testuser3', 'Test Group 3');
    $ldap->modify(
        "cn=Test Group 2,ou=groups,$base",
        replace => { 'cn' => 'Test Group 3' },
    );
    $ldap->modify(
        "cn=Test Group 3,ou=groups,$base",
        replace => { 'cn' => 'Test Group 2' },
    );
    ok( $importer->import_groups( import => 1 ), "imported groups" );
    is_member_of('testuser2', 'Test Group 3');
    is_member_of('testuser3', 'Test Group 2');
    ok get_group('Test Group 2')->FirstAttribute('LDAPImport-gid-3');
    ok get_group('Test Group 3')->FirstAttribute('LDAPImport-gid-2');
}

done_testing;

sub is_member_of {
    my $uname = shift;
    my $gname = shift;

    my $group = get_group($gname);
    return ok(0, "found group $gname") unless $group->id;

    my $user = RT::User->new($RT::SystemUser);
    $user->Load( $uname );
    return ok(0, "found user $uname") unless $user->id;

    return ok($group->HasMember($user->id), "$uname is member of $gname");
}

sub get_group {
    my $gname = shift;
    my $group = RT::Group->new($RT::SystemUser);
    $group->LoadUserDefinedGroup( $gname );
    return $group;
}
