
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 5;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;


use RT::Model::Link;
my $link = RT::Model::Link->new($RT::SystemUser);


ok (ref $link);
ok (UNIVERSAL::isa($link, 'RT::Model::Link'));
ok (UNIVERSAL::isa($link, 'RT::Base'));
ok (UNIVERSAL::isa($link, 'RT::Record'));
ok (UNIVERSAL::isa($link, 'Jifty::DBI::Record'));


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
