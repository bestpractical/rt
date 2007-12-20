
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



{

my $s = RT::System->new(current_user => RT->system_user);
my $rights = $s->AvailableRights;
ok ($rights, "Rights defined");
ok ($rights->{'AdminUsers'},"AdminUsers right found");
ok ($rights->{'CreateTicket'},"CreateTicket right found");
ok ($rights->{'AdminGroupMembership'},"ModifyGroupMembers right found");
ok (!$rights->{'CasdasdsreateTicket'},"bogus right not found");




}

{

use RT::System;
my $sys = RT::System->new();
is( $sys->id, 1);
is ($sys->id, 1);


}

1;
