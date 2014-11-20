use warnings;
use strict;

use RT::Test nodata => 1, tests => undef;
use RT::I18N;
use Test::Warn;

diag "normal mime encoding conversion: utf8 => iso-8859-1";
{
    my $mime = MIME::Entity->build(
        Type => 'text/plain; charset=utf-8',
        Data => ['À中文'],
    );

    warning_like {
        RT::I18N::SetMIMEEntityToEncoding( $mime, 'iso-8859-1', );
    }
    [ qr/does not map to iso-8859-1/ ], 'got one "not map" error';
    is( $mime->stringify_body, 'À中文', 'body is not changed' );
    is( $mime->head->mime_attr('Content-Type'), 'application/octet-stream' );
}

diag "mime encoding conversion: utf8 => iso-8859-1";
{
    my $mime = MIME::Entity->build(
        Type => 'text/plain; charset=utf-8',
        Data => ['À中文'],
    );
    is( $mime->stringify_body, 'À中文', 'body is not changed' );
}

done_testing;
