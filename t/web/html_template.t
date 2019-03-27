
use strict;
use warnings;

use RT::Test tests => undef;
my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

diag('make Autoreply template a html one and add utf8 chars')
  if $ENV{TEST_VERBOSE};

my $template = Encode::decode("UTF-8", "你好 éèà€");
my $subject  = Encode::decode("UTF-8", "标题");
my $content  = Encode::decode("UTF-8", "测试");
{
    $m->follow_link_ok( { id => 'admin-global-templates' }, '-> Templates' );
    $m->follow_link_ok( { text => 'Autoreply in HTML' },    '-> Autoreply in HTML' );

    $m->submit_form(
        form_name => 'ModifyTemplate',
        fields => {
            Content => <<EOF,
Subject: AutoReply: {\$Ticket->Subject}
Content-Type: text/html

$template
{\$Ticket->Subject}
-------------------------------------------------------------------------
{\$Transaction->Content()}

EOF
        },
    );
    $m->content_like( qr/Content updated/, 'content is changed' );
    $m->content_contains( $template, 'content is really updated' );
}

diag('create a ticket to see the autoreply mail') if $ENV{TEST_VERBOSE};

{
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->submit_form(
        form_name => 'TicketCreate',
        fields      => { Subject => $subject, Content => "<h1>$content</h1>",
        ContentType => 'text/html' },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->follow_link( text => 'Show' );
    $m->content_contains( $template, "html has $template" );
    $m->content_contains( $subject,
        "html has ticket subject $subject" );
    $m->content_contains( "&lt;h1&gt;$content&lt;/h1&gt;",
        "html has ticket html content $content" );
}

diag('test real mail outgoing') if $ENV{TEST_VERBOSE};

{

    # $mail is utf8 encoded
    my ($mail) = RT::Test->fetch_caught_mails;
    $mail = Encode::decode("UTF-8", $mail );
    my $quoted_template = MIME::QuotedPrint::encode_qp( Encode::encode( 'UTF-8', $template ), '' );
    my $quoted_subject = MIME::QuotedPrint::encode_qp( Encode::encode( 'UTF-8', $subject ), '' );
    my $quoted_content = MIME::QuotedPrint::encode_qp( Encode::encode( 'UTF-8', $content ), '' );
    like( $mail, qr/$quoted_template.*$quoted_template/s, 'mail has template content $template twice' );
    like( $mail, qr/$quoted_subject.*$quoted_subject/s,   'mail has ticket subject $sujbect twice' );
    like( $mail, qr/$quoted_content.*$quoted_content/s,   'mail has ticket content $content twice' );
    like( $mail, qr!<h1>$quoted_content</h1>!,     'mail has ticket html content <h1>$content</h1>' );
}

diag('test long line mails') if $ENV{TEST_VERBOSE};
{
    $m->get_ok( $baseurl . '/Ticket/Create.html?Queue=1' );

    $m->submit_form(
        form_name => 'TicketCreate',
        fields    => {
            Subject     => $subject,
            Content     => 'a' x 1000,
            ContentType => 'text/html',
        },
    );
    $m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
    $m->follow_link( text => 'Show' );
    $m->content_contains( $template, "html has $template" );
    $m->content_contains( $subject,  "html has ticket subject $subject" );
    $m->text_contains( 'a' x 1000, "html has 1000 continuous a" );
    my ($mail) = RT::Test->fetch_caught_mails;
    ok( $mail =~ /Content-Transfer-Encoding: quoted-printable/, 'mail is quoted-printable encoded' );
    ok( $mail !~ /a{1000}/,                                     'mail lacks 1000 continuous a' );
}

done_testing;
