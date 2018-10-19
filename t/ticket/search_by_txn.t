
use warnings;
use strict;


BEGIN{ $ENV{'TZ'} = 'GMT'};

use RT::Test tests => undef;

my $SUBJECT = "Search test - ".$$;

use_ok('RT::Tickets');
my $tix = RT::Tickets->new(RT->SystemUser);
can_ok($tix, 'FromSQL');
$tix->FromSQL('Updated = "2005-08-05" AND Subject = "$SUBJECT"');

ok(! $tix->Count, "Searching for tickets updated on a random date finds nothing" . $tix->Count);

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Create(Queue => 'General', Subject => $SUBJECT);
ok ($ticket->id, "We created a ticket");
my ($id, $txnid, $txnobj) =  $ticket->Comment( Content => 'A comment that happend on 2004-01-01');

isa_ok($txnobj, 'RT::Transaction');

ok($txnobj->CreatedObj->ISO);

my $user = RT::CurrentUser->new( RT->SystemUser );
ok( $user->Load('root'),                          'Loaded user root' );
ok( $user->UserObj->SetTimezone('Asia/Shanghai'), 'Updated root timezone to +08:00' );

ok($txnobj->__Set(Field => 'Created', Value => '2005-08-05 20:00:56'), 'Updated txn created to UTC 2005-08-05 20:00:56');
is($txnobj->Created,         '2005-08-05 20:00:56', 'Created date');
is($txnobj->CreatedObj->ISO, '2005-08-05 20:00:56', 'Created ISO');

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL(qq{Updated = "2005-08-05" AND Subject = "$SUBJECT"});
is($tix->Count, 1, "Found the ticket using 2005-08-05 for system user");

$tix = RT::Tickets->new($user);
$tix->FromSQL(qq{Updated = "2005-08-06" AND Subject = "$SUBJECT"});
is($tix->Count, 1, "Found the ticket using 2005-08-06 for user in +08:00 timezone");

ok($txnobj->__Set(Field => 'Created', Value => '2005-08-05 06:00:56'), 'Updated txn created to UTC 2005-08-05 06:00:56');

$tix = RT::Tickets->new(RT->SystemUser);
$tix->FromSQL(qq{Updated = "2005-08-05" AND Subject = "$SUBJECT"});
is($tix->Count, 1, "Found the ticket using 2005-08-05 for system user");

$tix = RT::Tickets->new($user);
$tix->FromSQL(qq{Updated = "2005-08-05" AND Subject = "$SUBJECT"});
is($tix->Count, 1, "Found the ticket using 2005-08-05 for user in +08:00 timezone");

done_testing;
