use strict;
use warnings;
use RT;
use RT::Test tests => 8;

use_ok("RT::URI::fsck_com_rt");
my $uri = RT::URI::fsck_com_rt->new(RT->SystemUser);

my $t1 = RT::Ticket->new(RT->SystemUser);
my ($id,$trans,$msg) =$t1->Create (Queue => 'general', Subject => 'Requestor test one', );
ok ($id, $msg);

ok(ref($uri));

ok (UNIVERSAL::isa($uri,"RT::URI::fsck_com_rt"), "It's an RT::URI::fsck_com_rt");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->LocalURIPrefix , 'fsck.com-rt://'.RT->Config->Get('Organization'));


my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Load(1);
$uri = RT::URI::fsck_com_rt->new($ticket->CurrentUser);
is($uri->LocalURIPrefix. "/ticket/1" , $uri->URIForObject($ticket));

