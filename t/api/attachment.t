
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 4;
use RT;



{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::Model::Attachment);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $test1 = "From: jesse";
my @headers = RT::Model::Attachment->_split_headers($test1);
is ($#headers, 0, $test1 );

my $test2 = qq{From: jesse
To: bobby
Subject: foo
};

@headers = RT::Model::Attachment->_split_headers($test2);
is ($#headers, 2, "testing a bunch of singline multiple headers" );


my $test3 = qq{From: jesse
To: bobby,
 Suzie,
    Sally,
    Joey: bizzy,
Subject: foo
};

@headers = RT::Model::Attachment->_split_headers($test3);
is ($#headers, 2, "testing a bunch of singline multiple headers" );



}

1;
