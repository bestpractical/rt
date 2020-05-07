use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;
#use Test::Warn;

use Data::Dumper;
my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;

my $rest_base_path = '/REST/2.0';
my $test_user = RT::Test::REST2->user;
$test_user->PrincipalObj->RevokeRight(Right => 'ShowUserHistory');

my $user_foo = RT::Test->load_or_create_user(
    Name     => 'foo',
    RealName => 'Foo Jr III',
    EmailAddress => 'test@test.test',
    Password => 'password',
);
my $user_bar = RT::Test->load_or_create_user( Name => 'bar', RealName => 'Bar Jr III', );
my $user_baz = RT::Test->load_or_create_user( Name => 'baz' );
my $user_quuz = RT::Test->load_or_create_user( Name => 'quuz' );

$user_baz->SetDisabled(1);

my $group1 = RT::Group->new(RT->SystemUser);
$group1->CreateUserDefinedGroup(Name => 'Group 1');

my $group2 = RT::Group->new(RT->SystemUser);
$group2->CreateUserDefinedGroup(Name => 'Group 2');

my ($ok, $msg) = $group1->AddMember($user_bar->id);
($ok, $msg) = $group1->AddMember($user_foo->id);
($ok, $msg) = $group2->AddMember($user_foo->id);
($ok, $msg) = $group2->AddMember($user_quuz->id);

# user search
{
    my $user_id = $test_user->id;
    my $res = $mech->get("$rest_base_path/users", 'Authorization' => $auth );
    is($res->code, 200);
    my $content = $mech->json_response;

    my $items = delete $content->{items};
    is_deeply( $content,
               {
                   'count' => 7,
                   'total' => 7,
                   'per_page' => 20,
                   'pages' => 1,
                   'page' => 1
               });
    is(scalar(@$items), 7);
    foreach my $username (qw(foo bar quuz root test)) {
        my ($item) = grep { $_->{id} eq $username } @$items;
        like($item->{_url}, qr{$rest_base_path/user/$username$});
        is($item->{type}, 'user');
    }
    ok(not grep { $_->{id} eq 'baz' } @$items);
}


# basic user request, own user details
{
    my $user_id = $test_user->id;
    my $res = $mech->get("$rest_base_path/user/$user_id", 'Authorization' => $auth );
    is($res->code, 200);
    my $content = $mech->json_response;
    cmp_deeply(
        $content,
        superhashof({
            'Privileged' => 1,
            'Name' => 'test',
            'Disabled' => '0',
        }),'basic summary for own user ok'
    );

    my $links = $content->{_hyperlinks};
    my ($history_link) = grep { $_->{ref} eq 'history' } @$links;
    like($history_link->{_url}, qr{$rest_base_path/user/$user_id/history$});
}

# basic user request, no rights
{
    my $user_id = $user_foo->id;
    my $res = $mech->get("$rest_base_path/user/$user_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    my $links = delete $content->{_hyperlinks};
    is(scalar(@$links),1, 'only 1 link, should be self');
    my ($self_link) = grep { $_->{ref} eq 'self' } @$links;
    like($self_link->{_url}, qr{$rest_base_path/user/$user_id$});
    is_deeply($content, {
        Name     => 'foo',
        RealName => 'Foo Jr III',
        EmailAddress => 'test@test.test',
        'Privileged' => 1
    }, 'basic summary for user ok, no extra fields or hyperlinks');
}

# showuserhistory authorised User with hypermedia links
$test_user->PrincipalObj->GrantRight(Right => 'ShowUserHistory');
{
    my $user_id = $user_foo->id;
    my $res = $mech->get("$rest_base_path/user/$user_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    my $links = delete $content->{_hyperlinks};
    is(scalar(@$links),2);
    my @memberships_links = grep { $_->{ref} eq 'memberships' } @$links;
    is(scalar(@memberships_links), 0);
    my ($history_link) = grep { $_->{ref} eq 'history' } @$links;
    like($history_link->{_url}, qr{$rest_base_path/user/$user_id/history$});

    is_deeply($content, {
        Name     => 'foo',
        RealName => 'Foo Jr III',
        EmailAddress => 'test@test.test',
        'Privileged' => 1
    }, 'basic summary for user ok, no extra fields');
}

# useradmin authorised User with hypermedia links
$test_user->PrincipalObj->GrantRight(Right => 'AdminUsers');
$test_user->PrincipalObj->GrantRight(Right => 'AdminGroupMembership');
{
    my $user_id = $user_foo->id;
    my $res = $mech->get("$rest_base_path/user/$user_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    # test hyperlinks
    my $links = delete $content->{_hyperlinks};
    is(scalar(@$links),3);
    my ($history_link) = grep { $_->{ref} eq 'history' } @$links;
    like($history_link->{_url}, qr{$rest_base_path/user/$user_id/history$});
    my @memberships_links = grep { $_->{ref} eq 'memberships' } @$links;
    is(scalar(@memberships_links), 1);
    like($memberships_links[0]->{_url}, qr{$rest_base_path/user/$user_id/groups$});
    my ($self_link) = grep { $_->{ref} eq 'self' } @$links;
    like($self_link->{_url}, qr{$rest_base_path/user/$user_id$});

    cmp_deeply($content,
        superhashof({
            'RealName' => 'Foo Jr III',
            'Privileged' => 1,
            'Memberships' => [],
            'Disabled' => '0',
            'Name' => 'foo',
            'EmailAddress' => 'test@test.test',
            'CustomFields' => []
        })
    );
}

$test_user->PrincipalObj->RevokeRight(Right => 'ShowUserHistory');
$test_user->PrincipalObj->RevokeRight(Right => 'AdminUsers');

done_testing;
