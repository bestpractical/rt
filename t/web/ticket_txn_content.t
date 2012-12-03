use strict;
use warnings;

use RT::Test tests => 63;
my $plain_file = File::Spec->catfile( RT::Test->temp_directory, 'attachment.txt' );
open my $plain_fh, '>', $plain_file or die $!;
print $plain_fh "this is plain content";
close $plain_fh;
my $plain_name = (File::Spec->splitpath($plain_file))[-1];

my $html_file = File::Spec->catfile( RT::Test->temp_directory, 'attachment.html' );
open my $html_fh, '>', $html_file or die $!;
print $html_fh "this is plain content";
close $html_fh;
my $html_name = (File::Spec->splitpath($html_file))[-1];

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Queue->new(RT->Nobody);
my $qid = $queue->Load('General');
ok( $qid, "Loaded General queue" );

RT::Test->clean_caught_mails;

sub follow_parent_with_headers_link {
    my $m    = shift;
    my $link = $m->find_link(@_)->url;
    $link =~ s{/(\d+)$}{"/" . ($1-1)}e;  # get the parent attach
    $m->get_ok($link);
}

sub follow_with_headers_link {
    my $m    = shift;
    my $link = $m->find_link(@_)->url;
    $link =~ s{/\d+/(\d+)/.+$}{/WithHeaders/$1};   # frob into a with headers url
    $m->get_ok($link);
}

for my $type ( 'text/plain', 'text/html' ) {
    $m->form_name('CreateTicketInQueue');
    $m->field( 'Queue', $qid );
    $m->submit;
    is( $m->status, 200, "request successful" );
    $m->content_contains('Create a new ticket', 'ticket create page' );

    $m->form_name('TicketCreate');
    $m->field( 'Subject', 'with plain attachment' );
    $m->field( 'Attach',  $plain_file );
    $m->field( 'Content', 'this is main content' );
    $m->field( 'ContentType', $type ) unless $type eq 'text/plain';
    $m->submit;
    is( $m->status, 200, "request successful" );
    $m->content_contains('with plain attachment',
        'we have subject on the page' );
    $m->content_contains('this is main content', 'main content' );
    $m->content_contains("Download $plain_name", 'download plain file link' );

    # Check for Message-IDs
    follow_parent_with_headers_link($m, text => 'with headers', n => 1);
    $m->content_like(qr/^Message-ID:/im, 'create content has one Message-ID');
    $m->content_unlike(qr/^Message-ID:.+?Message-ID:/ism, 'but not two Message-IDs');
    $m->back;

    follow_with_headers_link($m, text => "Download $plain_name", n => 1);
    $m->content_unlike(qr/^Message-ID:/im, 'attachment lacks a Message-ID');
    $m->back;

    my ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main content/, 'email contains main content' );
    # check the email link in page too
    $m->follow_link_ok( { text => 'Show' }, 'show the email outgoing' );
    $m->content_contains('this is main content', 'email contains main content');
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

    $m->content_contains("this is main reply content", 'main reply content' );
    $m->content_contains("Download $html_name", 'download html file link' );

    # Check for Message-IDs
    follow_parent_with_headers_link($m, text => 'with headers', n => 2);
    $m->content_like(qr/^Message-ID:/im, 'correspondence has one Message-ID');
    $m->content_unlike(qr/^Message-ID:.+?Message-ID:/ism, 'but not two Message-IDs');
    $m->back;

    follow_with_headers_link($m, text => "Download $plain_name", n => 2);
    $m->content_unlike(qr/^Message-ID:/im, 'text/plain attach lacks a Message-ID');
    $m->back;

    follow_with_headers_link($m, text => "Download $html_name", n => 1);
    $m->content_unlike(qr/^Message-ID:/im, 'text/html attach lacks a Message-ID');
    $m->back;

    ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main reply content/, 'email contains main reply content' );
    # check the email link in page too
    $m->follow_link_ok( { text => 'Show', n => 2 }, 'show the email outgoing' );
    $m->content_contains("this is main reply content", 'email contains main reply content');
    $m->back;
}
