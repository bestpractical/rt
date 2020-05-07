use strict;
use warnings;
use RT::Test::REST2 tests => undef;

my $mech = RT::Test::REST2->mech;
my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';

sub is_404 {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res = shift;
    is($res->code, 404);
    is($mech->json_response->{message}, 'Not Found');
}

# Proper 404 Response
{
    for (qw[
        /foobar
        /foo
        /index.html
        /ticket.do/1
        /ticket/foo
        /1/1
        /record
        /collection
    ]) {
        my $path = $rest_base_path . $_;
        is_404($mech->get($path, 'Authorization' => $auth));
        is_404($mech->post($path, { param => 'value' }, 'Authorization' => $auth));
    }
}

done_testing;
