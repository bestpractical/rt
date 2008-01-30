
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



{

my $s = RT::System->new(current_user => RT->system_user);
my $Rights = $s->available_rights;
ok ($Rights, "Rights defined");
ok ($Rights->{'AdminUsers'},"AdminUsers right found");
ok ($Rights->{'create_ticket'},"create_ticket right found");
ok ($Rights->{'AdminGroupMembership'},"ModifyGroupMembers right found");
ok (!$Rights->{'CasdasdsreateTicket'},"bogus Right not found");




}

{

use RT::System;
my $sys = RT::System->new();
is( $sys->id, 1);
is ($sys->id, 1);


}

1;
