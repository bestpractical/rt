use strict;
use warnings;

use File::Spec;
use RT::Test tests => undef;

my $ticket = RT::Test->create_ticket(
    Queue       => 'General',
    Subject     => 'test scrubber',
    ContentType => 'text/html',
    Content     => <<'EOF' );
Image start
<img src="https://example.com/test.png">
Image end
EOF

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

$m->goto_ticket( $ticket->Id );

$m->content_lacks('<img src="https://example.com/test.png">', 'Remote images are not shown by default');

my $config = RT::Configuration->new( RT->SystemUser );
my ( $ret, $msg ) = $config->Create(
    Name    => 'ShowRemoteImages',
    Content => 1,
);
ok( $ret, 'Updated config' );

$m->reload;
$m->content_contains('<img src="https://example.com/test.png">', 'Remote images are shown with ShowRemoteImages=1');

# Tests covering the inputs the client-side auto-contrast scanner relies on:
# colors set on email HTML must survive scrubbing + CSS::Inliner, and the
# history container must emit data-auto-contrast reflecting the config.

diag "Inline color style survives into the rendered messagebody";
{
    my $t = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'auto-contrast inline color',
        ContentType => 'text/html',
        Content     => '<p style="color: #222222;">Dark text that is unreadable in dark mode</p>',
    );
    $m->goto_ticket( $t->Id );
    $m->content_contains( 'color: #222222',
        'rendered messagebody retains inline color style' );
}

diag "Stylesheet block gets inlined by CSS::Inliner";
{
    my $t = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'auto-contrast style block',
        ContentType => 'text/html',
        Content     => '<style>p { color: #333333; }</style><p>Stylesheet-driven dark text</p>',
    );
    $m->goto_ticket( $t->Id );
    $m->content_contains( 'color: #333333',
        'CSS::Inliner pushed stylesheet color onto the element style attribute' );
}

diag "An explicit inline background-color survives alongside a paired color";
{
    my $t = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'auto-contrast own-bg',
        ContentType => 'text/html',
        Content     => '<p style="color: #111111; background-color: #dddddd;">Both colors set inline</p>',
    );
    $m->goto_ticket( $t->Id );
    $m->content_contains( 'background-color: #dddddd',
        'inline background-color is not scrubbed' );
    $m->content_contains( 'color: #111111',
        'paired inline color is not scrubbed' );
}

diag "History container emits data-auto-contrast=1 by default";
{
    $m->goto_ticket( $ticket->Id );
    $m->content_contains( 'data-auto-contrast="1"',
        'history-container has data-auto-contrast=1 by default' );
}

diag "Real-world fixture: inline span color pattern from webmail senders";
{
    my $path    = RT::Test::get_relocatable_file(
        'html-inline-span-colors',
        ( File::Spec->updir(), 'data', 'emails' ),
    );
    my $mail    = RT::Test->file_content($path);
    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, 'mail gateway accepted the fixture' );
    ok( $id, "created ticket $id from fixture" );

    $m->goto_ticket($id);

    # Span-level colors on transparent bg — the pattern that triggers the
    # scanner in dark mode (but renders fine in light mode).
    $m->content_contains( 'color:#222222',
        'span-on-transparent #222 color survives into rendered messagebody' );
    $m->content_contains( 'color:#0000ff',
        'span blue annotation color survives into rendered messagebody' );

    # Span-level white background with dark text — should never trigger the
    # scanner regardless of theme because the inner bg/fg pair is high-contrast.
    $m->content_contains( 'background-color:#ffffff',
        'span-level explicit white background survives scrubbing' );
    $m->content_contains( 'color:#000000',
        'span-level explicit black text color survives scrubbing' );

    # The transparent-bg spans also need to keep their transparency so the
    # scanner walks up to the theme bg instead of stopping at the span.
    $m->content_contains( 'background-color:transparent',
        'span-level transparent background survives scrubbing' );
}

diag "Disabling \$TransactionAutoContrast flips the data attribute to 0";
{
    my $cfg = RT::Configuration->new( RT->SystemUser );
    my ( $r, $m2 ) = $cfg->Create(
        Name    => 'TransactionAutoContrast',
        Content => 0,
    );
    ok( $r, "Set TransactionAutoContrast=0: $m2" );

    $m->reload;
    $m->goto_ticket( $ticket->Id );
    $m->content_contains( 'data-auto-contrast="0"',
        'history-container has data-auto-contrast=0 when disabled' );

    # Leave config consistent for any further tests in the file.
    my $row = RT::Configuration->new( RT->SystemUser );
    $row->LoadByCols( Name => 'TransactionAutoContrast' );
    $row->Delete if $row->Id;
}

done_testing;
