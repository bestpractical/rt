#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 32;
use Encode;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

use utf8;

use File::Spec;

diag 'test without attachments' if $ENV{TEST_VERBOSE};

{
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->form_name('TicketModify');
    $m->submit_form(
        form_number => 3,
        fields      => { Subject => '标题', Content => '测试' },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->follow_link_ok( { text => 'with headers' },
        '-> /Ticket/Attachment/WithHeaders/...' );
    $m->content_contains( '标题', 'has subject 标题' );
    $m->content_contains( '测试', 'has content 测试' );

    my ( $id ) = $m->uri =~ /(\d+)$/;
    ok( $id, 'found attachment id' );
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");
    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_contains( '标题', 'has subject 标题' );
    $m->content_contains( '测试', 'has content 测试' );
}

diag 'test with attachemnts' if $ENV{TEST_VERBOSE};

{

    my $file =
      File::Spec->catfile( RT::Test->temp_directory, encode_utf8 '附件.txt' );
    open( my $fh, '>', $file ) or die $!;
    binmode $fh, ':utf8';
    print $fh '附件';
    close $fh;

    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->form_name('TicketModify');
    $m->submit_form(
        form_number => 3,
        fields => { Subject => '标题', Content => '测试', Attach => $file },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->content_contains( '附件.txt', 'attached filename' );
    $m->content_lacks( encode_utf8 '附件.txt', 'no double encoded attached filename' );
    $m->follow_link_ok( { text => 'with headers' },
        '-> /Ticket/Attachment/WithHeaders/...' );

    # subject is in the parent attachment, so there is no 标题
    $m->content_lacks( '标题', 'does not have content 标题' );
    $m->content_contains( '测试', 'has content 测试' );

    my ( $id ) = $m->uri =~ /(\d+)$/;
    ok( $id, 'found attachment id' );
    my $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");
    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_lacks( '标题', 'does not have content 标题' );
    $m->content_contains( '测试', 'has content 测试' );


    $m->back;
    $m->back;
    $m->follow_link_ok( { text => 'Download 附件.txt' },
        '-> /Ticket/Attachment/...' );
    $m->content_contains( '附件', 'has content 附件' );

    ( $id ) = $m->uri =~ /(\d+)\D+$/;
    ok( $id, 'found attachment id' );
    $attachment = RT::Attachment->new( $RT::SystemUser );
    ok($attachment->Load($id), "load att $id");

    # let make original encoding to gbk
    ok( $attachment->SetHeader( 'X-RT-Original-Encoding' => 'gbk' ),
        'set original encoding to gbk' );
    $m->get( $m->uri );
    $m->content_contains( '附件', 'has content 附件' );

    unlink $file;
}

