use strict;
use warnings;
use RT::Extension::REST2::Test tests => undef;
use Test::Deep;

my $mech = RT::Extension::REST2::Test->mech;

my $auth = RT::Extension::REST2::Test->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Extension::REST2::Test->user;

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


done_testing;

