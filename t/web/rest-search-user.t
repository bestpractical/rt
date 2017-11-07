use strict;
use warnings;
use RT::Test tests => undef;

my $root = RT::Test->load_or_create_user( Name => 'root', );
my $user_foo = RT::Test->load_or_create_user(
    Name     => 'foo',
    Password => 'password',
);
my $user_bar = RT::Test->load_or_create_user( Name => 'bar' );
my $user_baz = RT::Test->load_or_create_user( Name => 'baz' );
$user_baz->SetDisabled(1);

my ( $baseurl, $m ) = RT::Test->started_ok;

ok( $m->login, 'logged in' );

search_users_ok(
    { query => 'id = ' . $user_foo->id },
    [ $user_foo->id . ': foo' ],
    'search by id'
);

search_users_ok(
    {
        query  => 'Name = ' . $user_foo->Name,
        format => 's',
        fields => 'id,name'
    },
    [ "id\tName", $user_foo->id . "\tfoo" ],
    'search by name with customized fields'
);


search_users_ok(
    { query => 'foo = 3' },
    ['Invalid field specification: foo'],
    'invalid field'
);

search_users_ok(
    { query => 'id foo 3' },
    ['Invalid operator specification: foo'],
    'invalid op'
);

search_users_ok(
    { query => 'password = foo' },
    ['Invalid field specification: password'],
    "can't search password"
);

search_users_ok(
    { query => '', orderby => 'id' },
    [ $root->id . ': root', $user_foo->id . ': foo', $user_bar->id . ': bar', ],
    'order by id'
);

search_users_ok(
    { query => '', orderby => 'name' },
    [ $user_bar->id . ': bar', $user_foo->id . ': foo', $root->id . ': root' ],
    'order by name'
);

search_users_ok(
    { query => '', orderby => '+name' },
    [ $user_bar->id . ': bar', $user_foo->id . ': foo', $root->id . ': root' ],
    'order by +name'
);

search_users_ok(
    { query => '', orderby => '-name' },
    [ $root->id . ': root', $user_foo->id . ': foo', $user_bar->id . ': bar' ],
    'order by -name'
);

search_users_ok(
    { query => 'Disabled = 0', orderby => 'id' },
    [ $root->id . ': root', $user_foo->id . ': foo', $user_bar->id . ': bar', ],
    'enabled users'
);

search_users_ok(
    { query => 'Disabled = 1', orderby => 'id' },
    [ $user_baz->id . ': baz', ],
    'disabled users'
);

ok( $m->login( 'foo', 'password', logout => 1 ), 'logged in as foo' );
search_users_ok(
    { query => 'id = ' . $user_foo->id },
    [ 'Permission denied' ],
    "can't search without permission"
);

sub search_users_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $query    = shift;
    my $expected = shift;
    my $name     = shift || 'search users';

    my $uri = URI->new("$baseurl/REST/1.0/search/user");
    $uri->query_form(%$query);
    $m->get_ok($uri);

    my @lines = split /\n/, $m->content;
    shift @lines;    # header
    shift @lines;    # empty line

    is_deeply( \@lines, $expected, $name );

}

done_testing;
