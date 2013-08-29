use strict;
use warnings;

use RT::Test tests => 4, config => q{Set($CorrespondAddress, 'rt@example.com');};
use RT::Test::Email;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my $user  = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com' );
$queue->AddWatcher( Type => 'AdminCc', PrincipalId => $user->PrincipalObj->Id );

my $text = <<EOF;
Subject: Badly handled multipart email
From: root\@localhost
To: rt\@@{[RT->Config->Get('rtname')]}
Content-Type: multipart/alternative; boundary=20cf3071cac0cb9772049eb22371

--20cf3071cac0cb9772049eb22371
Content-Type: text/plain; charset=ISO-8859-1

Hi

--20cf3071cac0cb9772049eb22371
Content-Type: text/html; charset=ISO-8859-1
Content-Transfer-Encoding: quoted-printable

<div>Hi</div>

--20cf3071cac0cb9772049eb22371--
EOF

my ( $status, $id ) = RT::Test->send_via_mailgate($text);
is( $status >> 8, 0, "The mail gateway exited normally" );
ok( $id, "Created ticket" );

my @msgs = RT::Test->fetch_caught_mails;
is(@msgs,2,"sent 2 emails");
diag("We're skipping any testing of the autoreply");

my $entity = parse_mail($msgs[1]);
is($entity->parts, 2, "only two parts");
