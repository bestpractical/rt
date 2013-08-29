use strict;
use warnings;

use RT::Test tests => undef;

diag "specials (, and ;) in MIME encoded-words aren't treated as specials";
{
    # RT decodes too early in the game (i.e. before parsing), so it needs to
    # ensure special characters in encoded words are properly escaped/quoted
    # after decoding

    RT->Config->Set( ParseNewMessageForTicketCcs => 1 );
    my $mail = <<'.';
From: root@localhost
Subject: testing mime encoded specials
Cc: a@example.com, =?utf8?q?d=40example.com=2ce=40example.com=3b?=
    <b@example.com>, c@example.com
Content-Type: text/plain; charset=utf8

here's some content
.

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    ok $ticket->id, 'loaded ticket';

    my @cc = @{$ticket->Cc->UserMembersObj->ItemsArrayRef};
    is scalar @cc, 3, "three ccs";
    for my $addr (qw(a b c)) {
        ok( (scalar grep { $_->EmailAddress eq "$addr\@example.com" } @cc),
            "found $addr" );
    }
}

done_testing;

