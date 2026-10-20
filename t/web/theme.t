use strict;
use warnings;

use URI::Escape;
use RT::Test tests => undef, plugins => ['ThemeTest'];

diag 'ThemeModeSpecificProperties';
{
    my $props = RT::Interface::Web->ThemeModeSpecificProperties;
    ok( $props->{'--bs-body-bg'},   '--bs-body-bg differs in dark mode' );
    ok( $props->{'--bs-link-color'}, '--bs-link-color differs in dark mode' );
    ok( !$props->{'--bs-primary'},  '--bs-primary is shared by both modes' );
    ok( $props->{'--rt-menu-bg'},  '--rt-menu-bg from theme-tokens.css differs in dark mode' );
    ok( !$props->{'--rt-secondary'}, '--rt-secondary is shared by both modes' );
    ok( !$props->{'--rt-widget-title-color'}, '--rt-widget-title-color is shared by both modes' );
    ok( $props->{'--rt-menu-hover-bg'}, '--rt-menu-hover-bg differs in dark mode' );
    ok( $props->{$_}, "$_ differs in dark mode" )
        for qw(--bs-heading-color --bs-tertiary-bg --bs-secondary-bg --bs-secondary-color --bs-tertiary-color
        --bs-border-color --rt-border-color-strong --rt-menu-divider-color --rt-surface-bg --rt-surface-border-color);
}

diag 'ValidateThemePalette';
{
    my ( $clean, @errors ) = RT::Interface::Web->ValidateThemePalette(
        {   light => {
                '--bs-primary'          => ' #7a1f8c ',
                '--my-company-color'    => 'rebeccapurple',
                '--rt-heading-font'     => '"Creepster", serif',
                '--bs-body-bg'          => '',
                'color'                 => 'red',
                '--evil'                => 'red; } body { display: none',
                '--evil-tag'            => '</style><script>',
                '--open-comment'        => 'red /*',
                '--open-quote'          => '"Creepster, serif',
                '--quoted-comment'      => '"a /* b", serif',
            },
            dark => { '--bs-body-bg' => '#120a1a', '--bad-newline' => "red\nblue" },
        }
    );
    is_deeply(
        $clean,
        {   light => {
                '--bs-primary'       => '#7a1f8c',
                '--my-company-color' => 'rebeccapurple',
                '--rt-heading-font'  => '"Creepster", serif',
                '--quoted-comment'   => '"a /* b", serif',
            },
            dark => { '--bs-body-bg' => '#120a1a' },
        },
        'valid entries kept (unknown names too), empty dropped, values trimmed'
    );
    is( scalar @errors, 6, 'six rejected entries' ) or diag explain \@errors;
    like( $errors[0], qr/--evil\b/,      'first error: light --evil' );
    like( $errors[2], qr/--open-comment/, 'third error: light --open-comment' );
    like( $errors[3], qr/--open-quote/,   'fourth error: light --open-quote' );
    like( $errors[5], qr/--bad-newline/, 'last error: dark --bad-newline' );

    # Palettes that are not hashes are rejected, not fatal.
    for my $bad ( 'plain', [], { light => 'x' }, { dark => [] } ) {
        my ( $c, @e ) = RT::Interface::Web->ValidateThemePalette($bad);
        is_deeply( $c, {}, 'non-hash palette or mode yields nothing' );
        is( scalar @e, 1, 'one error for non-hash palette or mode' ) or diag explain \@e;
    }

    # Reference values are rejected, not stringified.
    {
        my ( $c, @e ) = RT::Interface::Web->ValidateThemePalette( { light => { '--a' => [], '--b' => {} } } );
        is_deeply( $c, {}, 'reference values are dropped' );
        is( scalar @e, 2, 'two errors for reference values' ) or diag explain \@e;
        like( $e[0], qr/--a\b/, 'error names --a' );
    }

    # Trimming is ASCII-only: NBSP is not whitespace here, so it is kept.
    {
        my ($c) = RT::Interface::Web->ValidateThemePalette( { light => { '--a' => "\x{A0}red\x{A0}" } } );
        is( $c->{light}{'--a'}, "\x{A0}red\x{A0}", 'non-ASCII whitespace is not trimmed' );
    }
}

