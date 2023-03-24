use strict;
use warnings;

use RT::Test tests => undef;

my $content = join ' ', ('<h3>The quick brown fox jumps over the lazy dog.</h3>') x 5;
$content = join '<br>', $content, $content, $content;

my $escaped_content = $content;
RT::Interface::Web::EscapeHTML( \$escaped_content );

my $cf = RT::CustomField->new( RT->SystemUser );
$cf->Load('Content');
ok( $cf->Id, 'Found custom field' );

my $article = RT::Article->new( RT->SystemUser );
my ( $ret, $msg ) = $article->Create( Class => 'General', Name => 'Test html content' );
ok( $ret, 'Created article' );

my ( $base, $m ) = RT::Test->started_ok;

$m->login;

my $cf_input = RT::Interface::Web::GetCustomFieldInputName(
    Object      => $article,
    CustomField => $cf,
);

$m->get_ok( '/Articles/Article/Edit.html?id=' . $article->Id );

$m->submit_form_ok(
    {
        with_fields => {
            $cf_input => $content,
        },
    },
    'Set content'
);

$m->content_contains( "<li>Content $escaped_content added</li>", 'content found' );
$m->save_content('/tmp/x.html');

my $new_content         = '<h3>The quick brown fox jumps over the lazy dog.</h3>';
my $escaped_new_content = $new_content;
RT::Interface::Web::EscapeHTML( \$escaped_new_content );

$m->submit_form_ok(
    {
        with_fields => {
            $cf_input => $new_content,

        },
    },
    'Update content'
);

$m->content_contains( "<li>Content $escaped_content changed to $escaped_new_content</li>", 'Content was updated' );

my $newer_content         = '<h3>The quick yellow fox jumps over the lazy dog.</h3>';
my $escaped_newer_content = $newer_content;
RT::Interface::Web::EscapeHTML( \$escaped_newer_content );

$m->submit_form_ok(
    {
        with_fields => {
            $cf_input => $newer_content,

        },
    },
    'Update content again'
);

$m->content_contains( "<li>Content $escaped_new_content changed to $escaped_newer_content</li>",
    'Content was updated' );

my $txn = $article->Transactions->Last;
$m->get_ok( '/Helpers/TextDiff?TransactionId=' . $txn->id );
$m->content_like( qr{<del>brown\s*</del><ins>yellow\s*</ins>}, 'text diff has the brown => yellow change' );

$m->back;
$m->follow_link_ok( { text => 'Display' } );
$m->content_contains( $newer_content, 'Content on display page' );

$m->back;
$m->submit_form_ok(
    {
        with_fields => {
            $cf_input => '',
        },
    },
    'Delete content'
);

$m->content_contains( "<li>$escaped_newer_content is no longer a value for custom field Content</li>",
    'Content was deleted' );

$m->follow_link_ok( { text => 'History' } );
$m->content_like(
    qr/Content\sadded.+\Q$content\E.+
       Content\schanged.+From:.+\Q$content\E.+To:.+\Q$new_content\E.+
       Content\schanged.+From:.+\Q$new_content\E.+To:.+\Q$newer_content\E.+
       Content\sdeleted.+\Q$newer_content\E/xs,
    'Content change details'
);

done_testing;
