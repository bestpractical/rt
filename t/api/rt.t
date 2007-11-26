
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 4;
use RT;



{

is ($RT::Nobody->Name() , 'Nobody', "Nobody is nobody");
isnt ($RT::Nobody->Name() , 'root', "Nobody isn't named root");
is (RT->system_user->Name() , 'RT_System', "The system user is RT_System");
isnt (RT->system_user->Name() , 'noname', "The system user isn't noname");


}

1;