diag 'ThemeContrastColor';
{
    is( RT::Interface::Web->ThemeContrastColor('#3858a3'), '#fff', 'dark blue gets white' );
    is( RT::Interface::Web->ThemeContrastColor('#f28c28'), '#000', 'orange gets black' );
    is( RT::Interface::Web->ThemeContrastColor('#fff'),    '#000', 'white gets black' );
    is( RT::Interface::Web->ThemeContrastColor('#000'),    '#fff', 'black gets white' );
    is( RT::Interface::Web->ThemeContrastColor('#F28C28'), '#000', 'hex digits are case-insensitive' );
    is( RT::Interface::Web->ThemeContrastColor('#f80'),    '#000', 'three-digit hex is expanded' );
    is( RT::Interface::Web->ThemeContrastColor('red'),     undef,  'named color gives undef' );
    is( RT::Interface::Web->ThemeContrastColor('var(--x)'), undef, 'var() gives undef' );
    is( RT::Interface::Web->ThemeContrastColor(undef),         undef,  'undef gives undef' );
    is( RT::Interface::Web->ThemeContrastColor("#fff\n"),     undef,  'trailing newline gives undef' );
}

diag 'ThemePaletteCSS';
{
    my $css = RT::Interface::Web->ThemePaletteCSS(
        {   light => { '--bs-primary' => '#7a1f8c', '--bs-body-bg' => '#fffaf0' },
            dark  => { '--bs-body-bg' => '#120a1a' },
        }
    );
    is( $css,
        ":root {\n    --bs-primary: #7a1f8c;\n    --rt-primary-contrast: #fff;\n}\n\n"
            . ":root:not([data-bs-theme=dark]) {\n    --bs-body-bg: #fffaf0;\n}\n\n"
            . "[data-bs-theme=dark] {\n    --bs-body-bg: #120a1a;\n}\n",
        'shared, light-only and dark blocks' );
    is( RT::Interface::Web->ThemePaletteCSS(
            { light => { '--bs-primary' => '#f28c28', '--rt-primary-contrast' => '#123456' } } ),
        ":root {\n    --bs-primary: #f28c28;\n    --rt-primary-contrast: #123456;\n}\n",
        'explicit contrast is not overridden' );
    is( RT::Interface::Web->ThemePaletteCSS(
            { light => { '--bs-primary' => '#3858a3' }, dark => { '--bs-primary' => '#f28c28' } } ),
        ":root {\n    --bs-primary: #3858a3;\n    --rt-primary-contrast: #fff;\n}\n\n"
            . "[data-bs-theme=dark] {\n    --bs-primary: #f28c28;\n    --rt-primary-contrast: #000;\n}\n",
        'dark contrast derives from the dark primary' );
    is( RT::Interface::Web->ThemePaletteCSS( { light => { '--bs-primary' => 'red' } } ),
        ":root {\n    --bs-primary: red;\n}\n",
        'no contrast derived from a non-hex primary' );
    is( RT::Interface::Web->ThemePaletteCSS( { dark => { '--bs-primary' => '#f28c28', '--rt-primary-contrast' => '#fff' } } ),
        "[data-bs-theme=dark] {\n    --bs-primary: #f28c28;\n    --rt-primary-contrast: #fff;\n}\n",
        'explicit dark contrast is kept' );
    is( RT::Interface::Web->ThemePaletteCSS( {} ), '', 'empty palette renders nothing' );
    is( RT::Interface::Web->ThemePaletteCSS( { light => { '--x' => 'a;b' } } ), '',
        'invalid entries are not rendered' );
    is( RT::Interface::Web->ThemePaletteCSS('plain'), '', 'string palette renders nothing' );
    is( RT::Interface::Web->ThemePaletteCSS( { light => 'x' } ), '', 'non-hash mode renders nothing' );
}

