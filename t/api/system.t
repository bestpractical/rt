
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 7;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $s = RT::System->new(RT->SystemUser);
my $rights = $s->AvailableRights;
ok ($rights, "Rights defined");
ok ($rights->{'AdminUsers'},"AdminUsers right found");
ok ($rights->{'CreateTicket'},"CreateTicket right found");
ok ($rights->{'AdminGroupMembership'},"ModifyGroupMembers right found");
ok (!$rights->{'CasdasdsreateTicket'},"bogus right not found");




    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

use RT::System;
my $sys = RT::System->new();
is( $sys->id, 1);
is ($sys->id, 1);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
