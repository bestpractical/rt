use strict;
use warnings;

use RT::Test tests => 13;
use CGI::PSGI;
my $r = $HTML::Mason::Commands::r = bless {}, 'R';
my $m = $HTML::Mason::Commands::m = bless { cgi_object => CGI::PSGI->new( {} ) }, 'M';

set_config(
    CanonicalizeRedirectURLs => 0,
    WebDomain => 'localhost',
    WebPort => 80,
    WebPath => '',
);
is( RT->Config->Get('WebBaseURL'), 'http://localhost' );
is( RT->Config->Get('WebURL'), 'http://localhost/' );

redirect_ok(
    'http://localhost/Ticket/', 'http://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 80 },
);
redirect_ok(
    '/Ticket/', 'http://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 80 },
);
redirect_ok(
    'http://localhost/Ticket/', 'http://example.com/Ticket/',
    { SERVER_NAME => 'example.com', SERVER_PORT => 80 },
);

set_config(
    CanonicalizeRedirectURLs => 0,
    WebDomain => 'localhost',
    WebPort => 443,
    WebPath => '',
);
is( RT->Config->Get('WebBaseURL'), 'https://localhost' );
is( RT->Config->Get('WebURL'), 'https://localhost/' );

redirect_ok(
    'https://localhost/Ticket/', 'https://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 443, 'psgi.url_scheme' => 'https' },
);
redirect_ok(
    '/Ticket/', 'https://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 443, 'psgi.url_scheme' => 'https' },
);
redirect_ok(
    'https://localhost/Ticket/', 'http://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 80 },
);
redirect_ok(
    '/Ticket/', 'http://localhost/Ticket/',
    { SERVER_NAME => 'localhost', SERVER_PORT => 80 },
);
redirect_ok(
    'https://localhost/Ticket/', 'http://example.com/Ticket/',
    { SERVER_NAME => 'example.com', SERVER_PORT => 80 },
);
redirect_ok(
    'https://localhost/Ticket/', 'https://example.com/Ticket/',
    { SERVER_NAME => 'example.com', SERVER_PORT => 443, 'psgi.url_scheme' => 'https' },
);

sub set_config {
    my %values = @_;
    while ( my ($k, $v) = each %values ) {
        RT->Config->Set( $k => $v );
    }

    unless ( $values{'WebBaseURL'} ) {
        my $port = RT->Config->Get('WebPort');
        RT->Config->Set(
            WebBaseURL => 
                ($port == 443? 'https': 'http') .'://'
                . RT->Config->Get('WebDomain')
                . ($port != 80 && $port != 443? ":$port" : '')
        );
    }
    unless ( $values{'WebURL'} ) {
        RT->Config->Set(
            WebURL => RT->Config->Get('WebBaseURL') . RT->Config->Get('WebPath') . "/"
        );
    }
}

sub redirect_ok {
    my ($to, $expected, $env, $details) = @_;

    %{$m->cgi_object->env} = %$env;
    RT::Interface::Web::Redirect( $to );
    is($m->redirect, $expected, $details || "correct for '$to'");
}

package R;
sub status {};

package M;
sub redirect { $_[0]{'last'} = $_[1] if @_ > 1; return $_[0]{'last'} }
sub abort {}
sub cgi_object { $_[0]{'cgi_object'} }

