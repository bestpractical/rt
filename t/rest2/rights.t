use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

# Create a queue and a group for testing
my $queue = RT::Queue->new( RT->SystemUser );
my ( $ok, $msg ) = $queue->Create( Name => 'Rights Test Queue' );
ok( $ok, "Created queue: $msg" );

my $group = RT::Group->new( RT->SystemUser );
( $ok, $msg ) = $group->CreateUserDefinedGroup( Name => 'Rights Test Group' );
ok( $ok, "Created group: $msg" );

my $queue_id = $queue->Id;
my $group_id = $group->Id;

# Create a second user to grant rights to
my $other_user = RT::User->new( RT->SystemUser );
( $ok, $msg ) = $other_user->Create( Name => 'rights-test-user', Privileged => 1 );
ok( $ok, "Created other user: $msg" );

my $queue_rights_url  = "$rest_base_path/queue/$queue_id/rights";
my $queue_avail_url   = "$rest_base_path/queue/$queue_id/rights/available";
my $queue_bulk_url    = "$rest_base_path/queue/$queue_id/rights/bulk";
my $group_rights_url  = "$rest_base_path/group/$group_id/rights";
my $system_rights_url = "$rest_base_path/system/rights";

# -- Permission checks for GET endpoints --

diag "GET available rights requires AdminQueue";
{
    my $res = $mech->get( $queue_avail_url, 'Authorization' => $auth );
    is( $res->code, 403, 'Forbidden without AdminQueue' );

    $user->PrincipalObj->GrantRight( Right => 'AdminQueue', Object => $queue );

    $res = $mech->get( $queue_avail_url, 'Authorization' => $auth );
    is( $res->code, 200, 'Allowed with AdminQueue' );

    my $content = $mech->json_response;
    ok( exists $content->{General},              'Has General category' );
    ok( exists $content->{Admin},                'Has Admin category' );
    ok( exists $content->{General}{SeeQueue},    'SeeQueue in General' );
    ok( exists $content->{General}{CreateTicket},'CreateTicket in General' );
    ok( exists $content->{Admin}{ModifyACL},     'ModifyACL in Admin' );
    ok( !exists $content->{General}{SuperUser},  'SuperUser not in queue rights' );
}

diag "GET rights list requires AdminQueue";
{
    # AdminQueue still held from previous block
    my $res = $mech->get( $queue_rights_url, 'Authorization' => $auth );
    is( $res->code, 200, 'Can list rights with AdminQueue' );

    my $content = $mech->json_response;
    is( $content->{total}, 1, 'One right granted (AdminQueue for test user)' );
}

# -- Grant and revoke operations --
# AdminQueue gates the REST2 endpoint. The underlying RT::ACE layer
# additionally requires ModifyACL (for grant/revoke) and ShowACL
# (for reading ACE fields and recording transactions).

$user->PrincipalObj->GrantRight( Right => 'ModifyACL', Object => $queue );
$user->PrincipalObj->GrantRight( Right => 'ShowACL',   Object => $queue );

