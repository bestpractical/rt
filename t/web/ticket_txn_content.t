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
    $m->follow_link_ok( { url_regex => qr/ShowEmailRecord/, n => 1 }, 'show the email outgoing' );
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

diag "Testing spaces in text content";
$m->goto_create_ticket( $qid );
$m->submit_form_ok(
    {
        form_name => 'TicketCreate',
        fields    => {
            Subject     => 'Multiple plain spaces',
            ContentType => 'text/plain',
            Content     => <<'EOF',
This is the first line.
This is a test with   multiple spaces.
EOF
        },
        button    => 'SubmitTicket',
    },
    'submit TicketCreate form'
);
$m->text_like( qr/Ticket \d+ created in queue/, 'ticket is created' );
$m->content_contains( q{This is the first line.<br />This is a test with &nbsp; multiple spaces.},
    'space is not collapsed' );

diag "multipart/related with a text/plain root (no text/html) must still display the body";
{
    my $path
        = RT::Test::get_relocatable_file( 'multipart-related-text-plain', ( File::Spec->updir(), 'data', 'emails' ) );
    my $email = RT::Test->file_content($path);

    my ( $status, $id ) = RT::Test->send_via_mailgate($email);
    is( $status >> 8, 0, 'mail gateway exited normally' );
    ok( $id, "created ticket #$id from multipart/related message" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load($id);
    is( $ticket->Id, $id, "loaded ticket #$id" );

    # Confirm the message really has the structure under test before asserting
    # on how it is displayed.
    my $txn = $ticket->Transactions->First;
    my $top = $txn->Attachments->First;
    is( lc $top->ContentType, 'multipart/related', 'top-level part is multipart/related' );

    my %child_types = map { lc( $_->ContentType ) => 1 }
        grep { $_->Parent == $top->Id } @{ $txn->Attachments->ItemsArrayRef };
    ok( $child_types{'text/plain'}, 'has a text/plain child part' );
    ok( !$child_types{'text/html'}, 'has no text/html child part' );

    $m->get_ok( "/Ticket/History.html?id=$id", 'fetched ticket history' );

    my @bodies = $m->dom->find('div.messagebody')->map('all_text')->each;
    ok( ( grep {/UNIQUEPLAINBODY/} @bodies ), 'text/plain body of the multipart/related message is displayed inline' )
        or diag "Rendered message bodies: " . join( '||', @bodies );
}

# Returns the concatenated text of every rendered message body for a ticket.
sub history_bodies {
    my $tid = shift;
    $m->get_ok( "/Ticket/History.html?id=$tid", "fetched history for #$tid" );
    return join '||', $m->dom->find('div.messagebody')->map('all_text')->each;
}

# Used by both the PreferRichText on/off cases below.
my $alt_id;

diag "nested multipart/alternative -> multipart/related(html): exactly one textual part renders";
{
    # The common MUA structure (Outlook, Apple Mail, Gmail):
    #   multipart/alternative
    #     text/plain          # plain downgrade
    #     multipart/related
    #       text/html         # composed rich body
    #       image/png         # inline CID image
    # The text/html part's direct parent is the multipart/related.  RT must
    # show exactly one textual part, never both (the "duplicate message"
    # regression fixed in 4a38585f75) and never neither.  With PreferRichText
    # on (the default) the rich body wins.
    my $path = RT::Test::get_relocatable_file( 'multipart-alternative-related-html',
        ( File::Spec->updir(), 'data', 'emails' ) );
    my $email = RT::Test->file_content($path);

    my ( $status, $id ) = RT::Test->send_via_mailgate($email);
    is( $status >> 8, 0, 'mail gateway exited normally' );
    ok( $id, "created ticket #$id from nested alternative/related message" );
    $alt_id = $id;

    my $bodies = history_bodies($id);
    like( $bodies, qr/HTMLBODYMARKER/, 'PreferRichText on: text/html body is displayed' );
    unlike( $bodies, qr/PLAINDOWNGRADEMARKER/, 'PreferRichText on: text/plain downgrade is suppressed (no duplicate)' );
}

diag "same message with PreferRichText off: the plain downgrade wins";
{
    # PreferRichText is overridable, so flip it via the user preference rather
    # than restarting the server with a new system config.
    my $root = RT::User->new( RT->SystemUser );
    $root->Load('root');
    my ( $ok, $msg ) = $root->SetPreferences( RT->System, { PreferRichText => 0 } );
    ok( $ok, "set root's PreferRichText preference to 0" ) or diag $msg;

    my $bodies = history_bodies($alt_id);
    like( $bodies, qr/PLAINDOWNGRADEMARKER/, 'PreferRichText off: text/plain downgrade is displayed' );
    unlike( $bodies, qr/HTMLBODYMARKER/, 'PreferRichText off: text/html body is suppressed (no duplicate)' );
}

done_testing;
