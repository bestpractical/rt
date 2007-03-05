
use Test::More qw/no_plan/;
use RT;
RT::LoadConfig();
RT::Init();

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use_ok("RT::URI::t");
my $uri = RT::URI::t->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $uristr = "t:1";
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::Ticket", "Object loaded is a ticket");
is($uri->Object->Id, 1, "Object loaded has correct ID");
is($uri->URI, 'fsck.com-rt://'.RT->Config->Get('Organization').'/ticket/1',
   "URI object has correct URI string");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
