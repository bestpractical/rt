use strict;
use warnings;

use RT::Test tests => 12;
use Test::Warn;

my ($baseurl, $m) = RT::Test->started_ok;

diag "Testing non-ASCII in From: header";
SKIP:{
    skip "Test requires Email::Address 1.893 or later, "
      . "you have $Email::Address::VERSION", 3,
      if $Email::Address::VERSION < 1.893;

    my $mail = Encode::encode( 'iso-8859-1', Encode::decode( "UTF-8", <<'.') );
From: René@example.com>
Reply-To: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Subject: testing non-ASCII From
Content-Type: text/plain; charset=iso-8859-1

here's some content
.

    my ($status, $id);
    warnings_like { ( $status, $id ) = RT::Test->send_via_mailgate($mail) }
        [qr/Failed to parse Reply-To:.*, From:/,
         qr/Couldn't parse or find sender's address/
        ],
        'Got parse error for non-ASCII in From';
    is( $status >> 8, 0, "The mail gateway exited normally" );
    TODO: {
          local $TODO = "Currently don't handle non-ASCII for sender";
          ok( $id, "Created ticket" );
      }
}

diag "Testing iso-8859-1 encoded non-ASCII in From: header";
SKIP:{
    skip "Test requires Email::Address 1.893 or later, "
      . "you have $Email::Address::VERSION", 3,
      if $Email::Address::VERSION < 1.893;

    my $mail = Encode::encode( 'iso-8859-1', Encode::decode( "UTF-8", <<'.' ) );
From: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Reply-To: =?iso-8859-1?Q?Ren=E9?= <René@example.com>
Subject: testing non-ASCII From
Content-Type: text/plain; charset=iso-8859-1

here's some content
.

    my ($status, $id);
    warnings_like { ( $status, $id ) = RT::Test->send_via_mailgate($mail) }
        [qr/Failed to parse Reply-To:.*, From:/,
         qr/Couldn't parse or find sender's address/
        ],
        'Got parse error for iso-8859-1 in From';
    is( $status >> 8, 0, "The mail gateway exited normally" );
    TODO: {
          local $TODO = "Currently don't handle non-ASCII in sender";
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
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( !$id, "No ticket created" );
}