my ( $ok, $msg ) = RT->System->SetAttribute(
    Name        => 'UserLogo',
    Description => 'User-provided logo',
    Content     => { type => 'image/png', data => 'not really a png', hash => 'abc123' },
);
ok( $ok, 'set an uploaded logo' ) or diag $msg;

RT->System->SetAttribute(
    Name        => 'ThemePalette',
    Description => 'Theme editor palette',
    Content     => { light => { '--bs-primary' => '#7a1f8c' } },
);
RT->System->SetAttribute(
    Name        => 'UserCSS',
    Description => 'User-provided css',
    Content     => 'div#body { --usercss-marker: 1; }',
);

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

sub set_stylesheet {
    my ( $m, $style ) = @_;
    $m->get_ok( "$baseurl/Prefs/Other.html", 'load preferences' );
    $m->submit_form_ok(
        {   form_name => 'ModifyPreferences',
            fields    => { WebDefaultStylesheet => $style },
            button    => 'Update',
        },
        "select the $style stylesheet"
    );
    $m->get_ok( "$baseurl/", 'load homepage' );
    like( $m->dom->at('body')->attr('class'), qr/(?:^|\s)\Q$style\E(?:\s|$)/, "body has $style class" );
}

diag 'elevator: default favicon and uploaded logo';
{
    $m->get_ok( "$baseurl/", 'load homepage' );
    my $dom = $m->dom;
    is( $dom->at('link[rel="shortcut icon"]')->attr('href'),
        RT->Config->Get('WebImagesURL') . 'favicon.png', 'default favicon' );
    is( $dom->at('#logo img')->attr('src'),
        RT->Config->Get('WebPath') . '/NoAuth/Helpers/CustomLogo/abc123', 'uploaded logo shown' );
}

