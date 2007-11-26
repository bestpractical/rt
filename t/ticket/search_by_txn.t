#!/usr/bin/perl

use warnings;
use strict;

use RT::Test; use Test::More tests => 10;

BEGIN{ $ENV{'TZ'} = 'GMT'};



my $SUBJECT = "Search test - ".$$;

use_ok('RT::Model::TicketCollection');
my $tix = RT::Model::TicketCollection->new(RT->system_user);
can_ok($tix, 'from_sql');
$tix->from_sql('Updated = "2005-08-05" AND Subject = "$SUBJECT"');

ok(! $tix->count, "Searching for tickets updated on a random date finds nothing" . $tix->count);

my $ticket = RT::Model::Ticket->new(RT->system_user);
$ticket->create(Queue => 'General', Subject => $SUBJECT);
ok ($ticket->id, "We Created a ticket");
my ($id, $txnid, $txnobj) =  $ticket->Comment( Content => 'A comment that happend on 2004-01-01');

isa_ok($txnobj, 'RT::Model::Transaction');

ok($txnobj->CreatedObj->ISO);
my ( $sid,$smsg) = $txnobj->__set(column => 'Created', value => '2005-08-05 20:00:56');
ok($sid,$smsg);
is($txnobj->Created,'2005-08-05 20:00:56');
is($txnobj->CreatedObj->ISO,'2005-08-05 20:00:56');

$tix->from_sql(qq{Updated = "2005-08-05" AND Subject = "$SUBJECT"});
is( $tix->count, 1);

