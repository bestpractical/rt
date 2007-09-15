
use strict;
use warnings;
use Test::More; 
plan tests => 5;
use RT;
use RT::Test;


{


use RT::Link;
my $link = RT::Link->new($RT::SystemUser);


ok (ref $link);
ok (UNIVERSAL::isa($link, 'RT::Link'));
ok (UNIVERSAL::isa($link, 'RT::Base'));
ok (UNIVERSAL::isa($link, 'RT::Record'));
ok (UNIVERSAL::isa($link, 'DBIx::SearchBuilder::Record'));


}

1;
