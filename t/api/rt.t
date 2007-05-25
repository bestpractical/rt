
use strict;
use warnings;
use Test::More; 
plan tests => 4;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok ($RT::Nobody->Name() eq 'Nobody', "Nobody is nobody");
ok ($RT::Nobody->Name() ne 'root', "Nobody isn't named root");
ok ($RT::SystemUser->Name() eq 'RT_System', "The system user is RT_System");
ok ($RT::SystemUser->Name() ne 'noname', "The system user isn't noname");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
