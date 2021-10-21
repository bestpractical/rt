use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Warn;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $group1 = RT::Group->new(RT->SystemUser);
my ($ok, $msg) = $group1->CreateUserDefinedGroup(Name => 'Group 1');
ok($ok, $msg);

my $user1 = RT::User->new(RT->SystemUser);
($ok, $msg) = $user1->Create(Name => 'User 1');
ok($ok, $msg);

my $user2 = RT::User->new(RT->SystemUser);
($ok, $msg) = $user2->Create(Name => 'User 2');
ok($ok, $msg);

# Group creation
my ($group2_url, $group2_id);
{
    my $payload = {
        Name => 'Group 2',
    };

    # Rights Test - No AdminGroup
    my $res = $mech->post_json("$rest_base_path/group",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403, 'Cannot create group without AdminGroup right');

    # Rights Test - With AdminGroup
    $user->PrincipalObj->GrantRight(Right => 'AdminGroup');
    $res = $mech->post_json("$rest_base_path/group",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201, 'Create group with AdminGroup right');
    ok($group2_url = $res->header('location'), 'Created group url');
    ok(($group2_id) = $group2_url =~ qr[/group/(\d+)], 'Created group id');
}

my $group2 = RT::Group->new(RT->SystemUser);
$group2->Load($group2_id);

# Group disabling
{
    # Rights Test - No AdminGroup
    $user->PrincipalObj->RevokeRight(Right => 'AdminGroup');
    my $res = $mech->delete($group2_url,
        'Authorization' => $auth,
    );
    is($res->code, 403, 'Cannot disable group without AdminGroup right');

    # Rights Test - With AdminGroup, no SeeGroup
    $user->PrincipalObj->GrantRight(Right => 'AdminGroup', Object => $group2);
    $res = $mech->delete($group2_url,
        'Authorization' => $auth,
    );
    is($res->code, 403, 'Cannot disable group without SeeGroup right');

    # Rights Test - With AdminGroup, no SeeGroup
    $user->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $group2);
    $res = $mech->delete($group2_url,
        'Authorization' => $auth,
    );
    is($res->code, 204, 'Disable group with AdminGroup & SeeGroup rights');

    is($group2->Disabled, 1, "Group disabled");
}

# Group enabling
{
    my $payload = {
        Disabled => 0,
    };

    # Rights Test - No AdminGroup
    $user->PrincipalObj->RevokeRight(Right => 'AdminGroup', Object => $group2);
    $user->PrincipalObj->RevokeRight(Right => 'SeeGroup', Object => $group2);

    my $res = $mech->put_json($group2_url,
        $payload,
        'Authorization' => $auth);
    is($res->code, 403, 'Cannot enable group without AdminGroup right');

    # Rights Test - With AdminGroup, no SeeGroup
    $user->PrincipalObj->GrantRight(Right => 'AdminGroup', Object => $group2);
    $res = $mech->put_json($group2_url,
        $payload,
        'Authorization' => $auth);
    is($res->code, 403, 'Cannot enable group without SeeGroup right');

    # Rights Test - With AdminGroup, no SeeGroup
    $user->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $group2);
    $res = $mech->put_json($group2_url,
        $payload,
        'Authorization' => $auth);
    is($res->code, 200, 'Enable group with AdminGroup & SeeGroup rights');
    is_deeply($mech->json_response, ['Group enabled']);

    is($group2->Disabled, 0, "Group enabled");
}

my $group1_id = $group1->id;
(my $group1_url = $group2_url) =~ s/$group2_id/$group1_id/;
$user->PrincipalObj->GrantRight(Right => 'SeeGroup', Object => $group1);

# Members addition
{
    my $payload = [
        $user1->id,
        $group2->id,
        $user1->id + 666,
    ];

    # Rights Test - No AdminGroupMembership
    my $res = $mech->put_json($group1_url . '/members',
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403, 'Cannot add members to group without AdminGroupMembership right');

    # Rights Test - With AdminGroupMembership
    $user->PrincipalObj->GrantRight(Right => 'AdminGroupMembership', Object => $group1);
    $res = $mech->put_json($group1_url . '/members',
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200, 'Add members to group with AdminGroupMembership right');
    is_deeply($mech->json_response, [
        "Member added: " . $user1->Name,
        "Member added: " . $group2->Name,
        "Couldn't find that principal",
    ], 'Two members added, bad principal rejected');
    my $members1 = $group1->MembersObj;
    is($members1->Count, 2, 'Two members added');
    my $member = $members1->Next;
    is($member->MemberObj->PrincipalType, 'User', 'User added as member');
    is($member->MemberObj->id, $user1->id, 'Accurate user added as member');
    $member = $members1->Next;
    is($member->MemberObj->PrincipalType, 'Group', 'Group added as member');
    is($member->MemberObj->id, $group2->id, 'Accurate group added as member');
}

