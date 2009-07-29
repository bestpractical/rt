
use strict;
use warnings;
use RT;
use RT::Test tests => 5;


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
