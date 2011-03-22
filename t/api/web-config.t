use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => 89;

sub no_warnings_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $option = shift;
    my $value  = shift;
    my $name   = shift;

    is(warnings_from($option => $value), 0, $name);
}

sub one_warning_like {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $option = shift;
    my $value  = shift;
    my $regex  = shift;
    my $name   = shift;

    my @w = warnings_from($option => $value);
    is(@w, 1);
    like($w[0], $regex, $name);
}


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
no_warnings_ok(WebPath => '');
no_warnings_ok(WebPath => '/foo');
no_warnings_ok(WebPath => '/foo/bar');

one_warning_like(WebPath => '/foo/', qr/The WebPath config option requires no trailing slash/);

one_warning_like(WebPath => 'foo', qr/The WebPath config option requires a leading slash/);

my @w = warnings_from(WebPath => 'foo/');
is(@w, 2);
like($w[0], qr/The WebPath config option requires no trailing slash/);
like($w[1], qr/The WebPath config option requires a leading slash/);

one_warning_like(WebPath => '/foo/bar/', qr/The WebPath config option requires no trailing slash/);

one_warning_like(WebPath => 'foo/bar', qr/The WebPath config option requires a leading slash/);

@w = warnings_from(WebPath => 'foo/bar/');
is(@w, 2);
like($w[0], qr/The WebPath config option requires no trailing slash/);
like($w[1], qr/The WebPath config option requires a leading slash/);

one_warning_like(WebPath => '/', qr{For the WebPath config option, use the empty string instead of /});

# reinstate a valid WebPath for other tests
no_warnings_ok(WebPath => '/rt');

# WebDomain
no_warnings_ok(WebDomain => 'example.com');
no_warnings_ok(WebDomain => 'rt.example.com');
no_warnings_ok(WebDomain => 'localhost');

one_warning_like(WebDomain => '', qr{You must set the WebDomain config option});

one_warning_like(WebDomain => 'http://rt.example.com', qr{The WebDomain config option must not contain a scheme \(http://\)});

one_warning_like(WebDomain => 'https://rt.example.com', qr{The WebDomain config option must not contain a scheme \(https://\)});

one_warning_like(WebDomain => 'rt.example.com/path', qr{The WebDomain config option must not contain a path \(/path\)});

one_warning_like(WebDomain => 'rt.example.com/path/more', qr{The WebDomain config option must not contain a path \(/path/more\)});

one_warning_like(WebDomain => 'rt.example.com:80', qr{The WebDomain config option must not contain a port \(80\)});

# reinstate a valid WebDomain for other tests
no_warnings_ok(WebDomain => 'rt.example.com');

# WebPort
no_warnings_ok(WebDomain => 80);
no_warnings_ok(WebDomain => 443);
no_warnings_ok(WebDomain => 8888);

one_warning_like(WebPort => '', qr{You must set the WebPort config option});

one_warning_like(WebPort => 3.14, qr{The WebPort config option must be an integer});

one_warning_like(WebPort => 'wha?', qr{The WebPort config option must be an integer});

# reinstate a valid WebDomain for other tests
no_warnings_ok(WebPort => 443);

# WebBaseURL
no_warnings_ok(WebBaseURL => 'http://rt.example.com');
no_warnings_ok(WebBaseURL => 'HTTP://rt.example.com', 'uppercase scheme is okay');
no_warnings_ok(WebBaseURL => 'http://rt.example.com:8888', 'nonstandard port is okay');
no_warnings_ok(WebBaseURL => 'https://rt.example.com:8888', 'nonstandard port with https is okay');

one_warning_like(WebBaseURL => '', qr{You must set the WebBaseURL config option});

one_warning_like(WebBaseURL => 'rt.example.com', qr{The WebBaseURL config option must contain a scheme});

one_warning_like(WebBaseURL => 'xtp://rt.example.com', qr{The WebBaseURL config option must contain a scheme \(http or https\)});

one_warning_like(WebBaseURL => 'http://rt.example.com/', qr{The WebBaseURL config option requires no trailing slash});

one_warning_like(WebBaseURL => 'http://rt.example.com/rt', qr{The WebBaseURL config option must not contain a path \(/rt\)});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt/');
is(@w, 2);
like($w[0], qr{The WebBaseURL config option requires no trailing slash});
like($w[1], qr{The WebBaseURL config option must not contain a path \(/rt/\)});

one_warning_like(WebBaseURL => 'http://rt.example.com/rt/ir', qr{The WebBaseURL config option must not contain a path \(/rt/ir\)});

@w = warnings_from(WebBaseURL => 'http://rt.example.com/rt/ir/');
is(@w, 2);
like($w[0], qr{The WebBaseURL config option requires no trailing slash});
like($w[1], qr{The WebBaseURL config option must not contain a path \(/rt/ir/\)});

# reinstate a valid WebBaseURL for other tests
no_warnings_ok(WebBaseURL => 'http://rt.example.com');

# WebURL
no_warnings_ok(WebURL => 'http://rt.example.com/');
no_warnings_ok(WebURL => 'HTTP://rt.example.com/', 'uppercase scheme is okay');
no_warnings_ok(WebURL => 'http://example.com/rt/');
no_warnings_ok(WebURL => 'http://example.com/rt/ir/');
no_warnings_ok(WebURL => 'http://rt.example.com:8888/', 'nonstandard port is okay');
no_warnings_ok(WebURL => 'https://rt.example.com:8888/', 'nonstandard port with https is okay');

one_warning_like(WebURL => '', qr{You must set the WebURL config option});

@w = warnings_from(WebURL => 'rt.example.com');
is(@w, 2);
like($w[0], qr{The WebURL config option must contain a scheme});
like($w[1], qr{The WebURL config option requires a trailing slash});

one_warning_like(WebURL => 'http://rt.example.com', qr{The WebURL config option requires a trailing slash});

one_warning_like(WebURL => 'xtp://example.com/rt/', qr{The WebURL config option must contain a scheme \(http or https\)});

one_warning_like(WebURL => 'http://rt.example.com/rt', qr{The WebURL config option requires a trailing slash});

one_warning_like(WebURL => 'http://rt.example.com/rt/ir', qr{The WebURL config option requires a trailing slash});

# reinstate a valid WebURL for other tests
no_warnings_ok(WebURL => 'http://rt.example.com/rt/');

