
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 4;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

is ($RT::Nobody->Name() , 'Nobody', "Nobody is nobody");
isnt ($RT::Nobody->Name() , 'root', "Nobody isn't named root");
is ($RT::SystemUser->Name() , 'RT_System', "The system user is RT_System");
isnt ($RT::SystemUser->Name() , 'noname', "The system user isn't noname");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
