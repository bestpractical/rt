use strict;
use warnings;

use RT::Test tests => undef, playwright => 1;

my ( $url, $p ) = RT::Test->started_ok;
$p->login();

diag 'pickers for empty fields show the color in effect';
{
    my $page   = $p->{page};
    my $picker = sub {
        my ( $mode, $name ) = @_;
        return $page->locator(qq{input.palette-picker[data-mode="$mode"][data-property="$name"]})->inputValue();
    };

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor with an empty palette' );
    # The pickers fill in once the hidden per-mode frames load.
    $p->{handle}->await( $page->waitForFunction( q{(function() { return document.querySelector('input.palette-picker[data-mode="light"][data-property="--bs-primary"]').value !== "#000000"; })()}, {}, { timeout => 10000 } ) );
    is( $picker->( light => '--bs-primary' ),      '#3858a3', 'light Primary picker shows the default primary' );
    is( $picker->( light => '--rt-secondary' ),    '#547ccc', 'light Secondary picker shows the default secondary' );
    is( $picker->( light => '--rt-tertiary' ),     '#2c3539', 'light Tertiary picker shows the default tertiary' );
    is( $picker->( light => '--rt-menu-hover-bg' ), '#d7deed', 'light Menu hover picker shows the color mixed from Primary' );
    is( $picker->( dark => '--rt-menu-hover-bg' ),  '#3c4a5f', 'dark Menu hover picker shows the color mixed from Primary' );
    is( $picker->( dark => '--rt-menu-bg' ),        '#343d41', 'dark Menus picker shows the dark menu color' );

    $page->locator('input[name="palette.light.--bs-primary"]')->fill('#b4470b');
    is( $picker->( light => '--rt-widget-title-color' ), '#b4470b', 'Widget titles picker follows Primary' );
    is( $picker->( light => '--rt-primary-contrast' ),   '#ffffff', 'Text on primary picker shows the derived contrast' );

    $page->locator('input[name="palette.light.--bs-primary"]')->fill('');
    is( $picker->( light => '--bs-primary' ), '#3858a3', 'clearing Primary restores the default in its picker' );
    is( $picker->( light => '--rt-widget-title-color' ), '#3858a3', 'Widget titles picker follows the cleared Primary' );

    $page->locator('#preview-mode')->click();
    is( $page->evaluate('return document.documentElement.getAttribute("data-bs-theme")'), 'dark', 'previewing dark mode' );
    is( $picker->( light => '--rt-menu-bg' ), '#ffffff', 'light Menus picker keeps its light color while previewing dark' );
    is( $picker->( dark => '--rt-menu-bg' ),  '#343d41', 'dark Menus picker unchanged while previewing dark' );
    $page->locator('#preview-mode')->click();
}

diag 'pickers are exact in both modes whatever mode the page is in';
{
    my $page   = $p->{page};
    my $picker = sub {
        my ( $mode, $name ) = @_;
        return $page->locator(qq{input.palette-picker[data-mode="$mode"][data-property="$name"]})->inputValue();
    };
    my $wait_for_picker = sub {
        my ( $mode, $name, $value ) = @_;
        $p->{handle}->await(
            $page->waitForFunction(
                qq{(function() { return document.querySelector('input.palette-picker[data-mode="$mode"][data-property="$name"]').value === "$value"; })()},
                {}, { timeout => 10000 }
            )
        );
    };

    my $root = RT::User->new( RT->SystemUser );
    $root->Load('root');
    my $prefs = $root->Preferences( $RT::System ) || {};
    my ($ok) = $root->SetPreferences( $RT::System => { %$prefs, WebDefaultThemeMode => 'dark' } );
    ok( $ok, 'root prefers dark mode' );

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor in dark mode' );
    is( $page->evaluate('return document.documentElement.getAttribute("data-bs-theme")'), 'dark', 'page is dark' );
    $wait_for_picker->( light => '--bs-primary', '#3858a3' );
    is( $picker->( light => '--bs-primary' ),      '#3858a3', 'light Primary picker exact on a dark page' );
    is( $picker->( light => '--rt-menu-hover-bg' ), '#d7deed', 'light Menu hover picker exact on a dark page' );

    ($ok) = $root->SetPreferences( $RT::System => { %$prefs, WebDefaultThemeMode => 'light' } );
    ok( $ok, 'root prefers light mode' );

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor in light mode' );
    is( $page->evaluate('return document.documentElement.getAttribute("data-bs-theme")'), 'light', 'page is light' );
    $wait_for_picker->( light => '--bs-primary', '#3858a3' );

    # color-mix(in srgb, <primary> 25%, <dark --bs-secondary-bg>), the dark
    # --rt-menu-hover-bg. The secondary bg is itself #2c3539 mixed 8% toward
    # white, unrounded.
    my @menu = map { 0.92 * $_ + 0.08 * 255 } ( 0x2c, 0x35, 0x39 );
    my @red  = ( 0xff, 0, 0 );
    my $mix  = '#' . join '', map { sprintf '%02x', int( 0.25 * $red[$_] + 0.75 * $menu[$_] + 0.5 ) } 0 .. 2;
    $page->locator('input[name="palette.dark.--bs-primary"]')->fill('#ff0000');
    is( $picker->( dark => '--rt-menu-hover-bg' ), $mix, "dark Menu hover picker mixes the dark Primary ($mix)" );
    $page->locator('input[name="palette.dark.--bs-primary"]')->fill('');

    ($ok) = $root->SetPreferences( $RT::System => $prefs );
    ok( $ok, 'root theme preference restored' );
}


