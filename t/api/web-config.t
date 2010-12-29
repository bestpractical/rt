use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 24;

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

# WebPath
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

# reinstate a valid WebPath for other tests
is(warnings_from(WebPath => '/rt'), 0);

# WebDomain
is(warnings_from(WebDomain => 'example.com'), 0);
is(warnings_from(WebDomain => 'rt.example.com'), 0);
is(warnings_from(WebDomain => 'localhost'), 0);

@w = warnings_from(WebDomain => '');
is(@w, 1);
like($w[0], qr{You must set the WebDomain config option});

@w = warnings_from(WebDomain => 'http://rt.example.com');
is(@w, 1);
like($w[0], qr{The WebDomain config option must not contain a scheme \(http://\)});

@w = warnings_from(WebDomain => 'https://rt.example.com');
is(@w, 1);
like($w[0], qr{The WebDomain config option must not contain a scheme \(https://\)});

@w = warnings_from(WebDomain => 'rt.example.com/path');
is(@w, 1);
like($w[0], qr{The WebDomain config option must not contain a path \(/path\)});

# reinstate a valid WebDomain for other tests
is(warnings_from(WebDomain => 'rt.example.com'), 0);

