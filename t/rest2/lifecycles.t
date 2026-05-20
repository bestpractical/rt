use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $lifecycles_url = "$rest_base_path/lifecycles";

# -- Permission checks --

diag "Non-SuperUser gets 403 on all lifecycle endpoints";
{
    my $res = $mech->get( $lifecycles_url, 'Authorization' => $auth );
    is( $res->code, 403, 'GET /lifecycles forbidden without SuperUser' );

    $res = $mech->get( "$rest_base_path/lifecycle/default",
        'Authorization' => $auth );
    is( $res->code, 403, 'GET /lifecycle/:name forbidden without SuperUser' );
}

# Grant SuperUser for the rest of the tests
$user->PrincipalObj->GrantRight( Right => 'SuperUser', Object => RT->System );

# -- List lifecycles --

diag "GET /lifecycles returns available lifecycles";
{
    my $res = $mech->get( $lifecycles_url, 'Authorization' => $auth );
    is( $res->code, 200, 'GET /lifecycles succeeds' );

    my $content = $mech->json_response;
    ok( ref $content eq 'ARRAY', 'Response is an array' );
    ok( scalar @$content >= 1, 'At least one lifecycle returned' );

    my ($default) = grep { $_->{name} eq 'default' } @$content;
    ok( $default, 'default lifecycle present' );
    is( $default->{type}, 'ticket', 'default lifecycle is type ticket' );
    ok( ref $default->{initial} eq 'ARRAY', 'initial statuses is array' );
    ok( ref $default->{active} eq 'ARRAY', 'active statuses is array' );
    ok( ref $default->{inactive} eq 'ARRAY', 'inactive statuses is array' );
    like( $default->{_url}, qr{/lifecycle/default$}, '_url points to lifecycle' );

    # Ensure approvals lifecycle is excluded
    my ($approvals) = grep { $_->{name} eq 'approvals' } @$content;
    ok( !$approvals, 'approvals lifecycle excluded from list' );
}

diag "GET /lifecycles?type=ticket filters by type";
{
    my $res = $mech->get( "$lifecycles_url?type=ticket",
        'Authorization' => $auth );
    is( $res->code, 200, 'Filtered list succeeds' );

    my $content = $mech->json_response;
    my @non_ticket = grep { $_->{type} ne 'ticket' } @$content;
    is( scalar @non_ticket, 0, 'Only ticket lifecycles returned' );
}

# -- Get single lifecycle --

diag "GET /lifecycle/:name returns full lifecycle";
{
    my $res = $mech->get( "$rest_base_path/lifecycle/default",
        'Authorization' => $auth );
    is( $res->code, 200, 'GET /lifecycle/default succeeds' );

    my $content = $mech->json_response;
    is( $content->{name}, 'default', 'name field present' );
    is( $content->{type}, 'ticket', 'type field present' );
    ok( ref $content->{initial} eq 'ARRAY', 'initial statuses' );
    ok( ref $content->{active} eq 'ARRAY', 'active statuses' );
    ok( ref $content->{inactive} eq 'ARRAY', 'inactive statuses' );
    ok( exists $content->{transitions}, 'transitions present' );
    ok( exists $content->{defaults}, 'defaults present' );
    ok( ref $content->{used_by} eq 'ARRAY', 'used_by present' );
    like( $content->{_url}, qr{/lifecycle/default$}, '_url present' );

    # default lifecycle should be used by General queue
    my ($general) = grep { $_->{name} eq 'General' } @{ $content->{used_by} };
    ok( $general, 'General queue uses default lifecycle' );
}

diag "GET /lifecycle/nonexistent returns 404";
{
    my $res = $mech->get( "$rest_base_path/lifecycle/nonexistent",
        'Authorization' => $auth );
    is( $res->code, 404, 'Nonexistent lifecycle returns 404' );
}

# -- Create lifecycle --

diag "POST /lifecycles creates a new lifecycle";
{
    my $payload = { Name => 'test-lifecycle', Type => 'ticket' };
    my $res = $mech->post_json( $lifecycles_url, $payload,
        'Authorization' => $auth );
    is( $res->code, 201, 'Created lifecycle' );

    my $content = $mech->json_response;
    is( $content->{name}, 'test-lifecycle', 'Response has correct name' );
    like( $content->{_url}, qr{/lifecycle/test-lifecycle$}, '_url in response' );

    # Verify it shows up in list
    $res = $mech->get( $lifecycles_url, 'Authorization' => $auth );
    my $list = $mech->json_response;
    my ($found) = grep { $_->{name} eq 'test-lifecycle' } @$list;
    ok( $found, 'New lifecycle appears in list' );
}

diag "POST /lifecycles with Clone";
{
    my $payload = { Name => 'cloned-lifecycle', Type => 'ticket', Clone => 'default' };
    my $res = $mech->post_json( $lifecycles_url, $payload,
        'Authorization' => $auth );
    is( $res->code, 201, 'Created lifecycle by cloning' );

    my $content = $mech->json_response;
    is( $content->{name}, 'cloned-lifecycle', 'Cloned lifecycle name' );
    ok( ref $content->{initial} eq 'ARRAY' && @{ $content->{initial} },
        'Cloned lifecycle has initial statuses from default' );
}

