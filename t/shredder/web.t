use strict;
use warnings;

use Test::Deep;
use RT::Test::Shredder tests => undef;

my $test = "RT::Test::Shredder";
my ( $baseurl, $agent ) = RT::Test->started_ok;
# test a login
{
    $agent->login('root' => 'password');
    # the field isn't named, so we have to click link 0
    is( $agent->status, 200, "Fetched the page ok");
    $agent->content_contains("Logout", "Found a logout link");
}

{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id) = $ticket->Create( Subject => 'test', Queue => 1 );
    ok( $id, "created new ticket" );
    $ticket->ApplyTransactionBatch;
    $agent->get($baseurl . '/Admin/Tools/Shredder/?Plugin=Tickets&Tickets%3Alimit=&Tickets%3Aquery=id%3D1&Tickets&WipeoutObject=RT%3A%3ATicket-example.com-1&Wipeout=Wipeout');
    ok $agent;
}
done_testing();
