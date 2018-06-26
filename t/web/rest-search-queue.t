use strict;
use warnings;
use RT::Test tests => undef;

my $queue_foo = RT::Test->load_or_create_queue( Name => 'Foo' );
my $queue_bar = RT::Test->load_or_create_queue( Name => 'Bar' );
my $queue_baz = RT::Test->load_or_create_queue( Name => 'Baz' );
$queue_baz->SetDisabled(1);

my ( $baseurl, $m ) = RT::Test->started_ok;

ok( $m->login, 'logged in' );

search_queues_ok( { query => 'id = 1' }, ['1: General'], 'search id = 1' );
search_queues_ok(
    {
        query  => 'Name = General',
        format => 's',
        fields => 'id,name,description'
    },
    [ "id\tName\tDescription", "1\tGeneral\tThe default queue" ],
    'search by name with customized fields'
);

search_queues_ok(
    { query => 'id > 10' },
    ['No matching results.'],
    'no matching results'
);

search_queues_ok(
    { query => 'foo = 3' },
    ['Invalid field specification: foo'],
    'invalid field'
);

search_queues_ok(
    { query => 'id foo 3' },
    ['Invalid operator specification: foo'],
    'invalid op'
);

search_queues_ok(
    { query => '', orderby => 'id' },
    [ '1: General', $queue_foo->id . ': Foo', $queue_bar->id . ': Bar', ],
    'order by id'
);

search_queues_ok(
    { query => '', orderby => 'name' },
    [ $queue_bar->id . ': Bar', $queue_foo->id . ': Foo', '1: General', ],
    'order by name'
);

search_queues_ok(
    { query => '', orderby => '+name' },
    [ $queue_bar->id . ': Bar', $queue_foo->id . ': Foo', '1: General', ],
    'order by +name'
);

search_queues_ok(
    { query => '', orderby => '-name' },
    [ '1: General', $queue_foo->id . ': Foo', $queue_bar->id . ': Bar', ],
    'order by -name'
);

search_queues_ok(
    { query => 'Disabled = 0', orderby => 'id' },
    [ '1: General', $queue_foo->id . ': Foo', $queue_bar->id . ': Bar', ],
    'enabled queues'
);

search_queues_ok(
    { query => 'Disabled = 1', orderby => 'id' },
    [ $queue_baz->id . ': Baz', ],
    'disabled queues'
);

search_queues_ok(
    { query => 'Disabled = 2', orderby => 'id' },
    [ '2: ___Approvals', ],
    'special Approvals queue'
);

sub search_queues_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $query    = shift;
    my $expected = shift;
    my $name     = shift || 'search queues';

    my $uri = URI->new("$baseurl/REST/1.0/search/queue");
    $uri->query_form(%$query);
    $m->get_ok($uri);

    my @lines = split /\n/, $m->content;
    shift @lines;    # header
    shift @lines;    # empty line

    is_deeply( \@lines, $expected, $name );

}

done_testing;
