
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 4;
use RT;



{

is ($RT::Nobody->name() , 'Nobody', "Nobody is nobody");
isnt ($RT::Nobody->name() , 'root', "Nobody isn't named root");
is (RT->system_user->name() , 'RT_System', "The system user is RT_System");
isnt (RT->system_user->name() , 'noname', "The system user isn't noname");


}

1;
