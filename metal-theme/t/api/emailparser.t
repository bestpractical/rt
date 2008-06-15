
use strict;
use warnings;
use Test::More; 
plan tests => 4;
use RT;
use RT::Test;


{

ok(require RT::EmailParser);


}

{

is(RT::EmailParser::IsRTAddress("","rt\@example.com"),1, "Regexp matched rt address" );
is(RT::EmailParser::IsRTAddress("","frt\@example.com"),undef, "Regexp didn't match non-rt address" );


}

{

my @before = ("rt\@example.com", "frt\@example.com");
my @after = ("frt\@example.com");
ok(eq_array(RT::EmailParser::CullRTAddresses("",@before),@after), "CullRTAddresses only culls RT addresses");


}

1;
