use strict;
use warnings;
use RT::Test; use Test::More tests => 6;
use RT;


my $t1 = RT::Model::Ticket->new($RT::SystemUser);
my ($id,$trans,$msg) =$t1->create (Queue => 'general', Subject => 'Requestor test one', );
ok ($id, $msg);

use_ok("RT::URI::t");
my $uri = RT::URI::t->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $uristr = "t:1";
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::Model::Ticket", "Object loaded is a ticket");
is($uri->Object->id, 1, "Object loaded has correct ID");
is($uri->URI, 'fsck.com-rt://'.RT->Config->Get('Organization').'/ticket/1',
   "URI object has correct URI string");

1;
