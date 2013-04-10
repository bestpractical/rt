
use strict;
use warnings;
use RT;
use RT::Test tests => undef;
use Test::Warn;

use_ok ('RT::Transaction');

{
    my $u = RT::User->new(RT->SystemUser);
    $u->Load("root");
    ok ($u->Id, "Found the root user");
    ok(my $t = RT::Ticket->new(RT->SystemUser));
    my ($id, $msg) = $t->Create( Queue => 'General',
                                    Subject => 'Testing',
                                    Owner => $u->Id
                               );
    ok($id, "Create new ticket $id");
    isnt($id , 0);

    my $txn = RT::Transaction->new(RT->SystemUser);
    my ($txn_id, $txn_msg) = $txn->Create(
                  Type => 'AddLink',
                  Field => 'RefersTo',
                  Ticket => $id,
                  NewValue => 'ticket 42', );
    ok( $txn_id, "Created transaction $txn_id: $txn_msg");

    my $brief;
    warning_like { $brief = $txn->BriefDescription }
                  qr/Could not determine a URI scheme/,
                    "Caught URI warning";

    is( $brief, 'Reference to ticket 42 added', "Got string description: $brief");

    $txn = RT::Transaction->new(RT->SystemUser);
    ($txn_id, $txn_msg) = $txn->Create(
                  Type => 'DeleteLink',
                  Field => 'RefersTo',
                  Ticket => $id,
                  OldValue => 'ticket 42', );
    ok( $txn_id, "Created transaction $txn_id: $txn_msg");

    warning_like { $brief = $txn->BriefDescription }
                  qr/Could not determine a URI scheme/,
                    "Caught URI warning";

    is( $brief, 'Reference to ticket 42 deleted', "Got string description: $brief");
}

done_testing;
