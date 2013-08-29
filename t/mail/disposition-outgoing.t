use strict;
use warnings;

use RT::Test tests => undef;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue->id, 'loaded queue';

my ($ok, $msg) = $queue->AddWatcher(
    Type    => 'AdminCc',
    Email   => 'test@example.com',
);
ok $ok, $msg;

my $mail = <<'.';
From: root@localhost
Subject: I like inline dispositions and I cannot lie
Content-type: multipart/related; boundary="foo"

--foo
Content-type: text/plain; charset="UTF-8"

ho hum just some text

--foo
Content-type: text/x-patch; name="filename.patch"
Content-disposition: inline; filename="filename.patch"

a fake patch

--foo
.

# inline
{
    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*inline.+?filename\.patch/is, 'found inline disposition';
}

# attachment
{
    $mail =~ s/(?<=Content-disposition: )inline/attachment/i;

    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*attachment.+?filename\.patch/is, 'found attachment disposition';
}

# no disposition
{
    $mail =~ s/^Content-disposition: .+?\n(?=\n)//ism;

    my $rt = send_and_receive($mail);
    like $rt, qr/Content-Disposition:\s*attachment.+?filename\.patch/is, 'found default (attachment) disposition';
}

sub send_and_receive {
    my $mail = shift;
    my ($stat, $id) = RT::Test->send_via_mailgate($mail);
    is( $stat >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "created ticket" );

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 2, "got 2 outgoing emails";

    # first is autoreply
    pop @mails;
}

done_testing;
