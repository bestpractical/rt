use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my $parent = RT::Ticket->new(RT->SystemUser);
my ($ok, undef, $msg) = $parent->Create(Queue => 'General', Subject => 'parent ticket');
ok($ok, $msg);
my $parent_id = $parent->Id;

my $child = RT::Ticket->new(RT->SystemUser);
($ok, undef, $msg) = $child->Create(Queue => 'General', Subject => 'child ticket');
ok($ok, $msg);
my $child_id = $child->Id;

($ok, $msg) = $child->AddLink(Type => 'MemberOf', Target => $parent->id);
ok($ok, $msg);

($ok, $msg) = $child->AddLink(Type => 'RefersTo', Target => 'https://bestpractical.com');
ok($ok, $msg);

$user->PrincipalObj->GrantRight( Right => 'ShowTicket' );

# Inspect existing ticket links (parent)
{

    my $res = $mech->get("$rest_base_path/ticket/$parent_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    my %links;
    for (@{ $content->{_hyperlinks} }) {
        push @{ $links{$_->{ref}} }, $_;
    }

    cmp_deeply($links{'depends-on'}, undef, 'no depends-on links');
    cmp_deeply($links{'depended-on-by'}, undef, 'no depended-on-by links');
    cmp_deeply($links{'parent'}, undef, 'no parent links');
    cmp_deeply($links{'refers-to'}, undef, 'no refers-to links');
    cmp_deeply($links{'referred-to-by'}, undef, 'no referred-to-by links');

    cmp_deeply($links{'child'}, [{
        ref  => 'child',
        type => 'ticket',
        id   => $child->Id,
        _url => re(qr{$rest_base_path/ticket/$child_id$}),
    }], 'one child link');
}

# Inspect existing ticket links (child)
{

    my $res = $mech->get("$rest_base_path/ticket/$child_id",
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    my %links;
    for (@{ $content->{_hyperlinks} }) {
        push @{ $links{$_->{ref}} }, $_;
    }

    cmp_deeply($links{'depends-on'}, undef, 'no depends-on links');
    cmp_deeply($links{'depended-on-by'}, undef, 'no depended-on-by links');
    cmp_deeply($links{'child'}, undef, 'no child links');
    cmp_deeply($links{'referred-to-by'}, undef, 'no referred-to-by links');

    cmp_deeply($links{'parent'}, [{
        ref  => 'parent',
        type => 'ticket',
        id   => $parent->Id,
        _url => re(qr{$rest_base_path/ticket/$parent_id$}),
    }], 'one child link');

    cmp_deeply($links{'refers-to'}, [{
        ref  => 'refers-to',
        type => 'external',
        _url => re(qr{https\:\/\/bestpractical\.com}),
    }], 'one external refers-to link');
}

# Create/Modify ticket with links
$user->PrincipalObj->GrantRight( Right => $_ ) for qw/CreateTicket ModifyTicket/;

{
    my $res = $mech->post_json(
        "$rest_base_path/ticket",
        { Queue => 'General', DependsOn => [ $parent_id, $child_id ], RefersTo => $child_id },
        'Authorization' => $auth,
    );
    is( $res->code, 201, 'post response code' );
    my $content = $mech->json_response;
    my $id      = $content->{id};
    ok( $id, "create another ticket with links" );

    $res = $mech->put_json( "$rest_base_path/ticket/$id", { RefersTo => $parent_id }, 'Authorization' => $auth, );
    is( $res->code, 200, 'put response code' );

    $content = $mech->json_response;
    is_deeply(
        $content,
        [ "Ticket $id refers to Ticket $parent_id.", "Ticket $id no longer refers to Ticket $child_id." ],
        'update RefersTo'
    );

    $res = $mech->put_json(
        "$rest_base_path/ticket/$id",
        { DeleteDependsOn => $parent_id, AddMembers => [ $parent_id, $child_id ] },
        'Authorization' => $auth
    );
    is( $res->code, 200, 'put response code' );
    $content = $mech->json_response;
    is_deeply(
        $content,
        [   "Ticket $id no longer depends on Ticket $parent_id.",
            "Ticket $parent_id member of Ticket $id.",
            "Ticket $child_id member of Ticket $id."
        ],
        'add Members and delete DependsOn'
    );
}

done_testing;

