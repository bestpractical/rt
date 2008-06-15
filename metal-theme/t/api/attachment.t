
use strict;
use warnings;
use Test::More; 
plan tests => 4;
use RT;
use RT::Test;


{

ok (require RT::Attachment);


}

{

my $test1 = "From: jesse";
my @headers = RT::Attachment->_SplitHeaders($test1);
is ($#headers, 0, $test1 );

my $test2 = qq{From: jesse
To: bobby
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test2);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


my $test3 = qq{From: jesse
To: bobby,
 Suzie,
    Sally,
    Joey: bizzy,
Subject: foo
};

@headers = RT::Attachment->_SplitHeaders($test3);
is ($#headers, 2, "testing a bunch of singline multiple headers" );



}

1;
