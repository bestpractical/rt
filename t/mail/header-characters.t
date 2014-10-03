use strict;
use warnings;

use RT::Test tests => 12;
use Test::Warn;

my ($baseurl, $m) = RT::Test->started_ok;

diag "Testing non-ASCII latin1 in From: header";
{
    my $mail = Encode::encode( 'iso-8859-1', Encode::decode( "UTF-8", <<'.') );
From: <René@example.com>
Reply-To: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Subject: testing non-ASCII From
Content-Type: text/plain; charset=iso-8859-1

here's some content
.

    my ($status, $id);
    warnings_like { ( $status, $id ) = RT::Test->send_via_mailgate($mail) }
        [(qr/Unable to parse an email address from/) x 2,
         qr/Couldn't parse or find sender's address/
        ],
        'Got parse error for non-ASCII in From';
    TODO: {
        local $TODO = "Currently don't handle non-ASCII for sender";
        is( $status >> 8, 0, "The mail gateway exited normally" );
        ok( $id, "Created ticket" );
    }
}

diag "Testing non-ASCII latin1 in From: header with MIME-word-encoded phrase";
{
    my $mail = Encode::encode( 'iso-8859-1', Encode::decode( "UTF-8", <<'.') );
From: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Reply-To: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Subject: testing non-ASCII From
Content-Type: text/plain; charset=iso-8859-1

here's some content
.

    my ($status, $id);
    warnings_like { ( $status, $id ) = RT::Test->send_via_mailgate($mail) }
        [(qr/Unable to parse an email address from/) x 2,
         qr/Couldn't parse or find sender's address/
        ],
        'Got parse error for iso-8859-1 in From';
    TODO: {
        local $TODO = "Currently don't handle non-ASCII in sender";
        is( $status >> 8, 0, "The mail gateway exited normally" );
        ok( $id, "Created ticket" );
      }
}

diag "No sender";
{
    my $mail = <<'.';
To: rt@example.com
Subject: testing non-ASCII From
Content-Type: text/plain; charset=iso-8859-1

here's some content
.

    my ($status, $id);
    warnings_like { ( $status, $id ) = RT::Test->send_via_mailgate($mail) }
        [qr/Couldn't parse or find sender's address/],
        'Got parse error with no sender fields';
    is( $status >> 8, 1, "The mail gateway failed" );
    ok( !$id, "No ticket created" );
}
