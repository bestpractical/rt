use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 11;

sub warnings_from {
    my $option = shift;
    my $value  = shift;

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, $_[0];
    };

    RT->Config->Set($option => $value);
    RT->Config->PostLoadCheck;

    return @warnings;
}

is(warnings_from(WebPath => ''), 0);
is(warnings_from(WebPath => '/foo'), 0);

my @w = warnings_from(WebPath => '/foo/');
is(@w, 1);
like($w[0], qr/The WebPath config option requires no trailing slash/);

@w = warnings_from(WebPath => 'foo');
is(@w, 1);
like($w[0], qr/The WebPath config option requires a leading slash/);

@w = warnings_from(WebPath => 'foo/');
is(@w, 2);
like($w[0], qr/The WebPath config option requires no trailing slash/);
like($w[1], qr/The WebPath config option requires a leading slash/);

@w = warnings_from(WebPath => '/');
is(@w, 1);
like($w[0], qr{For the WebPath config option, use the empty string instead of /});

