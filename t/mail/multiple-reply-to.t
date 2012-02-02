use strict;
use warnings;

use RT::Test tests => 7;

diag "grant everybody with CreateTicket right";
{
    ok( RT::Test->set_rights(
        { Principal => 'Everyone', Right => [qw(CreateTicket)], },
        { Principal => 'Requestor', Right => [qw(ReplyToTicket)], },
    ), "Granted rights");
}

{
    my $text = <<EOF;
From: user\@example.com
Subject: test

Blah!
Foob!
EOF
    my ($status, $id) = RT::Test->send_via_mailgate($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "ticket created");

    $text = <<EOF;
From: user\@example.com
Subject: [@{[RT->Config->Get('rtname')]} #$id] test

Blah!
Foob!
EOF
    ($status, my $tid) = RT::Test->send_via_mailgate($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($tid, $id, "ticket updated");

    $text = <<EOF;
From: somebody\@example.com
Reply-To: boo\@example.com, user\@example.com
Subject: [@{[RT->Config->Get('rtname')]} #$id] test

Blah!
Foob!
EOF
    ($status, $tid) = RT::Test->send_via_mailgate($text);
    is ($status >> 8, 0, "The mail gateway exited normally");
    is ($tid, $id, "ticket updated");
}


1;
