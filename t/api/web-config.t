use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 65;

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
is(warnings_from(WebPath => '/foo/bar'), 0);

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

@w = warnings_from(WebPath => '/foo/bar/');
is(@w, 1);
like($w[0], qr/The WebPath config option requires no trailing slash/);

@w = warnings_from(WebPath => 'foo/bar');
is(@w, 1);
like($w[0], qr/The WebPath config option requires a leading slash/);

@w = warnings_from(WebPath => 'foo/bar/');
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

@w = warnings_from(WebDomain => 'rt.example.com/path/more');
is(@w, 1);
like($w[0], qr{The WebDomain config option must not contain a path \(/path/more\)});

# reinstate a valid WebDomain for other tests
is(warnings_from(WebDomain => 'rt.example.com'), 0);

# WebPort
is(warnings_from(WebDomain => 80), 0);
is(warnings_from(WebDomain => 443), 0);
is(warnings_from(WebDomain => 8888), 0);

@w = warnings_from(WebPort => '');
is(@w, 1);
like($w[0], qr{You must set the WebPort config option});

@w = warnings_from(WebPort => 3.14);
is(@w, 1);
like($w[0], qr{The WebPort config option must be an integer});

@w = warnings_from(WebPort => 'wha?');
is(@w, 1);
like($w[0], qr{The WebPort config option must be an integer});

# reinstate a valid WebDomain for other tests
is(warnings_from(WebPort => 443), 0);

# WebBaseURL
is(warnings_from(WebBaseURL => 'http://rt.example.com'), 0);
is(warnings_from(WebBaseURL => 'xtp://rt.example.com'), 0, 'nonstandard schema is okay?');
is(warnings_from(WebBaseURL => 'http://rt.example.com:8888'), 0, 'nonstandard port is okay');
is(warnings_from(WebBaseURL => 'https://rt.example.com:8888'), 0, 'nonstandard port with https is okay');

@w = warnings_from(WebBaseURL => '');
is(@w, 1);
like($w[0], qr{You must set the WebBaseURL config option});

@w = warnings_from(WebBaseURL => 'rt.example.com');
is(@w, 1);
like($w[0], qr{The WebBaseURL config option must contain a scheme});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/');
is(@w, 1);
like($w[0], qr{The WebBaseURL config option requires no trailing slash});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt');
is(@w, 1);
like($w[0], qr{The WebBaseURL config option must not contain a path \(/rt\)});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt/');
is(@w, 2);
like($w[0], qr{The WebBaseURL config option requires no trailing slash});
like($w[1], qr{The WebBaseURL config option must not contain a path \(/rt/\)});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt/ir');
is(@w, 1);
like($w[0], qr{The WebBaseURL config option must not contain a path \(/rt/ir\)});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt/ir/');
is(@w, 2);
like($w[0], qr{The WebBaseURL config option requires no trailing slash});
like($w[1], qr{The WebBaseURL config option must not contain a path \(/rt/ir/\)});

# reinstate a valid WebBaseURL for other tests
is(warnings_from(WebBaseURL => 'http://rt.example.com'), 0);