# Members list
{
    # Add user to subgroup
    $group2->AddMember($user2->id);

    # Direct members
    my $res = $mech->get($group1_url . '/members',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List direct members');

    my $content = $mech->json_response;
    is($content->{total}, 2, 'Two direct members');
    is($content->{items}->[0]->{type}, 'user', 'User member');
    is($content->{items}->[0]->{id}, $user1->id, 'Accurate user member');
    is($content->{items}->[1]->{type}, 'group', 'Group member');
    is($content->{items}->[1]->{id}, $group2->id, 'Accurate group member');

    # Deep members
    $res = $mech->get($group1_url . '/members?recursively=1',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List deep members');

    $content = $mech->json_response;
    is($content->{total}, 4, 'Four deep members');

    cmp_deeply(
        $content->{items},
        bag({   type => 'group',
                id   => $group1->id,
                _url => re(qr{$rest_base_path/group/@{[$group1->id]}}),
            },
            {   type => 'group',
                id   => $group2->id,
                _url => re(qr{$rest_base_path/group/@{[$group2->id]}}),
            },
            {   type => 'user',
                id   => $user1->id,
                _url => re(qr{$rest_base_path/user/@{[$user1->id]}}),
            },
            {   type => 'user',
                id   => $user2->id,
                _url => re(qr{$rest_base_path/user/@{[$user2->id]}}),
            }
        ),
        'Four deep member items'
    );

    # Direct user members
    $res = $mech->get($group1_url . '/members?groups=0',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List direct user members');

    $content = $mech->json_response;
    is($content->{total}, 1, 'One direct user member');
    is($content->{items}->[0]->{type}, 'user', 'Direct user member');
    is($content->{items}->[0]->{id}, $user1->id, 'Accurate direct user member');

    # Recursive user members
    $res = $mech->get($group1_url . '/members?groups=0&recursively=1',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List recursive user members');

    $content = $mech->json_response;
    is($content->{total}, 2, 'Two recursive user members');
    is($content->{items}->[0]->{type}, 'user', 'First recursive user member');
    is($content->{items}->[0]->{id}, $user1->id, 'First accurate recursive user member');
    is($content->{items}->[1]->{type}, 'user', 'Second recursive user member');
    is($content->{items}->[1]->{id}, $user2->id, 'Second accurate recursive user member');

    # Direct group members
    $res = $mech->get($group1_url . '/members?users=0',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List direct group members');

    $content = $mech->json_response;
    is($content->{total}, 1, 'One direct group member');
    is($content->{items}->[0]->{type}, 'group', 'Direct group member');
    is($content->{items}->[0]->{id}, $group2->id, 'Accurate direct group member');

    # Recursive group members
    $res = $mech->get($group1_url . '/members?users=0&recursively=1',
        'Authorization' => $auth,
    );
    is($res->code, 200, 'List recursive group members');

    $content = $mech->json_response;
    is($content->{total}, 2, 'Two recursive group members');
    is($content->{items}->[0]->{type}, 'group', 'First recursive group member');
    is($content->{items}->[0]->{id}, $group1->id, 'First accurate recursive group member');
    is($content->{items}->[1]->{type}, 'group', 'Second recursive group member');
    is($content->{items}->[1]->{id}, $group2->id, 'Second accurate recursive group member');
}

# Members removal
{
    my $res = $mech->delete($group1_url . '/member/' . $user1->id,
        'Authorization' => $auth,
    );
    is($res->code, 204, 'Remove member');
    my $members1 = $group1->MembersObj;
    is($members1->Count, 1, 'One member removed');
    my $member = $members1->Next;
    is($member->MemberObj->PrincipalType, 'Group', 'Group remaining member');
    is($member->MemberObj->id, $group2->id, 'Accurate remaining member');
}

# All members removal
{
    my $res = $mech->delete($group1_url . '/members',
        'Authorization' => $auth,
    );
    is($res->code, 204, 'Remove all members');
    my $members1 = $group1->MembersObj;
    is($members1->Count, 0, 'All members removed');
}

# Group hypermedia links
{
    my $res = $mech->get("$rest_base_path/group/$group1_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    my $links = $content->{_hyperlinks};
    my @members_links = grep { $_->{ref} =~ /members/ } @$links;
    is(scalar(@members_links), 1);
    like($members_links[0]->{_url}, qr{$rest_base_path/group/$group1_id/members$});
}

done_testing;