diag "POST /lifecycles duplicate returns 409";
{
    my $payload = { Name => 'test-lifecycle', Type => 'ticket' };
    my $res = $mech->post_json( $lifecycles_url, $payload,
        'Authorization' => $auth );
    is( $res->code, 409, 'Duplicate lifecycle returns 409' );
}

diag "POST /lifecycles without Name returns 400";
{
    my $payload = { Type => 'ticket' };
    my $res = $mech->post_json( $lifecycles_url, $payload,
        'Authorization' => $auth );
    is( $res->code, 400, 'Missing Name returns 400' );
}

# -- Update lifecycle --

diag "PUT /lifecycle/:name updates configuration";
{
    my $new_config = {
        type       => 'ticket',
        initial    => ['new'],
        active     => ['open', 'working'],
        inactive   => ['resolved', 'rejected'],
        defaults   => {
            on_create => 'new',
            on_resolve => 'resolved',
        },
        transitions => {
            ''         => ['new'],
            new        => ['open', 'resolved', 'rejected'],
            open       => ['working', 'resolved', 'rejected'],
            working    => ['open', 'resolved', 'rejected'],
            resolved   => ['open'],
            rejected   => ['open'],
        },
    };

    my $res = $mech->put_json( "$rest_base_path/lifecycle/test-lifecycle",
        $new_config, 'Authorization' => $auth );
    is( $res->code, 200, 'Updated lifecycle' );

    my $content = $mech->json_response;
    is( $content->{name}, 'test-lifecycle', 'Response name correct' );
    cmp_deeply( $content->{active}, ['open', 'working'],
        'Updated active statuses' );
}

# -- Validate lifecycle --

diag "POST /lifecycle/:name/validate validates without saving";
{
    my $valid_config = {
        type       => 'ticket',
        initial    => ['new'],
        active     => ['open'],
        inactive   => ['resolved'],
        defaults   => { on_create => 'new' },
        transitions => {
            ''       => ['new'],
            new      => ['open', 'resolved'],
            open     => ['resolved'],
            resolved => ['open'],
        },
    };

    my $res = $mech->post_json(
        "$rest_base_path/lifecycle/test-lifecycle/validate",
        $valid_config, 'Authorization' => $auth );
    is( $res->code, 200, 'Validate endpoint succeeds' );

    my $content = $mech->json_response;
    ok( $content->{valid}, 'Lifecycle is valid' );
    is( ref $content->{warnings}, 'ARRAY', 'Warnings is an array' );
}

# -- Maps --

diag "GET /lifecycle/:name/maps returns mappings";
{
    my $res = $mech->get(
        "$rest_base_path/lifecycle/cloned-lifecycle/maps",
        'Authorization' => $auth );
    is( $res->code, 200, 'GET maps succeeds' );

    my $content = $mech->json_response;
    ok( ref $content eq 'HASH', 'Maps response is a hash' );
}

diag "PUT /lifecycle/:name/maps updates mappings";
{
    my $maps = {
        'test-lifecycle -> default' => {
            new      => 'new',
            open     => 'open',
            working  => 'open',
            resolved => 'resolved',
            rejected => 'rejected',
        },
        'default -> test-lifecycle' => {
            new      => 'new',
            open     => 'open',
            resolved => 'resolved',
            rejected => 'rejected',
        },
    };

    my $res = $mech->put_json(
        "$rest_base_path/lifecycle/test-lifecycle/maps",
        $maps, 'Authorization' => $auth );
    is( $res->code, 200, 'PUT maps succeeds' );

    my $content = $mech->json_response;
    ok( exists $content->{'test-lifecycle -> default'}, 'Forward map present' );
    ok( exists $content->{'default -> test-lifecycle'}, 'Reverse map present' );
}

# -- Delete lifecycle --

diag "DELETE lifecycle in use returns 409";
{
    # default is used by General queue
    my $res = $mech->delete( "$rest_base_path/lifecycle/default",
        'Authorization' => $auth );
    is( $res->code, 409, 'Cannot delete lifecycle in use' );
}

diag "DELETE unused lifecycle succeeds";
{
    my $res = $mech->delete( "$rest_base_path/lifecycle/test-lifecycle",
        'Authorization' => $auth );
    is( $res->code, 204, 'Deleted unused lifecycle' );

    # Verify it's gone
    $res = $mech->get( "$rest_base_path/lifecycle/test-lifecycle",
        'Authorization' => $auth );
    is( $res->code, 404, 'Deleted lifecycle returns 404' );
}

# Clean up cloned lifecycle
{
    my $res = $mech->delete( "$rest_base_path/lifecycle/cloned-lifecycle",
        'Authorization' => $auth );
    is( $res->code, 204, 'Cleaned up cloned lifecycle' );
}

done_testing;
