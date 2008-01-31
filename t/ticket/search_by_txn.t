#!/usr/bin/perl

use warnings;
use strict;

use RT::Test; use Test::More tests => 10;

BEGIN{ $ENV{'TZ'} = 'GMT'};



my $SUBJECT = "Search test - ".$$;

use_ok('RT::Model::TicketCollection');
my $tix = RT::Model::TicketCollection->new(current_user => RT->system_user);
can_ok($tix, 'from_sql');
$tix->from_sql('Updated = "2005-08-05" AND subject = "$SUBJECT"');

ok(! $tix->count, "Searching for tickets updated on a random date finds nothing" . $tix->count);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->create(queue => 'General', subject => $SUBJECT);
ok ($ticket->id, "We Created a ticket");
my ($id, $txnid, $txnobj) =  $ticket->comment( Content => 'A comment that happend on 2004-01-01');

isa_ok($txnobj, 'RT::Model::Transaction');

ok($txnobj->created_obj->iso);
my ( $sid,$smsg) = $txnobj->__set(column => 'created', value => '2005-08-05 20:00:56');
ok($sid,$smsg);
is($txnobj->created,'2005-08-05 20:00:56');
is($txnobj->created_obj->iso,'2005-08-05 20:00:56');

$tix->from_sql(qq{Updated = "2005-08-05" AND subject = "$SUBJECT"});
is( $tix->count, 1);

