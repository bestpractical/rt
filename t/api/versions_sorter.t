
use RT::Test nodata => 1, tests => 3;

use strict;
use warnings;

sub is_right_sorting {
    my @order = @_;
    my @tmp = sort { int(rand(3)) - 1 } @order;

    is_deeply(
        [ sort RT::Handle::cmp_version @tmp ],
        \@order,
        'test sorting of ('. join(' ', @tmp) .')'
    );
}

is_right_sorting(qw(1 2 3));
is_right_sorting(qw(1.1 1.2 1.3 2.0 2.1));
is_right_sorting(qw(4.0.0a1 4.0.0alpha2 4.0.0b1 4.0.0beta2 4.0.0pre1 4.0.0pre2 4.0.0rc1 4.0.0rc2 4.0.0));

