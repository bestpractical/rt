
use strict;
use warnings;
use RT::Test tests => 11;
use RT;



{

my $s = RT::System->new(current_user => RT->system_user);
my $Rights = $s->available_rights;
ok ($Rights, "Rights defined");
ok ($Rights->{'AdminUsers'},"AdminUsers right found");
ok ($Rights->{'CreateTicket'},"CreateTicket right found");
ok ($Rights->{'AdminGroupMembership'},"ModifyGroupMembers right found");
ok (!$Rights->{'CasdasdsreateTicket'},"bogus Right not found");




}

{

use RT::System;
my $sys = RT::System->new();
is( $sys->id, 1);
is ($sys->id, 1);


}

{


is (RT->nobody->name() , 'Nobody', "Nobody is nobody");
isnt (RT->nobody->name() , 'root', "Nobody isn't named root");
is (RT->system_user->name() , 'RT_System', "The system user is RT_System");
isnt (RT->system_user->name() , 'noname', "The system user isn't noname");

}

1;
