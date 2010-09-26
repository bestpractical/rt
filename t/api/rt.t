
use strict;
use warnings;
use RT;
use RT::Test nodata => 1, tests => 4;


{

is (RT->Nobody->Name() , 'Nobody', "Nobody is nobody");
isnt (RT->Nobody->Name() , 'root', "Nobody isn't named root");
is (RT->SystemUser->Name() , 'RT_System', "The system user is RT_System");
isnt (RT->SystemUser->Name() , 'noname', "The system user isn't noname");


}