diag "POST to grant a right to a group";
{
    my $payload = { Right => 'CreateTicket', Group => 'Rights Test Group' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted CreateTicket to group' );

    my $content = $mech->json_response;
    is( $content->{Right},       'CreateTicket',     'Response right name' );
    is( $content->{Group}{id},   $group->Id + 0,     'Response group id' );
    is( $content->{Group}{Name}, 'Rights Test Group', 'Response group name' );

    # Verify in list
    $res = $mech->get( $queue_rights_url, 'Authorization' => $auth );
    my $list = $mech->json_response;
    my @items = grep { $_->{Right} eq 'CreateTicket' } @{ $list->{items} };
    is( scalar @items, 1, 'CreateTicket appears in rights list' );
    is( $items[0]{Group}{Name}, 'Rights Test Group', 'Correct group in list' );
}

diag "POST duplicate returns 409";
{
    my $payload = { Right => 'CreateTicket', Group => 'Rights Test Group' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 409, 'Duplicate grant returns 409' );
}

diag "POST to grant a right to a user";
{
    my $payload = { Right => 'OwnTicket', User => 'rights-test-user' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted OwnTicket to user' );

    my $content = $mech->json_response;
    is( $content->{Right},      'OwnTicket',        'Response right name' );
    is( $content->{User}{Name}, 'rights-test-user', 'Response user name' );
    ok( !exists $content->{Group}, 'No Group key in user grant' );

    # Verify in list
    my $res2 = $mech->get( $queue_rights_url, 'Authorization' => $auth );
    my $list = $mech->json_response;
    my @items = grep { $_->{Right} eq 'OwnTicket' } @{ $list->{items} };
    is( scalar @items, 1, 'OwnTicket appears in rights list' );
    is( $items[0]{User}{Name}, 'rights-test-user', 'Correct user in list' );
    ok( !exists $items[0]{Group}, 'No Group key on user grant in list' );
}

diag "POST with group ID object";
{
    my $payload = { Right => 'CommentOnTicket', Group => { id => $group->Id } };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted right using group id object' );
}

diag "POST to grant a right to a system group by name";
{
    my $payload = { Right => 'SeeQueue', Group => 'Everyone' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted SeeQueue to Everyone' );

    my $content = $mech->json_response;
    is( $content->{Right},       'SeeQueue',  'Response right name' );
    is( $content->{Group}{Name}, 'Everyone',  'Response group name is Everyone' );
    ok( $content->{Group}{id},                'Response has group id' );
}

diag "POST to grant a right to Privileged system group";
{
    my $payload = { Right => 'CreateTicket', Group => 'Privileged' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted CreateTicket to Privileged' );

    my $content = $mech->json_response;
    is( $content->{Group}{Name}, 'Privileged', 'Response group name is Privileged' );
}

diag "POST to grant a right to a role group by name";
{
    my $payload = { Right => 'ShowTicket', Group => 'Requestor' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted ShowTicket to Requestor role' );

    my $content = $mech->json_response;
    is( $content->{Right},       'ShowTicket', 'Response right name' );
    is( $content->{Group}{Name}, 'Requestor',  'Response group name is Requestor' );
}

diag "POST to grant a right to Owner role";
{
    my $payload = { Right => 'ModifyTicket', Group => 'Owner' };
    my $res = $mech->post_json( $queue_rights_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Granted ModifyTicket to Owner role' );

    my $content = $mech->json_response;
    is( $content->{Group}{Name}, 'Owner', 'Response group name is Owner' );
}

diag "Bulk grant with system and role groups";
{
    my $payload = {
        grant => [
            { Right => 'ReplyToTicket', Group => 'Everyone' },
            { Right => 'CommentOnTicket', Group => 'AdminCc' },
            { Right => 'Watch', Group => 'Unprivileged' },
        ],
    };
    my $res = $mech->post_json( $queue_bulk_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Bulk grant with system/role groups returns 201' );

    my $content = $mech->json_response;
    is( $content->{granted}[0]{status}, 201, 'Everyone grant succeeded' );
    is( $content->{granted}[0]{Group}{Name}, 'Everyone', 'Everyone in response' );
    is( $content->{granted}[1]{status}, 201, 'AdminCc grant succeeded' );
    is( $content->{granted}[1]{Group}{Name}, 'AdminCc', 'AdminCc in response' );
    is( $content->{granted}[2]{status}, 201, 'Unprivileged grant succeeded' );
    is( $content->{granted}[2]{Group}{Name}, 'Unprivileged', 'Unprivileged in response' );
}

diag "POST error cases";
{
    my $res = $mech->post_json( $queue_rights_url,
        { Right => 'NoSuchRight', Group => 'Rights Test Group' },
        'Authorization' => $auth );
    is( $res->code, 400, 'Invalid right name returns 400' );

    $res = $mech->post_json( $queue_rights_url,
        { Right => 'CreateTicket' },
        'Authorization' => $auth );
    is( $res->code, 400, 'Missing principal returns 400' );

    $res = $mech->post_json( $queue_rights_url,
        { Right => 'CreateTicket', Group => 'No Such Group' },
        'Authorization' => $auth );
    is( $res->code, 400, 'Nonexistent group returns 400' );
}

diag "GET rights list filtered by group";
{
    my $res = $mech->get(
        "$queue_rights_url?group=$group_id",
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'Filtered by group' );
    my $content = $mech->json_response;
    ok( $content->{total} >= 1, 'At least one right for group' );
    for my $item ( @{ $content->{items} } ) {
        is( $item->{Group}{Name}, 'Rights Test Group',
            'Every item belongs to filtered group' );
    }
}

diag "DELETE to revoke a right";
{
    my $revoke_url = "$queue_rights_url/CreateTicket/group/$group_id";

    # Revoke AdminQueue to verify the gate
    $user->PrincipalObj->RevokeRight( Right => 'AdminQueue', Object => $queue );
    my $res = $mech->delete( $revoke_url, 'Authorization' => $auth );
    is( $res->code, 403, 'Cannot revoke without AdminQueue' );

    # Restore AdminQueue
    $user->PrincipalObj->GrantRight( Right => 'AdminQueue', Object => $queue );

    $res = $mech->delete( $revoke_url, 'Authorization' => $auth );
    is( $res->code, 204, 'Revoked CreateTicket' );

    # Verify removal — filter by group to avoid matches from other principals
    my $res2 = $mech->get( "$queue_rights_url?group=$group_id", 'Authorization' => $auth );
    my $list = $mech->json_response;
    my @remaining = grep { $_->{Right} eq 'CreateTicket' } @{ $list->{items} };
    is( scalar @remaining, 0, 'CreateTicket no longer in list for group' );
}

diag "DELETE user right";
{
    my $revoke_url = "$queue_rights_url/OwnTicket/user/" . $other_user->Id;
    my $res = $mech->delete( $revoke_url, 'Authorization' => $auth );
    is( $res->code, 204, 'Revoked user right' );

    my $res2 = $mech->get( $queue_rights_url, 'Authorization' => $auth );
    my $list = $mech->json_response;
    my @remaining = grep { $_->{Right} eq 'OwnTicket' } @{ $list->{items} };
    is( scalar @remaining, 0, 'OwnTicket no longer in list' );
}

diag "DELETE nonexistent right returns 404";
{
    my $revoke_url = "$queue_rights_url/CreateTicket/group/$group_id";
    my $res = $mech->delete( $revoke_url, 'Authorization' => $auth );
    is( $res->code, 404, 'Nonexistent right returns 404' );
}

diag "Queue accessible by name in rights URLs";
{
    my $name_base = "$rest_base_path/queue/Rights%20Test%20Queue/rights";

    my $res = $mech->get( $name_base, 'Authorization' => $auth );
    is( $res->code, 200, 'GET rights by queue name works' );

    # Grant a right so we can delete it by queue name
    $group->PrincipalObj->GrantRight( Right => 'SeeQueue', Object => $queue );

    my $delete_url = "$name_base/SeeQueue/group/$group_id";
    $res = $mech->delete( $delete_url, 'Authorization' => $auth );
    is( $res->code, 204, 'DELETE right by queue name works' );
}

diag "Bulk grant and revoke";
{
    my $payload = {
        grant => [
            { Right => 'CreateTicket',  Group => 'Rights Test Group' },
            { Right => 'ReplyToTicket', Group => 'Rights Test Group' },
            { Right => 'OwnTicket',     User  => 'rights-test-user'  },
            { Right => 'NoSuchRight',   Group => 'Rights Test Group' },
        ],
        revoke => [
            { Right => 'CommentOnTicket', Group => 'Rights Test Group' },
        ],
    };

    my $res = $mech->post_json( $queue_bulk_url, $payload, 'Authorization' => $auth );
    is( $res->code, 201, 'Bulk operation returns 201' );

    my $content = $mech->json_response;

    is( $content->{granted}[0]{Right},  'CreateTicket', 'First grant right' );
    is( $content->{granted}[0]{status}, 201,            'First grant status' );
    is( $content->{granted}[1]{status}, 201,            'Second grant status' );
    is( $content->{granted}[2]{Right},  'OwnTicket',    'Third grant right' );
    is( $content->{granted}[2]{status}, 201,            'Third grant status' );
    ok( exists $content->{granted}[2]{User},            'Third grant has User key' );
    is( $content->{granted}[3]{status}, 400,            'Invalid right returns 400' );

    is( $content->{revoked}[0]{Right},  'CommentOnTicket', 'Revoke right' );
    is( $content->{revoked}[0]{status}, 204,               'Revoke status' );
}

# -- System-level rights (requires SuperUser) --

diag "System rights require SuperUser";
{
    my $res = $mech->get( $system_rights_url, 'Authorization' => $auth );
    is( $res->code, 403, 'Cannot access system rights without SuperUser' );

    $user->PrincipalObj->GrantRight( Right => 'SuperUser' );

    $res = $mech->get( $system_rights_url, 'Authorization' => $auth );
    is( $res->code, 200, 'Can list system rights with SuperUser' );

    my $avail_res = $mech->get( "$rest_base_path/system/rights/available",
        'Authorization' => $auth );
    is( $avail_res->code, 200, 'Can read system available rights' );
    my $avail = $mech->json_response;
    ok( exists $avail->{Admin}{SuperUser}, 'SuperUser in system available rights' );

    # Grant and revoke a system-level right
    my $grant_res = $mech->post_json( $system_rights_url,
        { Right => 'CreateTicket', Group => 'Rights Test Group' },
        'Authorization' => $auth );
    is( $grant_res->code, 201, 'Granted system-level right' );

    my $revoke_res = $mech->delete(
        "$system_rights_url/CreateTicket/group/$group_id",
        'Authorization' => $auth );
    is( $revoke_res->code, 204, 'Revoked system-level right' );

    $user->PrincipalObj->RevokeRight( Right => 'SuperUser' );
}

# -- Group rights (requires AdminGroup) --

diag "Group rights require AdminGroup";
{
    my $res = $mech->get( $group_rights_url, 'Authorization' => $auth );
    is( $res->code, 403, 'Cannot access group rights without AdminGroup' );

    $user->PrincipalObj->GrantRight( Right => 'AdminGroup', Object => $group );

    $res = $mech->get( $group_rights_url, 'Authorization' => $auth );
    is( $res->code, 200, 'Can access group rights with AdminGroup' );

    $user->PrincipalObj->RevokeRight( Right => 'AdminGroup', Object => $group );
}

# -- Hypermedia links --

diag "Queue hypermedia links include rights URLs with AdminQueue";
{
    $user->PrincipalObj->GrantRight( Right => 'SeeQueue', Object => $queue );

    my $res = $mech->get( "$rest_base_path/queue/$queue_id",
        'Authorization' => $auth );
    is( $res->code, 200, 'Got queue resource' );

    my $content = $mech->json_response;
    my @links = @{ $content->{_hyperlinks} };
    my @rights_links = grep { $_->{ref} eq 'rights' } @links;
    my @avail_links  = grep { $_->{ref} eq 'rights-available' } @links;

    is( scalar @rights_links, 1, 'Has rights link' );
    is( scalar @avail_links,  1, 'Has rights-available link' );
    like( $rights_links[0]{_url}, qr{/queue/$queue_id/rights$},
        'Rights URL is correct' );
}

# -- Paging --

diag "Paging support";
{
    my $pq = RT::Queue->new( RT->SystemUser );
    $pq->Create( Name => 'Paging Test Queue' );
    my $pq_id  = $pq->Id;
    my $pq_url = "$rest_base_path/queue/$pq_id/rights";

    $user->PrincipalObj->GrantRight( Right => 'AdminQueue', Object => $pq );
    $user->PrincipalObj->GrantRight( Right => 'ShowACL',   Object => $pq );

    # Grant 5 rights to the group
    for my $right (qw( CreateTicket ReplyToTicket CommentOnTicket OwnTicket SeeQueue )) {
        $group->PrincipalObj->GrantRight( Right => $right, Object => $pq );
    }

    my $res = $mech->get( "$pq_url?per_page=2&page=1", 'Authorization' => $auth );
    is( $res->code, 200, 'First page returns 200' );

    my $p1 = $mech->json_response;
    is( $p1->{per_page}, 2, 'per_page is 2' );
    is( $p1->{page},     1, 'page is 1' );
    is( $p1->{count},    2, 'count is 2 on first page' );
    ok( $p1->{total} > 2,   'total exceeds per_page' );
    ok( $p1->{pages} > 1,   'multiple pages' );
    ok( exists $p1->{next_page},    'next_page on first page' );
    ok( !exists $p1->{prev_page},   'no prev_page on first page' );

    # Follow next_page
    my $res2 = $mech->get( $p1->{next_page}, 'Authorization' => $auth );
    is( $res2->code, 200, 'Second page returns 200' );
    my $p2 = $mech->json_response;
    is( $p2->{page}, 2, 'page is 2' );
    ok( $p2->{count} > 0, 'second page has results' );
    ok( exists $p2->{prev_page}, 'prev_page on second page' );

    # Last page
    my $last_res = $mech->get( "$pq_url?per_page=2&page=$p1->{pages}",
        'Authorization' => $auth );
    my $last = $mech->json_response;
    ok( !exists $last->{next_page}, 'no next_page on last page' );

    # Defaults
    my $default_res = $mech->get( $pq_url, 'Authorization' => $auth );
    my $default = $mech->json_response;
    is( $default->{per_page}, 20, 'per_page defaults to 20' );
    is( $default->{page},      1, 'page defaults to 1' );
}

# -- Sub-field expansion --

diag "fields[User] and fields[Group] expansion";
{
    # CreateTicket on group and OwnTicket on user are still granted from
    # the bulk block above. AdminQueue and ModifyACL are still held.
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $queue );

    my $res = $mech->get(
        "$queue_rights_url?fields[Group]=Description&fields[User]=EmailAddress",
        'Authorization' => $auth,
    );
    is( $res->code, 200, 'Got rights with sub-field expansion' );

    my $content = $mech->json_response;
    my @group_items = grep { exists $_->{Group} } @{ $content->{items} };
    my @user_items  = grep { exists $_->{User}  } @{ $content->{items} };

    ok( scalar @group_items >= 1, 'At least one group grant' );
    ok( exists $group_items[0]{Group}{Description},
        'Group has requested Description subfield' );
    ok( exists $group_items[0]{Group}{Name}, 'Group Name still present' );

    ok( scalar @user_items >= 1, 'At least one user grant' );
    ok( exists $user_items[0]{User}{EmailAddress},
        'User has requested EmailAddress subfield' );
    ok( exists $user_items[0]{User}{Name}, 'User Name still present' );
}

done_testing();
