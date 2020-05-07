use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Warn;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

my $group1 = RT::Group->new(RT->SystemUser);
my ($ok, $msg) = $group1->CreateUserDefinedGroup(Name => 'Group 1');
ok($ok, $msg);

my $group2 = RT::Group->new(RT->SystemUser);
($ok, $msg) = $group2->CreateUserDefinedGroup(Name => 'Group 2');
ok($ok, $msg);

($ok, $msg) = $group1->AddMember($group2->id);
ok($ok, $msg);

# Membership addition
{
    my $payload = [ $group2->id ];

    # Rights Test - No ModifyOwnMembership
    my $res = $mech->put_json("$rest_base_path/user/" . $user->id . '/groups',
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403, 'Cannot add user to group without ModifyOwnMembership right');

    # Rights Test - With ModifyOwnMembership
    $user->PrincipalObj->GrantRight(Right => 'ModifyOwnMembership');
    $res = $mech->put_json("$rest_base_path/user/" . $user->id . '/groups',
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200, 'Add user to group with ModifyOwnMembership right');
    my $members2 = $group2->MembersObj;
    is($members2->Count, 1, 'One member added');
    my $member = $members2->Next;
    is($member->MemberObj->PrincipalType, 'User', 'User added as member');
    is($member->MemberObj->id, $user->id, 'Accurate user added as member');
}


# Memberships list
{
    # Rights Test - No SeeGroup
    my $res = $mech->get("$rest_base_path/user/" . $user->id . '/groups',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List direct members');

    my $content = $mech->json_response;
    is($content->{total}, 2, 'Two recursive memberships');
    is(scalar(@{$content->{items}}), 0, 'Cannot see memberships content withtout SeeGroup right');
    
    # Recursive memberships
    $user->PrincipalObj->GrantRight(Right => 'SeeGroup');
    $res = $mech->get("$rest_base_path/user/" . $user->id . '/groups',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List direct members');

    $content = $mech->json_response;
    is($content->{total}, 2, 'Two recursive memberships');
    is($content->{items}->[0]->{type}, 'group', 'First group membership');
    is($content->{items}->[0]->{id}, $group1->id, 'Accurate first group membership');
    is($content->{items}->[1]->{type}, 'group', 'Second group membership');
    is($content->{items}->[1]->{id}, $group2->id, 'Accurate second group membership');
}

($ok, $msg) = $group1->AddMember($user->id);
ok($ok, $msg);

# Membership removal
{
    my $res = $mech->delete("$rest_base_path/user/" . $user->id . '/group/' . $group2->id,
        'Authorization' => $auth,
    );
    is($res->code, 204, 'Remove membership');
    my $memberships = $user->OwnGroups;
    is($memberships->Count, 1, 'One membership removed');
    my $membership = $memberships->Next;
    is($membership->id, $group1->id, 'Accurate membership removed');
}

($ok, $msg) = $group2->AddMember($user->id);
ok($ok, $msg);

# All members removal
{
    my $res = $mech->delete("$rest_base_path/user/" . $user->id . '/groups',
        'Authorization' => $auth,
    );
    is($res->code, 204, 'Remove all memberships');
    my $memberships = $user->OwnGroups;
    is($memberships->Count, 0, 'All membership removed');
}

# User hypermedia links
{
    my $res = $mech->get("$rest_base_path/user/" . $user->id,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    my $links = $content->{_hyperlinks};
    my @memberships_links = grep { $_->{ref} eq 'memberships' } @$links;
    is(scalar(@memberships_links), 1);
    my $user_id = $user->id;
    like($memberships_links[0]->{_url}, qr{$rest_base_path/user/$user_id/groups$});
}

done_testing;