diag 'tabs show the Basic and Advanced fields';
{
    my $page = $p->{page};
    my $visible_rows = sub {
        my $pane = shift;
        return $page->evaluate(
            qq{return [...document.querySelectorAll("$pane .palette-row")].filter(row => row.checkVisibility()).length});
    };

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    is( $visible_rows->('#theme-basic'),    3, 'Basic tab shows three rows' );
    is( $visible_rows->('#theme-advanced'), 0, 'Advanced rows hidden at first' );
    is( $page->locator('#theme-advanced .palette-row')->count, 11, 'Advanced fields present while hidden' );
    ok( $page->locator('#preview-mode')->isVisible, 'preview toggle visible on Basic tab' );

    $page->locator('#theme-tabs a[href="#theme-advanced"]')->click();
    is( $visible_rows->('#theme-advanced'), 11, 'Advanced tab shows its fields after clicking it' );
    is( $visible_rows->('#theme-basic'),    0,  'Basic rows hidden on Advanced tab' );
    ok( $page->locator('input[name="palette.dark.--rt-footer-color"]')->isVisible, 'dark Advanced field visible' );

    $page->locator('#theme-tabs a[href="#theme-custom-css"]')->click();
    ok( $page->locator('#user_css')->isVisible, 'Custom CSS textarea visible on its tab' );
    ok( !$page->locator('#preview-mode')->isVisible, 'palette buttons hidden on Custom CSS tab' );
}

