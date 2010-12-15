use strict;
use warnings;
use RT;
use RT::Test tests => 16;

RT->Config->Set( DevelMode            => 0 );
RT->Config->Set( WebDefaultStylesheet => 'aileron' );

my ( $url, $m );

diag "test squished files with devel mode disabled";
{
    ( $url, $m ) = RT::Test->started_ok;
    $m->login;

    $m->follow_link_ok( { url_regex => qr!main-squished-([a-f0-9]{32})\.css! },
        'follow squished css' );
    $m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
    $m->content_lacks( 'text-decoration: underline !important;',
        'no print.css by default' );

    $m->back;
    my ($js_link) =
      $m->content =~ m!src="([^"]+squished-([^"]+)-([a-f0-9]{32})\.js)"!;
    $m->get_ok( $url . $js_link, 'follow squished js' );
    $m->content_lacks( 'IE7=', 'no IE7.js by default' );

    RT::Test->stop_server;
}

diag "test squished files with customized files and devel mode disabled";
{
    require RT::Squish::JS;
    RT::Squish::JS->UpdateFilesMap( head => ['/NoAuth/js/IE7/IE7.js'] );
    require RT::Squish::CSS;
    RT::Squish::CSS->UpdateFilesMap( aileron => ['/NoAuth/css/print.css'] );
    ( $url, $m ) = RT::Test->started_ok;

    $m->login;
    $m->follow_link_ok( { url_regex => qr!main-squished-([a-f0-9]{32})\.css! },
        'follow squished css' );
    $m->content_like( qr!/\*\* End of .*?.css \*/!, 'squished css' );
    $m->content_contains( 'text-decoration: underline !important;',
        'has print.css' );

    $m->back;
    my ($js_link) =
      $m->content =~ m!src="([^"]+squished-([^"]+)-([a-f0-9]{32})\.js)"!;
    $m->get_ok( $url . $js_link, 'follow squished js' );
    $m->content_contains( 'IE7=', 'has IE7.js' );
    RT::Test->stop_server;
}

diag "test squished files with devel mode enabled";
{
    RT->Config->Set( 'DevelMode' => 1 );
    ( $url, $m ) = RT::Test->started_ok;
    $m->login;
    $m->content_unlike( qr!squished-.*?\.(js|css)!,
        'no squished link with develmode' );
}
