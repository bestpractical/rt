use strict;
use warnings;
use RT::Test tests => undef;

my $group_foo = RT::Group->new($RT::SystemUser);
$group_foo->CreateUserDefinedGroup( Name => 'foo' );

my $group_bar = RT::Group->new($RT::SystemUser);
$group_bar->CreateUserDefinedGroup( Name => 'bar' );

my $group_baz = RT::Group->new($RT::SystemUser);
$group_baz->CreateUserDefinedGroup( Name => 'baz' );
$group_baz->SetDisabled(1);

my ( $baseurl, $m ) = RT::Test->started_ok;

ok( $m->login, 'logged in' );

search_groups_ok(
    { query => 'id = ' . $group_foo->id },
    [ $group_foo->id . ': foo' ],
    'search by id'
);

search_groups_ok(
    {
        query  => 'Name = ' . $group_foo->Name,
        format => 's',
        fields => 'id,name',
    },
    [ "id\tName", $group_foo->id . "\tfoo" ],
    'search by name with customized fields'
);

search_groups_ok(
    { query => 'foo = 3' },
    ['Invalid field specification: foo'],
    'invalid field'
);

search_groups_ok(
    { query => 'id foo 3' },
    ['Invalid operator specification: foo'],
    'invalid op'
);

search_groups_ok(
    { query => '', orderby => 'id' },
    [ $group_foo->id . ': foo', $group_bar->id . ': bar', ],
    'order by id'
);

search_groups_ok(
    { query => '', orderby => 'name' },
    [ $group_bar->id . ': bar', $group_foo->id . ': foo' ],
    'order by name'
);

search_groups_ok(
    { query => '', orderby => '+name' },
    [ $group_bar->id . ': bar', $group_foo->id . ': foo' ],
    'order by +name'
);

search_groups_ok(
    { query => '', orderby => '-name' },
    [ $group_foo->id . ': foo', $group_bar->id . ': bar' ],
    'order by -name'
);

search_groups_ok(
    { query => 'Disabled = 0', orderby => 'id' },
    [ $group_foo->id . ': foo', $group_bar->id . ': bar' ],
    'enabled groups'
);

search_groups_ok(
    { query => 'Disabled = 1', orderby => 'id' },
    [ $group_baz->id . ': baz' ],
    'disabled groups'
);

sub search_groups_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $query    = shift;
    my $expected = shift;
    my $name     = shift || 'search groups';

    my $uri = URI->new("$baseurl/REST/1.0/search/group");
    $uri->query_form(%$query);
    $m->get_ok($uri);

    my @lines = split /\n/, $m->content;
    shift @lines;    # header
    shift @lines;    # empty line

    is_deeply( \@lines, $expected, $name );

}

done_testing;
