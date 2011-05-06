use strict;
use warnings;
use RT;
use RT::Test tests => 18;

RT->Config->Set( DevelMode            => 0 );
RT->Config->Set( WebDefaultStylesheet => 'aileron' );
RT->Config->Set( JSFiles => () );

my ( $url, $m );

diag "test squished files with devel mode disabled";
{
    ( $url, $m ) = RT::Test->started_ok;
    $m->login;

    $m->follow_link_ok( { url_regex => qr!aileron-squished-([a-f0-9]{32})\.css! },
        'follow squished css' );
    $m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
    $m->content_lacks( 'text-decoration: underline !important;',
        'no print.css by default' );

    $m->back;
    my ($js_link) =
      $m->content =~ m!src="([^"]+?squished-([a-f0-9]{32})\.js)"!;
    $m->get_ok( $url . $js_link, 'follow squished js' );
    $m->content_lacks('function showShredderPluginTab', "no util.js");

    RT::Test->stop_server;
}

diag "test squished files with customized files and devel mode disabled";
SKIP:
{
    skip 'need plack server to reinitialize', 6
      if $ENV{RT_TEST_WEB_HANDLER} && $ENV{RT_TEST_WEB_HANDLER} ne 'plack';
    RT->AddJavaScript( 'util.js' );
    RT->AddStyleSheets( 'print.css' );
    ( $url, $m ) = RT::Test->started_ok;

    $m->login;
    $m->follow_link_ok( { url_regex => qr!aileron-squished-([a-f0-9]{32})\.css! },
        'follow squished css' );
    $m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
    $m->content_contains( 'text-decoration: underline !important;',
        'has print.css' );

    $m->back;
    my ($js_link) =
      $m->content =~ m!src="([^"]+?squished-([a-f0-9]{32})\.js)"!;
    $m->get_ok( $url . $js_link, 'follow squished js' );
    $m->content_contains('function showShredderPluginTab', "has util.js");
    RT::Test->stop_server;
}

diag "test squished files with devel mode enabled";
{
    RT->Config->Set( 'DevelMode' => 1 );
    RT->AddJavaScript( 'util.js' );
    RT->AddStyleSheets( 'nottherebutwedontcare.css' );

    ( $url, $m ) = RT::Test->started_ok;
    $m->login;
    $m->content_unlike( qr!squished-.*?\.(js|css)!,
        'no squished link with develmode' );
    $m->content_contains('util.js', "found extra javascript resource");
    $m->content_contains('nottherebutwedontcare.css', "found extra css resource");
}
