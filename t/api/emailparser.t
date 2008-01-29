
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 4;
use RT;



{

ok(require RT::EmailParser);


}

{

is(RT::EmailParser::is_rt_address("","rt\@example.com"),1, "Regexp matched rt address" );
is(RT::EmailParser::is_rt_address("","frt\@example.com"),undef, "Regexp didn't match non-rt address" );


}

{

my @before = ("rt\@example.com", "frt\@example.com");
my @after = ("frt\@example.com");
ok(eq_array(RT::EmailParser::cull_rt_addresses("",@before),@after), "cull_rt_addresses only culls RT addresses");


}

1;
