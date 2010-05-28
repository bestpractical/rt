#!/usr/bin/perl -w
use strict;

use RT::Test tests => 37;
use File::Temp 'tempfile';
use File::Spec;
my ( $plain_fh, $plain_file ) =
  tempfile( 'rttestXXXXXX', SUFFIX => '.txt', UNLINK => 1, TMPDIR => 1 );
print $plain_fh "this is plain content";
close $plain_fh;
my $plain_name = (File::Spec->splitpath($plain_file))[-1];

my ( $html_fh, $html_file ) =
  tempfile( 'rttestXXXXXX', SUFFIX => '.html', UNLINK => 1, TMPDIR => 1 );
print $html_fh "this is html content";
close $html_fh;
my $html_name = (File::Spec->splitpath($html_file))[-1];

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Queue->new($RT::Nobody);
my $qid = $queue->Load('General');
ok( $qid, "Loaded General queue" );

RT::Test->set_mail_catcher;
RT::Test->clean_caught_mails;

for my $type ( 'text/plain', 'text/html' ) {
    $m->form_name('CreateTicketInQueue');
    $m->field( 'Queue', $qid );
    $m->submit;
    is( $m->status, 200, "request successful" );
    $m->content_like( qr/Create a new ticket/, 'ticket create page' );

    $m->form_name('TicketCreate');
    $m->field( 'Subject', 'with plain attachment' );
    $m->field( 'Attach',  $plain_file );
    $m->field( 'Content', 'this is main content' );
    $m->field( 'ContentType', $type ) unless $type eq 'text/plain';
    $m->submit;
    is( $m->status, 200, "request successful" );
    $m->content_like( qr/with plain attachment/,
        'we have subject on the page' );
    $m->content_like( qr/this is main content/, 'main content' );
    $m->content_like( qr/Download $plain_name/, 'download plain file link' );

    my ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main content/, 'email contains main content' );
    # check the email link in page too
    $m->follow_link_ok( { text => 'Show' }, 'show the email outgoing' );
    $m->content_like( qr/this is main content/, 'email contains main content');
    $m->back;

    $m->follow_link_ok( { text => 'Reply' }, "reply to the ticket" );
    $m->form_name('TicketUpdate');
    $m->field( 'Attach', $plain_file );
    $m->click('AddMoreAttach');
    is( $m->status, 200, "request successful" );

    $m->form_name('TicketUpdate');
    $m->field( 'Attach',        $html_file );
    # add UpdateCc so we can get email record
    $m->field( 'UpdateCc',      'rt-test@example.com' );
    $m->field( 'UpdateContent', 'this is main reply content' );
    $m->field( 'UpdateContentType', $type ) unless $type eq 'text/plain';
    $m->click('SubmitTicket');
    is( $m->status, 200, "request successful" );

    $m->content_like( qr/this is main reply content/, 'main reply content' );
    $m->content_like( qr/Download $html_name/, 'download html file link' );

    ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main reply content/, 'email contains main reply content' );
    # check the email link in page too
    $m->follow_link_ok( { text => 'Show', n => 2 }, 'show the email outgoing' );
    $m->content_like( qr/this is main reply content/, 'email contains main reply content');
    $m->back;
}
