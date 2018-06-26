use strict;
use warnings;
use RT::Test tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;

RT::Test->create_tickets(
    { },
    { Subject => 'uno'  },
    { Subject => 'dos'  },
    { Subject => 'tres' },
);

ok($m->login, 'logged in');

sorted_tickets_ok('Subject',  ['2: dos', '3: tres', '1: uno']);
sorted_tickets_ok('+Subject', ['2: dos', '3: tres', '1: uno']);
sorted_tickets_ok('-Subject', ['1: uno', '3: tres', '2: dos']);

sorted_tickets_ok('id',  ['1: uno',  '2: dos', '3: tres']);
sorted_tickets_ok('+id', ['1: uno',  '2: dos', '3: tres']);
sorted_tickets_ok('-id', ['3: tres', '2: dos', '1: uno']);

done_testing;

sub sorted_tickets_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $order    = shift;
    my $expected = shift;

    my $query = 'id > 0';

    my $uri = URI->new("$baseurl/REST/1.0/search/ticket");
    $uri->query_form(
        query   => $query,
        orderby => $order,
    );
    $m->get_ok($uri);

    my @lines = split /\n/, $m->content;
    shift @lines; # header
    shift @lines; # empty line

    is_deeply(\@lines, $expected, "sorted results by '$order'");
}
