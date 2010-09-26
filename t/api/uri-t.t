use strict;
use warnings;
use RT;
use RT::Test tests => 6;

my $t1 = RT::Ticket->new(RT->SystemUser);
my ($id,$trans,$msg) =$t1->Create (Queue => 'general', Subject => 'Requestor test one', );
ok ($id, $msg);

use_ok("RT::URI::t");
my $uri = RT::URI::t->new(RT->SystemUser);
ok(ref($uri), "URI object exists");

my $uristr = "t:1";
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::Ticket", "Object loaded is a ticket");
is($uri->Object->Id, 1, "Object loaded has correct ID");
is($uri->URI, 'fsck.com-rt://'.RT->Config->Get('Organization').'/ticket/1',
   "URI object has correct URI string");

