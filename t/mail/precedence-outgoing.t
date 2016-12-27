use strict;
use warnings;

use RT::Test tests => undef;
use RT::Test::Email;
use Test::Warn;

RT->Config->Set( DefaultMailPrecedence => "bulk" );
RT->Config->Set( OverrideMailPrecedence => {
    "test_list" => "list",
    "test_undef" => undef,
});

{
    my $queue = RT::Test->load_or_create_queue( Name => 'General' );
    ok $queue && $queue->id, 'loaded or created queue General';

    my $ticket = RT::Ticket->new( RT::CurrentUser->new( RT->SystemUser ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue     => $queue->id,
            Subject   => 'test bulk',
            Requestor => 'root@localhost',
        );
        ok $status, "created ticket 'test bulk'";
    } { Precedence => "bulk" };
}

{
    my $queue = RT::Test->load_or_create_queue( Name => "test_list" );
    ok $queue && $queue->id, 'loaded or created queue test_list';

    my $ticket = RT::Ticket->new( RT::CurrentUser->new( RT->SystemUser ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue     => $queue->id,
            Subject   => 'test list',
            Requestor => 'root@localhost',
        );
        ok $status, "created ticket 'test list'";
    } { Precedence => "list" };
}

{
    my $queue = RT::Test->load_or_create_queue( Name => "test_undef" );
    ok $queue && $queue->id, 'loaded or created queue test_undef';

    my $ticket = RT::Ticket->new( RT::CurrentUser->new( RT->SystemUser ) );
    mail_ok {
        my ($status, undef, $msg) = $ticket->Create(
            Queue     => $queue->id,
            Subject   => 'test undef',
            Requestor => 'root@localhost',
        );
        ok $status, "created ticket 'test undef'";
    } { Precedence => "" };
}

done_testing;
