
use warnings;
use strict;


BEGIN{ $ENV{'TZ'} = 'GMT'};

use RT::Test tests => 10;

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
my ( $sid,$smsg) = $txnobj->__Set(Field => 'Created', Value => '2005-08-05 20:00:56');
ok($sid,$smsg);
is($txnobj->Created,'2005-08-05 20:00:56');
is($txnobj->CreatedObj->ISO,'2005-08-05 20:00:56');

$tix->FromSQL(qq{Updated = "2005-08-05" AND Subject = "$SUBJECT"});
is( $tix->Count, 1);

