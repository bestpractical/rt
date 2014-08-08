
use strict;
use warnings;

use RT::Test tests => 32;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

use File::Spec;

my $subject  = Encode::decode("UTF-8",'标题');
my $content  = Encode::decode("UTF-8",'测试');
my $filename = Encode::decode("UTF-8",'附件.txt');

diag 'test without attachments' if $ENV{TEST_VERBOSE};

{
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->form_name('TicketModify');
    $m->submit_form(
        form_number => 3,
        fields      => { Subject => $subject, Content => $content },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->follow_link_ok( { text => 'with headers' },
        '-> /Ticket/Attachment/WithHeaders/...' );
    $m->content_contains( $subject, "has subject $subject" );
    $m->content_contains( $content, "has content $content" );

    my ( $id ) = $m->uri =~ /(\d+)$/;
    ok( $id, 'found attachment id' );
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");
    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_contains( $subject, "has subject $subject" );
    $m->content_contains( $content, "has content $content" );
}

diag 'test with attachemnts' if $ENV{TEST_VERBOSE};

{

    my $file =
      File::Spec->catfile( RT::Test->temp_directory, Encode::encode("UTF-8",$filename) );
    open( my $fh, '>', $file ) or die $!;
    binmode $fh, ':utf8';
    print $fh $filename;
    close $fh;

    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->form_name('TicketModify');
    $m->submit_form(
        form_number => 3,
        fields => { Subject => $subject, Content => $content, Attach => $file },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->content_contains( $filename, 'attached filename' );
    $m->content_lacks( Encode::encode("UTF-8",$filename), 'no double encoded attached filename' );
    $m->follow_link_ok( { text => 'with headers' },
        '-> /Ticket/Attachment/WithHeaders/...' );

    # subject is in the parent attachment, so there is no 标题
    $m->content_lacks( $subject, "does not have content $subject" );
    $m->content_contains( $content, "has content $content" );

    my ( $id ) = $m->uri =~ /(\d+)$/;
    ok( $id, 'found attachment id' );
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");
    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_lacks( $subject, "does not have content $subject" );
    $m->content_contains( $content, "has content $content" );


    $m->back;
    $m->back;
    $m->follow_link_ok( { text => "Download $filename" },
        '-> /Ticket/Attachment/...' );
    $m->content_contains( $filename, "has file content $filename" );

    ( $id ) = $m->uri =~ m{/(\d+)/[^/]+$};
    ok( $id, 'found attachment id' );
    $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");

    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_contains( $filename, "has content $filename" );

    unlink $file;
}