diag 'themetest: callback favicon and logo override';
{
    set_stylesheet( $m, 'themetest' );
    my $dom    = $m->dom;
    my $images = RT->Config->Get('WebImagesURL');
    is( $dom->at('link[rel="shortcut icon"]')->attr('href'), $images . 'themetest/favicon.svg',
        'favicon from callback' );
    my @imgs = $dom->find('#logo img')->each;
    is( scalar @imgs, 2, 'large and small logo images' );
    is( $imgs[0]->attr('src'), $images . 'themetest/logo.svg',       'theme logo replaces uploaded logo' );
    is( $imgs[1]->attr('src'), $images . 'themetest/logo-small.svg', 'theme small logo' );
    # Each rejected path, and how the warning shows it (non-printable and
    # non-ASCII characters are logged as \x{...})
    for my $case (
        [ q{https://evil.example/x.ico} => q{https://evil.example/x.ico} ],
        [ q{/static/images/x.png}       => q{/static/images/x.png} ],
        [ q{../../etc/passwd}           => q{../../etc/passwd} ],
        [ q{themetest/../x.svg}         => q{themetest/../x.svg} ],
        [ q{a//b.svg}                   => q{a//b.svg} ],
        [ "x.svg\n"                     => q{x.svg\x{a}} ],
        [ "themetest/\x{e9}.svg"        => q{themetest/\x{e9}.svg} ],
    ) {
        my ( $bad, $shown ) = @$case;
        $m->get_ok( "$baseurl/?ThemeTestFavicon=" . URI::Escape::uri_escape_utf8($bad),
            "load homepage with favicon path $shown" );
        $m->next_warning_like( qr/Ignoring invalid FaviconPath '\Q$shown\E'/, "warning names rejected path $shown" );
        is( $m->dom->at('link[rel="shortcut icon"]')->attr('href'),
            $images . 'favicon.png', "rejected $shown, default favicon used" );
    }

    $m->get_ok( "$baseurl/?ThemeTestFavicon=themetest/sub/icon.v2.svg", 'load homepage with nested favicon path' );
    is( $m->dom->at('link[rel="shortcut icon"]')->attr('href'),
        $images . 'themetest/sub/icon.v2.svg', 'nested favicon path accepted' );

    set_stylesheet( $m, 'elevator' );
}

diag 'spinner: stock under elevator, override under themetest';
{
    $m->get_ok( "$baseurl/", 'load homepage' );
    my $boost = $m->dom->at('#hx-boost-spinner .spinner .rt-boost');
    ok( $boost->at('svg.checkbox-spinner'), 'elevator renders the stock checkbox spinner' );
    ok( !$boost->at('svg.checkbox-spinner rect[stroke]'), 'stock spinner colors come from CSS, not attributes' );

    set_stylesheet( $m, 'themetest' );
    $boost = $m->dom->at('#hx-boost-spinner .spinner .rt-boost');
    my $custom = $boost->at('span.themetest-spinner');
    ok( $custom, 'themetest renders its own spinner inside the boost wrapper' );
    is( $custom->attr('data-size'), '40', 'spinner override receives Size' );
    ok( !$boost->at('svg.checkbox-spinner'), 'stock spinner not rendered when overridden' );
    set_stylesheet( $m, 'elevator' );
}

diag 'palette only under elevator; UserCSS under every stylesheet';
{
    my $user_css_scripts = sub {
        return scalar grep { $_->text =~ /rtUserCssMarker/ } $m->dom->find('head script')->each;
    };
    my $palette_css = RT::Interface::Web->ThemePaletteCSS( { light => { '--bs-primary' => '#7a1f8c' } } );

    $m->get_ok( "$baseurl/", 'load homepage' );
    my $sitecss = $m->dom->at('style#sitecss')->text;
    like( $sitecss, qr/\Q:root {\E\s*\Q--bs-primary: #7a1f8c;\E\s*\Q--rt-primary-contrast: #fff;\E\s*\}/, 'palette rendered under elevator' );
    like( $sitecss, qr/\Qdiv#body { --usercss-marker: 1; }\E/, 'UserCSS rendered under elevator' );
    ok( index( $sitecss, '--bs-primary' ) < index( $sitecss, '--usercss-marker' ), 'UserCSS follows the palette' );

    set_stylesheet( $m, 'themetest' );
    is( $m->dom->at('style#sitecss')->text =~ s/^\s+|\s+$//gr, 'div#body { --usercss-marker: 1; }',
        'only UserCSS rendered under another stylesheet' );

    my $script_trick = qq{div#body { --usercss-marker: 1; }\n</style><script>window.rtUserCssMarker = 1;</script><style>\n.after-script { --after: 1; }};
    RT->System->SetAttribute( Name => 'UserCSS', Description => 'User-provided css', Content => $script_trick );

    $m->get_ok( "$baseurl/", 'load homepage with UserCSS that adds a script' );
    is( $user_css_scripts->(), 1, 'UserCSS script element rendered under themetest' );
    is( $m->dom->at('style#sitecss')->text =~ s/^\s+|\s+$//gr, 'div#body { --usercss-marker: 1; }',
        'sitecss holds the CSS before the script under themetest' );

    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor under themetest' );
    is( $m->dom->at('form#ThemePalette')->attr('data-saved-css'), "div#body { --usercss-marker: 1; }\n",
        'saved CSS under themetest is the CSS part of UserCSS only' );

    set_stylesheet( $m, 'elevator' );
    is( $user_css_scripts->(), 1, 'UserCSS script element rendered under elevator' );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor under elevator' );
    is( $m->dom->at('form#ThemePalette')->attr('data-saved-css'), "$palette_css\ndiv#body { --usercss-marker: 1; }\n",
        'saved CSS under elevator is the palette and the CSS part of UserCSS' );

    RT->System->SetAttribute( Name => 'UserCSS', Description => 'User-provided css', Content => qq{a { color: red; }</STYLE ><script></script>} );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor with an uppercase closing tag' );
    is( $m->dom->at('form#ThemePalette')->attr('data-saved-css'), "$palette_css\na { color: red; }",
        'closing style tag matched case-insensitively' );

    RT->System->SetAttribute( Name => 'UserCSS', Description => 'User-provided css', Content => 'div#body { --usercss-marker: 1; }' );
}

diag 'theme editor layout: tabs, fields, placeholders and labels';
{
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor' );
    my $dom = $m->dom;

    is_deeply(
        [ map { [ $_->attr('href'), $_->all_text =~ s/^\s+|\s+$//gr ] } $dom->find('#theme-tabs a.nav-link[data-bs-toggle="tab"]')->each ],
        [ [ '#theme-basic', 'Basic' ], [ '#theme-advanced', 'Advanced' ], [ '#theme-custom-css', 'Custom CSS' ] ],
        'three tabs in order'
    );
    is( $dom->at('#theme-tabs a.nav-link.active')->attr('href'), '#theme-basic', 'Basic tab active by default' );
    ok( $dom->at('form#ThemePalette > #theme-basic.tab-pane.active'),         'Basic pane in the palette form, active' );
    ok( $dom->at('form#ThemePalette > #theme-advanced.tab-pane:not(.active)'), 'Advanced pane in the palette form' );
    ok( $dom->at('#theme-custom-css.tab-pane:not(.active) form#custom-css-form'), 'Custom CSS form in its own pane' );
    ok( !$dom->at('#palette-dark'), 'no dark-mode expander' );

    my @basic = $dom->find('#theme-basic .palette-row')->each;
    is_deeply( [ map { $_->attr('data-property') } @basic ],
        [qw(--bs-primary --rt-secondary --rt-tertiary)], 'Basic tab has primary, secondary, tertiary' );
    is_deeply(
        [ map { $_->at('.palette-hint')->text } @basic ],
        [ 'Buttons, widget titles, focus rings', 'Page title underline, table headers', 'Headings, footer' ],
        'Basic rows have hints'
    );

    is_deeply(
        [ map { $_->attr('data-property') } $dom->find('#theme-advanced .palette-row')->each ],
        [   qw(--rt-primary-contrast --bs-link-color --bs-link-hover-color --rt-page-header-border-color
                --rt-table-header-border-color --bs-heading-color --rt-widget-title-color --rt-menu-bg
                --rt-menu-color --rt-menu-hover-bg --rt-footer-bg --rt-footer-color)
        ],
        'Advanced tab fields in order'
    );

    my $field = sub {
        my ( $mode, $name ) = @_;
        return $dom->at(qq{form#ThemePalette input.palette-value[name="palette.$mode.$name"]});
    };
    my %light_placeholder = (
        '--bs-primary'                   => 'default',
        '--rt-primary-contrast'          => 'automatic',
        '--bs-link-color'                => 'default',
        '--rt-page-header-border-color'  => 'from Secondary',
        '--rt-table-header-border-color' => 'from Secondary',
        '--bs-heading-color'             => 'from Tertiary',
        '--rt-widget-title-color'        => 'from Primary',
        '--rt-menu-hover-bg'             => 'from Primary',
        '--rt-footer-bg'                 => 'from Tertiary',
    );
    for my $name ( sort keys %light_placeholder ) {
        is( $field->( light => $name )->attr('placeholder'), $light_placeholder{$name}, "light $name placeholder" );
    }
    is( $field->( dark => '--bs-primary' )->attr('placeholder'), 'derived', 'dark shared property placeholder' );
    is( $field->( dark => '--rt-menu-bg' )->attr('placeholder'), 'default', 'dark mode-specific property placeholder' );

    is( $field->( light => '--bs-primary' )->attr('aria-label'), 'Primary color (light mode)', 'light text field label' );
    is( $field->( dark => '--rt-footer-color' )->attr('aria-label'), 'Footer text (dark mode)', 'dark text field label' );
    is( $dom->at('form#ThemePalette input.palette-picker[data-mode="dark"][data-property="--bs-primary"]')->attr('aria-label'),
        'Color picker for Primary color (dark mode)', 'picker label' );

    ok( $dom->at('form#ThemePalette > .theme-palette-actions #preview-mode'),                  'preview toggle below the panes' );
    ok( $dom->at('form#ThemePalette > .theme-palette-actions input[name="save_palette"]'), 'save button below the panes' );
}

diag 'logo color swatches carry hex values';
{
    my $logo = { type => 'image/png', data => 'not really a png', hash => 'abc123' };
    RT->System->SetAttribute(
        Name        => 'UserLogo',
        Description => 'User-provided logo',
        Content     => { %$logo, colors => [ { c => '255,128,0' }, { c => '7,8,9' } ] },
    );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor with cached logo colors' );
    is_deeply( [ map { $_->attr('data-color') } $m->dom->find('button.color-swatch')->each ],
        [ '#ff8000', '#070809' ], 'swatches use hex colors' );

    RT->System->SetAttribute( Name => 'UserLogo', Description => 'User-provided logo', Content => $logo );
}

diag 'theme editor saves, merges and resets the palette';
{
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor' );
    is( $m->dom->at('form#ThemePalette input[name="palette.light.--bs-primary"]')->attr('value'),
        '#7a1f8c', 'stored light value shown' );

    $m->submit_form_ok(
        {   form_id => 'ThemePalette',
            fields  => {
                'palette.light.--bs-primary' => '#b4470b',
                'palette.dark.--bs-primary'  => '#f28c28',
                'theme_tab'                  => 'advanced',
            },
            button => 'save_palette',
        },
        'save palette'
    );
    is( $m->dom->at('#theme-tabs a.nav-link.active')->attr('href'), '#theme-advanced', 'tab saved from stays active' );
    ok( $m->dom->at('#theme-advanced.tab-pane.active'), 'Advanced pane active after save' );

    my $assert_basic_active = sub {
        my $what = shift;
        my $dom  = $m->dom;
        is( $dom->at('#theme-tabs a.nav-link.active')->attr('href'), '#theme-basic', "Basic tab active $what" );
        is_deeply( [ map { $_->attr('id') } $dom->find('#customize-theme .tab-pane.active')->each ],
            ['theme-basic'], "only the Basic pane active $what" );
    };
    for my $case ( [ basic => 'after saving from Basic' ], [ bogus => 'after saving with an unknown tab' ] ) {
        my ( $tab, $what ) = @$case;
        $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
        $m->submit_form_ok( { form_id => 'ThemePalette', fields => { theme_tab => $tab }, button => 'save_palette' },
            "save palette with theme_tab $tab" );
        $assert_basic_active->($what);
    }
    RT->System->Attributes->RedoSearch;
    my $saved = RT->System->FirstAttribute('ThemePalette')->Content;
    is_deeply( $saved, { light => { '--bs-primary' => '#b4470b' }, dark => { '--bs-primary' => '#f28c28' } },
        'palette stored' );

    RT->System->SetAttribute(
        Name        => 'ThemePalette',
        Description => 'Theme editor palette',
        Content     => { light => { '--bs-primary' => '#b4470b', '--my-company-color' => '#123456' } },
    );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok(
        {   form_id => 'ThemePalette',
            fields  => { 'palette.light.--bs-primary' => '' },
            button  => 'save_palette',
        },
        'clear a field'
    );
    RT->System->Attributes->RedoSearch;
    is_deeply( RT->System->FirstAttribute('ThemePalette')->Content,
        { light => { '--my-company-color' => '#123456' } },
        'cleared field removed, value for a name not in the editor kept' );

    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok(
        {   form_id => 'ThemePalette',
            fields  => { 'palette.light.--bs-primary' => 'red; }' },
            button  => 'save_palette',
        },
        'save an unsafe value'
    );
    $m->text_contains( 'Invalid value for theme property --bs-primary', 'unsafe value reported' );
    $m->text_contains( 'Some theme colors were not saved', 'partial save reported' );
    $m->content_lacks( 'Theme colors saved', 'no success message when a value was rejected' );

    diag 'a rejected value keeps the stored value; valid changes still save';
    RT->System->SetAttribute(
        Name        => 'ThemePalette',
        Description => 'Theme editor palette',
        Content     => { light => { '--bs-primary' => '#b4470b' } },
    );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok(
        {   form_id => 'ThemePalette',
            fields  => { 'palette.light.--bs-primary' => 'red; }', 'palette.light.--rt-secondary' => '#5b2a86' },
            button  => 'save_palette',
        },
        'save one unsafe and one valid value'
    );
    $m->text_contains( 'Invalid value for theme property --bs-primary', 'unsafe value reported' );
    $m->text_contains( 'Some theme colors were not saved', 'partial save reported' );
    RT->System->Attributes->RedoSearch;
    is_deeply(
        RT->System->FirstAttribute('ThemePalette')->Content,
        { light => { '--bs-primary' => '#b4470b', '--rt-secondary' => '#5b2a86' } },
        'stored value kept for rejected entry, valid entry saved'
    );

    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok( { form_id => 'ThemePalette', button => 'save_palette' }, 'save without changes' );
    $m->text_contains( 'Theme colors saved', 'success reported when nothing rejected' );

    diag 'an empty dark field removes the stored dark value';
    RT->System->SetAttribute(
        Name        => 'ThemePalette',
        Description => 'Theme editor palette',
        Content     => { light => { '--bs-primary' => '#b4470b' }, dark => { '--bs-primary' => '#f28c28' } },
    );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok(
        {   form_id => 'ThemePalette',
            fields  => { 'palette.dark.--bs-primary' => '' },
            button  => 'save_palette',
        },
        'clear a dark field'
    );
    RT->System->Attributes->RedoSearch;
    is_deeply( RT->System->FirstAttribute('ThemePalette')->Content,
        { light => { '--bs-primary' => '#b4470b' } }, 'dark value removed' );

    diag 'stored palette that is not a hash renders as empty';
    for my $bad ( ['not a hash'], { light => 'nope', dark => ['x'] } ) {
        RT->System->SetAttribute(
            Name        => 'ThemePalette',
            Description => 'Theme editor palette',
            Content     => $bad,
        );
        $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor with malformed palette' );
        is( $m->dom->at('form#ThemePalette input[name="palette.light.--bs-primary"]')->attr('value'),
            '', 'light field empty' );
        is( $m->dom->at('form#ThemePalette input[name="palette.dark.--bs-primary"]')->attr('value'),
            '', 'dark field empty' );
    }
    RT->System->SetAttribute(
        Name        => 'ThemePalette',
        Description => 'Theme editor palette',
        Content     => { light => { '--bs-primary' => '#7a1f8c' } },
    );

    diag 'notice shown when the admin is not using the elevator stylesheet';
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor' );
    ok( !$m->dom->at('#customize-theme > .alert'), 'no notice under elevator' );
    set_stylesheet( $m, 'themetest' );
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor' );
    is( $m->dom->at('#customize-theme > .alert')->text,
        q{These colors apply to RT's default theme. You are currently using the themetest theme, so the preview below won't match what other users see.},
        'notice names the current theme'
    );
    set_stylesheet( $m, 'elevator' );

    diag 'Custom CSS Save stores UserCSS';
    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'load theme editor' );
    $m->submit_form_ok(
        {   form_id => 'custom-css-form',
            fields  => { user_css => 'div#body { --saved-marker: 2; }' },
            button  => undef,
        },
        'save custom css'
    );
    is( $m->dom->at('#theme-tabs a.nav-link.active')->attr('href'), '#theme-custom-css', 'Custom CSS tab active after saving custom CSS' );
    RT->System->Attributes->RedoSearch;
    is( RT->System->FirstAttribute('UserCSS')->Content, 'div#body { --saved-marker: 2; }', 'UserCSS stored' );

    $m->get_ok( "$baseurl/Admin/Tools/Theme.html", 'reload theme editor' );
    $m->submit_form_ok( { form_id => 'custom-css-form', button => 'reset_css' }, 'reset to default theme' );
    is( $m->dom->at('#theme-tabs a.nav-link.active')->attr('href'), '#theme-custom-css', 'Custom CSS tab active after reset' );
    RT->System->Attributes->RedoSearch;
    ok( !RT->System->FirstAttribute('ThemePalette'), 'palette removed by reset' );
    ok( !RT->System->FirstAttribute('UserCSS'),      'UserCSS removed by reset' );
}

done_testing;
