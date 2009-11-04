use strict;
use warnings;
use RT::Test; use Test::More tests => 14;
use RT;

{
use_ok("RT::URI::fsck_com_rt");
my $uri = RT::URI::fsck_com_rt->new(current_user => RT->system_user);

my $t1 = RT::Model::Ticket->new(current_user => RT->system_user);
my ($id,$trans,$msg) =$t1->create (queue => 'general', subject => 'Requestor test one', );
ok ($id, $msg);

ok(ref($uri));

ok (UNIVERSAL::isa($uri,"RT::URI::fsck_com_rt"), "It's an RT::URI::fsck_com_rt");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->local_uri_prefix , 'fsck.com-rt://'.RT->config->get('organization'));


my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
$ticket->load(1);
$uri = RT::URI::fsck_com_rt->new(current_user => $ticket->current_user);
is($uri->local_uri_prefix. "/ticket/1" , $uri->uri_for_object($ticket));

}

{

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
is($uri->uri, 'fsck.com-rt://'.RT->config->get('organization').'/ticket/1',
   "URI object has correct URI string");

}

1;
