use strict;
use warnings;
use RT::Test; use Test::More tests => 6;
use RT;


my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id,$trans,$msg) =$t1->create (queue => 'general', subject => 'Requestor test one', );
ok ($id, $msg);

use_ok("RT::URI::t");
my $uri = RT::URI::t->new(current_user => RT->system_user);
ok(ref($uri), "URI object exists");

my $uristr = "t:1";
$uri->parse_uri($uristr);
is(ref($uri->object), "RT::Model::Ticket", "object loaded is a ticket");
is($uri->object->id, 1, "object loaded has correct ID");
is($uri->uri, 'fsck.com-rt://'.RT->config->get('Organization').'/ticket/1',
   "URI object has correct URI string");

1;
