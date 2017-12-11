
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
    like( $mail, qr/$template.*$template/s, 'mail has template content $template twice' );
    like( $mail, qr/$subject.*$subject/s,   'mail has ticket subject $sujbect twice' );
    like( $mail, qr/$content.*$content/s,   'mail has ticket content $content twice' );
    like( $mail, qr!<h1>$content</h1>!,     'mail has ticket html content <h1>$content</h1>' );
}

done_testing;
