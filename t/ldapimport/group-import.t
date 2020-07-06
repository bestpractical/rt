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
                    cn   => "Test User $_ ".int rand(200),
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
        cn   =>  $groupname,
        members => [ map { $_->{dn} } @ldap_user_entries[($_-1),($_+3),($_+7)] ],
        memberUid => [ map { $_->{uid} } @ldap_user_entries[($_+1),($_+3),($_+5)] ],
        objectClass => 'Group',
    };
    $ldap->add( $dn, attr => [%$entry] );
    push @ldap_group_entries, $entry;
}
$ldap->add(
    "cn=42,ou=groups,$base",
    attr => [
        cn => "42",
        members => [ "uid=testuser1,ou=foo,$base" ],
        objectClass => 'Group',
    ],
);

my $entry = {
    cn          => "testdisabled",
    members     => ["uid=testuser1,ou=foo,$base"],
    objectClass => 'Group',
    disabled    => 1,
};
$ldap->add( "cn=testdisabled,ou=groups,$base", attr => [ %$entry ] );
push @ldap_group_entries, $entry;

$test->config_set_ldapimport();

ok($importer->import_users( import => 1 ));
for my $entry (@ldap_user_entries) {
    my $user = RT::User->new($RT::SystemUser);
    $user->LoadByCols( EmailAddress => $entry->{mail},
                       Realname => $entry->{cn},
                       Name => $entry->{uid} );
    ok($user->Id, "Found $entry->{cn} as ".$user->Id);
}

$test->config_set_ldapimport_group({
    'LDAPGroupMapping' => {
        Name        => 'cn',
        Member_Attr => 'members',
        Disabled    => sub {
            my %args = @_;
            return $args{ldap_entry}->get_value('disabled') ? 1 : 0;
        },
    }
});

# confirm that we skip the import
ok( $importer->import_groups() );
{
    my $groups = RT::Groups->new($RT::SystemUser);
    $groups->LimitToUserDefinedGroups;
    is($groups->Count,0);
}

import_group_members_ok( members => 'dn' );

my $group = RT::Group->new($RT::SystemUser);
$group->LoadUserDefinedGroup('testdisabled');
ok( $group->Disabled, 'Group testdisabled is disabled' );

$ldap->modify( "cn=testdisabled,ou=groups,$base", replace => { disabled => 0 } );
ok( $importer->import_groups( import => 1 ), "imported groups" );
$group->LoadUserDefinedGroup('testdisabled');
ok( !$group->Disabled, 'Group testdisabled is enabled' );

RT->Config->Set('LDAPGroupMapping',
                   {Name                => 'cn',
                    Member_Attr         => 'memberUid',
                    Member_Attr_Value   => 'uid',
                   });
import_group_members_ok( memberUid => 'uid' );

{
    my $uid  = $ldap_user_entries[2]->{uid}; # the first user used for memberUid
    my $user = RT::User->new($RT::SystemUser);
    my ($ok, $msg) = $user->Load($uid);
    ok $ok, "Loaded user #$uid" or diag $msg;

    ($ok, $msg) = $user->SetDisabled(1);
    ok $ok, "Disabled user #$uid" or diag $msg;
}
import_group_members_ok( memberUid => 'uid' );

sub import_group_members_ok {
    my $attr = shift;
    my $user_attr = shift;

    ok( $importer->import_groups( import => 1 ), "imported groups" );

    for my $entry (@ldap_group_entries) {
        my $group = RT::Group->new($RT::SystemUser);
        $group->LoadUserDefinedGroup( $entry->{cn} );
        ok($group->Id, "Found $entry->{cn} as ".$group->Id);

        my $idlist;
        my $members = $group->MembersObj;
        while (my $group_member = $members->Next) {
            my $member = $group_member->MemberObj;
            next unless $member->IsUser();
            $idlist->{$member->Object->Id}++;
        }

        foreach my $member ( @{$entry->{$attr}} ) {
            my ($user) = grep { $_->{$user_attr} eq $member } @ldap_user_entries;
            my $rt_user = RT::User->new($RT::SystemUser);
            my ($res,$msg) = $rt_user->Load($user->{uid});
            unless ($res) {
                diag("Couldn't load user $user->{uid}: $msg");
                next;
            }
            ok($group->HasMember($rt_user->PrincipalObj->Id),"Correctly assigned $user->{uid} to $entry->{cn}");
            delete $idlist->{$rt_user->Id};
        }
        is(keys %$idlist,0,"No dangling users");
    }

    my $group = RT::Group->new($RT::SystemUser);
    $group->LoadUserDefinedGroup( "42" );
    ok( !$group->Id );

    $group->LoadByCols(
        Domain => 'UserDefined',
        Name   => "42",
    );
    ok( !$group->Id );
}

done_testing;