diag 'dark override and derived dark value survive save and reload';
{
    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    $p->{page}->locator('input[name="palette.light.--bs-primary"]')->fill('#b4470b');
    $p->{page}->locator('#theme-tabs a[href="#theme-advanced"]')->click();
    $p->{page}->locator('input[name="palette.dark.--rt-menu-bg"]')->fill('#1e1626');

    my $preview = $p->{page}->evaluate('return document.getElementById("sitecss").textContent');
    like( $preview, qr/:root \{\s*--bs-primary: #b4470b;/, 'preview applies light primary to both modes' );
    like( $preview, qr/\[data-bs-theme=dark\] \{\s*--rt-menu-bg: #1e1626;/, 'preview includes dark override' );

    $p->{page}->locator('input[name="save_palette"]')->click();
    $p->wait_for_htmx();

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'reload theme editor' );
    is( $p->{page}->locator('input[name="palette.light.--bs-primary"]')->inputValue(), '#b4470b', 'light value kept' );
    is( $p->{page}->locator('input[name="palette.dark.--rt-menu-bg"]')->inputValue(), '#1e1626', 'dark override kept' );
    is( $p->{page}->locator('input[name="palette.dark.--bs-primary"]')->inputValue(), '', 'dark primary still derived' );
}

diag 'picker and text field stay in sync; preview mode toggles';
{
    $p->{page}->locator('input.palette-picker[data-mode="light"][data-property="--rt-secondary"]')->fill('#5b2a86');
    is( $p->{page}->locator('input[name="palette.light.--rt-secondary"]')->inputValue(), '#5b2a86', 'picker updates text field' );

    my $before = $p->{page}->evaluate('return document.documentElement.getAttribute("data-bs-theme")');
    $p->{page}->locator('#preview-mode')->click();
    my $after = $p->{page}->evaluate('return document.documentElement.getAttribute("data-bs-theme")');
    isnt( $after, $before, 'preview mode toggles the page theme' );
}

diag 'custom CSS and palette previews combine';
{
    $p->{page}->locator('#theme-tabs a[href="#theme-custom-css"]')->click();
    $p->{page}->locator('#user_css')->fill('body { outline: 1px solid red; }');
    my $preview = $p->{page}->evaluate('return document.getElementById("sitecss").textContent');
    like( $preview, qr/--rt-secondary: #5b2a86;/, 'palette still in preview' );
    like( $preview, qr/outline: 1px solid red/, 'custom CSS in preview' );
}

diag 'mode-specific light property renders in the light-only block';
{
    $p->{page}->locator('#theme-tabs a[href="#theme-advanced"]')->click();
    $p->{page}->locator('input[name="palette.light.--rt-menu-bg"]')->fill('#fafafa');
    my $preview = $p->{page}->evaluate('return document.getElementById("sitecss").textContent');
    like( $preview, qr/:root:not\(\[data-bs-theme=dark\]\) \{\s*--rt-menu-bg: #fafafa;/, 'mode-specific light value in light-only block' );
    unlike( $preview, qr/:root \{[^}]*--rt-menu-bg/, 'not in the shared block' );
}

diag 'sitecss follows saved state across boosted navigation';
{
    my $css = sub { $p->{page}->evaluate('return document.getElementById("sitecss").textContent') };

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    $p->{page}->locator('input[name="palette.light.--bs-primary"]')->fill('#112233');
    $p->{page}->locator('input[name="save_palette"]')->click();
    $p->wait_for_htmx();
    $p->{page}->locator('#theme-tabs a[href="#theme-custom-css"]')->click();
    $p->{page}->locator('#user_css')->fill('/* saved-marker */');
    $p->{page}->locator('#custom-css-form input[value="Save"]')->click();
    $p->wait_for_htmx();
    like( $css->(), qr/--bs-primary: #112233;/, 'saved palette in sitecss after save' );

    # Unsaved edit, then leave via a boosted link
    $p->{page}->locator('#theme-tabs a[href="#theme-basic"]')->click();
    $p->{page}->locator('input[name="palette.light.--bs-primary"]')->fill('#445566');
    like( $css->(), qr/#445566/, 'unsaved value previewed' );
    $p->{page}->locator('#main-navigation a[href$="/Admin/"]')->first->click();
    # wait_for_htmx's networkidle wait times out on the slow Admin page, so wait for the URL push instead. htmx saves history (running teardown), pushes the URL and swaps synchronously.
    $p->{handle}->await( $p->{page}->waitForFunction( '(function() { return location.pathname.endsWith("/Admin/"); })()', {}, { timeout => 20000 } ) );
    unlike( $css->(), qr/#445566/, 'unsaved value gone after boosted navigation' );
    like( $css->(), qr/--bs-primary: #112233;/, 'saved palette present after boosted navigation' );
    like( $css->(), qr/saved-marker/, 'saved custom CSS present after boosted navigation' );
}

diag 'preview derives text-on-primary contrast the same way as the server';
{
    my $page = $p->{page};
    my $css  = sub { $page->evaluate('return document.getElementById("sitecss").textContent') };
    my $root = qr/^:root \{\n    --bs-primary: #f28c28;\n    --rt-primary-contrast: #000;\n\}\n/m;

    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    $page->locator('input[name="palette.light.--bs-primary"]')->fill('#f28c28');
    my $preview = $css->();
    like( $preview, $root, 'preview derives black text for an orange primary' );

    $page->locator('input[name="save_palette"]')->click();
    $p->wait_for_htmx();
    my $saved = $page->evaluate('return document.getElementById("ThemePalette").dataset.savedCss');
    like( $saved, $root, 'server-rendered saved CSS derives the same contrast' );
    my ($preview_block) = $preview =~ /(^:root \{.*?^\}\n)/ms;
    my ($saved_block)   = $saved   =~ /(^:root \{.*?^\}\n)/ms;
    is( $preview_block, $saved_block, 'preview and saved :root blocks match' );

    $page->locator('input[name="palette.dark.--bs-primary"]')->fill('#3858a3');
    like( $css->(), qr/^\[data-bs-theme=dark\] \{\n    --bs-primary: #3858a3;\n[^}]*    --rt-primary-contrast: #fff;\n/m,
        'dark contrast derived from the dark primary' );
    $page->locator('#theme-tabs a[href="#theme-advanced"]')->click();
    $page->locator('input[name="palette.light.--rt-primary-contrast"]')->fill('#123456');
    unlike( $css->(), qr/--rt-primary-contrast: #000;/, 'explicit light contrast replaces the derived one' );
    like( $css->(), qr/^:root \{[^}]*--rt-primary-contrast: #123456;/m, 'explicit light contrast in the shared block' );
}

diag 'three-digit hex primary derives contrast too';
{
    my $page = $p->{page};
    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    $page->locator('input[name="palette.light.--bs-primary"]')->fill('#f80');
    like( $page->evaluate('return document.getElementById("sitecss").textContent'),
        qr/^:root \{\n    --bs-primary: #f80;\n    --rt-primary-contrast: #000;\n\}\n/m,
        'preview derives black text for #f80' );
}

diag 'tab chosen with the keyboard is remembered after save';
{
    my $page = $p->{page};
    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    $page->locator('#theme-tabs a[href="#theme-basic"]')->focus();
    $page->keyboard->press('ArrowRight');
    is( $page->locator('#theme-tabs a.nav-link.active')->getAttribute('href'), '#theme-advanced', 'arrow key switches to Advanced' );
    $page->locator('input[name="save_palette"]')->click();
    $p->wait_for_htmx();
    is( $page->locator('#theme-tabs a.nav-link.active')->getAttribute('href'), '#theme-advanced', 'Advanced tab active after save' );
    ok( $page->locator('input[name="palette.light.--rt-footer-color"]')->isVisible, 'Advanced fields visible after save' );
}

my $script_suffix = qq{</style><script>window.rtUserCssMarker = (window.rtUserCssMarker || 0) + 1;</script><style>\n};
my $set_user_css = sub {
    my $css = shift;
    my ($ok) = RT->System->SetAttribute( Name => 'UserCSS', Description => 'User-provided css', Content => $css );
    ok( $ok, 'set UserCSS' );
};

diag 'UserCSS that adds a script: preview and teardown use only its CSS';
{
    my $page = $p->{page};
    my $css  = sub { $page->evaluate('return document.getElementById("sitecss").textContent') };
    my $marker_scripts = sub {
        $page->evaluate('return [...document.querySelectorAll("script")].filter(s => s.textContent.includes("rtUserCssMarker")).length');
    };

    $set_user_css->( qq{div#body { --usercss-marker: 1; }\n$script_suffix} );
    $p->get_ok( $url . '/Admin/Tools/Theme.html', 'load theme editor' );
    is( $marker_scripts->(), 1, 'UserCSS script element in the page' );
    is( $page->evaluate('return window.rtUserCssMarker'), 1, 'UserCSS script ran once' );
    unlike( $css->(), qr{</style}i, 'sitecss holds no closing style tag on load' );

    $page->locator('input[name="palette.light.--bs-primary"]')->fill('#445566');
    like( $css->(), qr/--usercss-marker: 1;/, 'preview keeps the CSS part of UserCSS' );
    unlike( $css->(), qr{</style}i, 'preview holds no closing style tag' );

    $page->locator('#main-navigation a[href$="/Admin/"]')->first->click();
    $p->{handle}->await( $page->waitForFunction( '(function() { return location.pathname.endsWith("/Admin/"); })()', {}, { timeout => 20000 } ) );
    unlike( $css->(), qr{</style}i, 'sitecss holds no closing style tag after boosted navigation' );
    like( $css->(), qr/--usercss-marker: 1;/, 'CSS part of UserCSS restored after boosted navigation' );
    unlike( $css->(), qr/#445566/, 'unsaved palette value gone after boosted navigation' );
    is( $marker_scripts->(), 1, 'UserCSS script element neither removed nor duplicated' );
    is( $page->evaluate('return window.rtUserCssMarker'), 1, 'UserCSS script did not run again' );
}


done_testing;
