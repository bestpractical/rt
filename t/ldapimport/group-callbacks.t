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
        members     => [ map { 'mail="'. $_->{'mail'} .'"' } @ldap_user_entries[($_-1),($_+3),($_+7)] ],
        objectClass => 'Group',
    };
    $ldap->add( $dn, attr => [%$entry] );
    push @ldap_group_entries, $entry;
}

$test->config_set_ldapimport();
$test->config_set_ldapimport_group({
    'LDAPGroupMapping' => {
        Name         => 'cn',
        Member_Attr  => sub {
            my %args = @_;
            my $self = $args{'self'};
            my $members = $args{ldap_entry}->get_value('members', asref => 1);
            foreach my $record ( @$members ) {
                my $user = RT::User->new( RT->SystemUser );
                $user->LoadByEmail($record =~ /mail="(.*)"/);
                $self->_users->{ lc $record } = $user->Name;
            }
            return @$members;
        },
    },
});

ok( $importer->import_users( import => 1 ), 'imported users');
# no id mapping
{
    ok( $importer->import_groups( import => 1 ), "imported groups" );

    is_member_of('testuser1', 'Test Group 1');
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

