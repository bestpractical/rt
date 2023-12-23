use strict;
use warnings;

use RT::Test tests => undef;

use MIME::Entity;

diag "simple rfc822 attachment";
{

    my $top = MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'this is top',
        Data    => ['top mail'],
    );

    my $rfc822 = MIME::Entity->build(
        From    => 'foo@localhost',
        To      => 'bar@localhost',
        Subject => 'rfc822',
        Data    => ['rfc822 attachment 测试'],
        Charset => 'UTF-8',
        'X-Brokenness' => 'high',
    );

    $top->attach(
        Data => $rfc822->stringify,
        Type => 'message/rfc822',
        Charset => 'UTF-8',
    );

    for my $mime ( $top, contents_as_mime($top) ) {
        diag "testing mail";
        is $mime->parts, 2, 'two mime parts';

        eval { $mime->as_string };
        ok( !$@, 'stringifying mime does not die' );

        like $mime->head->get('Subject'), qr/this is top/, 'top subject';
        like $mime->head->get('From'), qr/root\@localhost/, 'top From';
        like $mime->parts(0)->bodyhandle->as_string, qr/top mail/, 'content of top';
        
        my $attach = $mime->parts(1);
        my $body   = $attach->bodyhandle->as_string;

        like $attach->head->mime_type, qr/message\/rfc822/, 'attach of type message/rfc822';
        like $body, qr/rfc822 attachment 测试/, 'attach content';

        headers_like(
            $attach,
            Subject         => 'rfc822',
            From            => 'foo@localhost',
            'X-Brokenness'  => 'high',
        );
    }
}

diag "multipart rfc822 attachment";
{

    my $top = MIME::Entity->build(
        From    => 'root@localhost',
        To      => 'rt@localhost',
        Subject => 'this is top',
        Data    => ['top mail'],
    );

    my $rfc822 = MIME::Entity->build(
        From    => 'foo@localhost',
        To      => 'bar@localhost',
        Subject => 'rfc822',
        Data    => ['rfc822 attachment 测试附件'],
        Charset => 'UTF-8',
        'X-Brokenness' => 'high',
    );

    $rfc822->attach(
        Data => ['<b>attachment of rfc822 attachment 测试</b>'],
        Type => 'text/html',
        Charset  => 'UTF-8',
    );

    $top->attach(
        Data => $rfc822->stringify,
        Type => 'message/rfc822',
        Charset => 'UTF-8',
    );

    for my $mime ( $top, contents_as_mime($top) ) {
        diag "testing mail";
        is $mime->parts, 2, 'two mime parts';
        eval { $mime->as_string };
        ok( !$@, 'stringifying mime does not die' );

        like $mime->head->get('Subject'), qr/this is top/, 'top subject';
        like $mime->head->get('From'), qr/root\@localhost/, 'top From';
        like $mime->parts(0)->bodyhandle->as_string, qr/top mail/, 'content of top';
        
        my $attach = $mime->parts(1);
        my $body   = $attach->bodyhandle->as_string;

        like $attach->head->mime_type, qr/message\/rfc822/, 'attach of type message/rfc822';
        like $body, qr/rfc822 attachment 测试附件/, 'attach content';

        like $body, qr/attachment of rfc822 attachment 测试/, 'attach content';

        headers_like(
            $attach,
            Subject         => 'rfc822',
            From            => 'foo@localhost',
            'X-Brokenness'  => 'high',
            'Content-Type'  => 'text/plain',
            'Content-type'  => 'text/html',
        );
    }
}

sub content_as_mime {
    my $entity = shift;
    my ( $status, $id ) = RT::Test->send_via_mailgate($entity);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "created ticket" );
    # We can't simply use Txn->ContentAsMIME since that is wrapped in a
    # message/rfc822 entity
    return RT::Test->last_ticket->Transactions->First->Attachments->First->ContentAsMIME(Children => 1);
}

sub contents_as_mime {
    my $entity = shift;
    RT->Config->Set( 'TreatAttachedEmailAsFiles', 1 );
    my @contents = content_as_mime($entity);
    RT->Config->Set( 'TreatAttachedEmailAsFiles', 0 );
    push @contents, content_as_mime($entity);
    return @contents;
}

sub headers_like {
    my $attach = shift;
    my %header = (@_);
    my $body   = $attach->bodyhandle->as_string;
    for my $name (keys %header) {
        if (lc $name eq 'content-type') {
            like $attach->head->get($name), qr/message\/rfc822/, "attach $name message/rfc822, not from a subpart";
        } else {
            is $attach->head->get($name), undef, "attach $name not in part header";
        }
        like $body, qr/$name: $header{$name}/i, "attach $name in part body";
    }
}

done_testing;

