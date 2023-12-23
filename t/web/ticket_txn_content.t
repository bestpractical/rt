use strict;
use warnings;

use RT::Test;
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
    $m->click('SubmitTicket');
    is( $m->status, 200, "request successful" );
    $m->content_contains('with plain attachment',
        'we have subject on the page' );
    $m->content_contains('this is main content', 'main content' );
    ok( $m->find_link( text => $plain_name, url_regex => qr{Attachment/} ), 'download plain file link' );

    # Check for Message-IDs
    follow_parent_with_headers_link($m, url_regex => qr/Attachment\/WithHeaders\//, n => 1);
    $m->content_like(qr/^Message-ID:/im, 'create content has one Message-ID');
    $m->content_unlike(qr/^Message-ID:.+?Message-ID:/ism, 'but not two Message-IDs');
    $m->back;

    follow_with_headers_link($m, url_regex => qr/Attachment\/\d+\/\d+\/$plain_name/, n => 1);
    $m->content_unlike(qr/^Message-ID:/im, 'attachment lacks a Message-ID');
    $m->back;

    my ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main content/, 'email contains main content' );
    # check the email link in page too
    $m->follow_link_ok( { url_regex => qr/ShowEmailRecord/ }, 'show the email outgoing' );
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
    ok( $m->find_link( text => $html_name, url_regex => qr{Attachment/} ), 'download html file link' );

    # Check for Message-IDs
    follow_parent_with_headers_link($m, url_regex => qr/Attachment\/WithHeaders\//, n => 2);
    $m->content_like(qr/^Message-ID:/im, 'correspondence has one Message-ID');
    $m->content_unlike(qr/^Message-ID:.+?Message-ID:/ism, 'but not two Message-IDs');
    $m->back;

    follow_with_headers_link($m, url_regex => qr/Attachment\/\d+\/\d+\/$plain_name/, n => 2);
    $m->content_unlike(qr/^Message-ID:/im, 'text/plain attach lacks a Message-ID');
    $m->back;

    follow_with_headers_link($m, url_regex => qr/Attachment\/\d+\/\d+\/$html_name/, n => 1);
    $m->content_unlike(qr/^Message-ID:/im, 'text/html attach lacks a Message-ID');
    $m->back;

    ( $mail ) = RT::Test->fetch_caught_mails;
    like( $mail, qr/this is main reply content/, 'email contains main reply content' );
    # check the email link in page too
    $m->follow_link_ok( { url_regex => qr/ShowEmailRecord/, n => 2 }, 'show the email outgoing' );
    $m->content_contains("this is main reply content", 'email contains main reply content');
    $m->back;
}

$m->goto_create_ticket( $qid );
$m->submit_form_ok(
    {
        form_name => 'TicketCreate',
        fields    => {
            Subject => 'with main body',
            Content => 'this is main body',
            Attach  => $plain_file,
        },
        button    => 'SubmitTicket',
    },
    'submit TicketCreate form'
);
$m->text_like( qr/Ticket \d+ created in queue/, 'ticket is created' );
ok( $m->find_link( text => $plain_name ), 'download plain file link' );
$m->follow_link_ok( { url_regex => qr/QuoteTransaction=/ }, 'reply the create transaction' );
my $form    = $m->form_name( 'TicketUpdate' );
my $content = $form->find_input( 'UpdateContent' );
like( $content->value, qr/this is main body/, 'has transaction content' );

$m->goto_create_ticket( $qid );
$m->submit_form_ok(
    {
        form_name => 'TicketCreate',
        fields    => {
            Subject => 'without main body',
            Attach  => $plain_file,
        },
        button    => 'SubmitTicket',
    },
    'submit TicketCreate form'
);
$m->text_like( qr/Ticket \d+ created in queue/, 'ticket is created' );
ok( $m->find_link( text => $plain_name ), 'download plain file link' );
$m->follow_link_ok( { url_regex => qr/QuoteTransaction=/ }, 'reply the create transaction' );
$form    = $m->form_name( 'TicketUpdate' );
$content = $form->find_input( 'UpdateContent' );
like( $content->value, qr/This transaction appears to have no content/, 'no transaction content' );

$m->goto_create_ticket( $qid );
$m->submit_form_ok(
    {
        form_name => 'TicketCreate',
        fields    => {
            Subject     => 'outlook plain quotes nested in html',
            ContentType => 'text/html',
            Content     => <<'EOF',
<div>On Tue Mar 01 18:29:22 2022, root wrote:
<blockquote>
<pre>
replied from outlook

________________________________________
From: root &lt;root@localhost&gt;
Sent: Tuesday, March 1, 2022 2:24 PM
To: rt
Subject: test mixed quotes

test

</pre>
</blockquote>
</div>

<p>test</p>
EOF
        },
        button    => 'SubmitTicket',
    },
    'submit TicketCreate form'
);
$m->text_like( qr/Ticket \d+ created in queue/, 'ticket is created' );
$m->content_contains(<<'EOF', 'stanza output' );
<div class="message-stanza closed"><blockquote>


<pre>
replied from outlook
</pre>
<div class="message-stanza open"><blockquote>
<pre>
________________________________________
From: root &lt;root@localhost&gt;
Sent: Tuesday, March 1, 2022 2:24 PM
To: rt
Subject: test mixed quotes

test

</pre>

</blockquote>
</div></blockquote></div></div>
EOF

$m->goto_create_ticket( $qid );
$m->submit_form_ok(
    {
        form_name => 'TicketCreate',
        fields    => {
            Subject     => 'outlook plain quotes nested in html',
            ContentType => 'text/html',
            Content     => <<'EOF',
This is what they typed
<blockquote>
This is what they replied to
<div><br>
-------- Forwarded Message --------
This is the original forwarded email
</div>
</blockquote>
EOF
        },
        button    => 'SubmitTicket',
    },
    'submit TicketCreate form'
);
$m->text_like( qr/Ticket \d+ created in queue/, 'ticket is created' );
$m->content_contains(<<'EOF', 'stanza output' );
<div class="message-stanza closed"><blockquote>

This is what they replied to

<div><br>
</div>
<div class="message-stanza open"><blockquote>
<div>-------- Forwarded Message --------
This is the original forwarded email
</div>

</blockquote>
</div></blockquote></div><hr class="clear"></div></div>
EOF

done_testing;
