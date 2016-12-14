use strict;
use warnings;

use RT::Test tests => undef;

use_ok('RT::Record::Role::Roles');

diag 'Test merging with RT email address as Cc';
# This confirms we catch errors when trying to assign an email RT
# owns as a Cc during merge.

my $user_a = RT::Test->load_or_create_user(
    Name         => 'user_a',
    Password     => 'password',
    EmailAddress => 'user_a@example.com',
);
ok( $user_a && $user_a->id, 'loaded or created user' );

my ($ticket1) = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test subject',
    Requestor      => 'user_a@example.com',
);

ok($ticket1->Id, 'Got a new ticket');

my ($ticket2) = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'test subject',
    Requestor      => 'user_a@example.com',
);

ok($ticket2->Id, 'Got another new ticket');

$ticket2->AddWatcher( Type => 'Cc', Email => 'rt@example.com' );

ok(RT::Config->Set('RTAddressRegexp', 'rt@example.com'), 'Set RTAddressRegexp');
is(RT::Config->Get('RTAddressRegexp'), 'rt@example.com', 'Got back RTAddressRegexp');
ok(RT::EmailParser->IsRTAddress( 'rt@example.com' ), 'rt@exmaple.com is an RT address');

my ($status,$msg) = $ticket2->MergeInto($ticket1->Id);
ok( $status, 'Ticket merge ok');


done_testing();
