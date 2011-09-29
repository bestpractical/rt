use strict;
use warnings;
use RT;
use RT::Test tests => 26;

RT->Config->Set( DevelMode            => 0 );
RT->Config->Set( WebDefaultStylesheet => 'aileron' );
RT->Config->Set( MasonLocalComponentRoot => RT::Test::get_abs_relocatable_dir('html') );

my ( $url, $m ) = RT::Test->started_ok;
$m->login;

diag "test squished files with devel mode disabled";

$m->follow_link_ok( { url_regex => qr!aileron-squished-([a-f0-9]{32})\.css! },
    'follow squished css' );
$m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
$m->content_lacks( 'text-decoration: underline !important;',
    'no print.css by default' );

$m->back;
my ($js_link) =
  $m->content =~ m!src="([^"]+?squished-([a-f0-9]{32})\.js)"!;
$m->get_ok( $url . $js_link, 'follow squished js' );
$m->content_lacks('function just_testing', "no not-by-default.js");
$m->content_contains('jQuery.noConflict', "found default js content");

RT::Test->stop_server;

diag "test squished files with customized files and devel mode disabled";
RT->AddJavaScript( 'not-by-default.js' );
RT->AddStyleSheets( 'print.css' );

( $url, $m ) = RT::Test->started_ok;

$m->login;
$m->follow_link_ok( { url_regex => qr!aileron-squished-([a-f0-9]{32})\.css! },
    'follow squished css' );
$m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
$m->content_contains( 'text-decoration: underline !important;',
    'has print.css' );

$m->back;
($js_link) =
  $m->content =~ m!src="([^"]+?squished-([a-f0-9]{32})\.js)"!;
$m->get_ok( $url . $js_link, 'follow squished js' );
$m->content_contains( 'function just_testing', "has not-by-default.js" );
$m->content_contains('jQuery.noConflict', "found default js content");
RT::Test->stop_server;


diag "Test with a trivial jsmin which is a pass-through";
RT->Config->Set( 'JSMinPath' => RT::Test::get_abs_relocatable_dir("passthrough-jsmin"));
( $url, $m ) = RT::Test->started_ok;
$m->login;
($js_link) =
  $m->content =~ m!src="([^"]+?squished-([a-f0-9]{32})\.js)"!;
$m->get_ok( $url . $js_link, 'follow squished js' );
$m->content_contains( 'passthrough-jsmin added this', "has passthrough-added content" );
$m->content_contains( 'function just_testing', "has not-by-default.js" );
$m->content_contains('jQuery.noConflict', "found default js content");
RT::Test->stop_server;


diag "test squished files with devel mode enabled";
RT->Config->Set( 'DevelMode' => 1 );
RT->AddJavaScript( 'not-by-default.js' );
RT->AddStyleSheets( 'nottherebutwedontcare.css' );

( $url, $m ) = RT::Test->started_ok;
$m->login;
$m->content_unlike( qr!squished-.*?\.(js|css)!,
    'no squished link with develmode' );

$m->content_contains('not-by-default.js', "found extra javascript resource");
$m->content_contains('nottherebutwedontcare.css', "found extra css resource");
$m->content_contains('jquery_noconflict.js', "found a default js resource");

