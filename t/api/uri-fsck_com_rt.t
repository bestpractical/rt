use strict;
use warnings;
use RT::Test; use Test::More tests => 8;
use RT;


use_ok("RT::URI::fsck_com_rt");
my $uri = RT::URI::fsck_com_rt->new(RT->system_user);

my $t1 = RT::Model::Ticket->new(RT->system_user);
my ($id,$trans,$msg) =$t1->create (Queue => 'general', Subject => 'Requestor test one', );
ok ($id, $msg);

ok(ref($uri));

ok (UNIVERSAL::isa($uri,"RT::URI::fsck_com_rt"), "It's an RT::URI::fsck_com_rt");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->LocalURIPrefix , 'fsck.com-rt://'.RT->Config->Get('Organization'));


my $ticket = RT::Model::Ticket->new(RT->system_user);
$ticket->load(1);
$uri = RT::URI::fsck_com_rt->new($ticket->current_user);
is($uri->LocalURIPrefix. "/ticket/1" , $uri->URIForObject($ticket));

1;
