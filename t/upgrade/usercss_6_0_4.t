use strict;
use warnings;

use RT::Test tests => undef;

# Exercises the 6.0.4 upgrade step in etc/upgrade/6.0.4/content that removes
# the earlier theme editor's empty rules from UserCSS, moves its portlet title
# color to ThemePalette, and keeps everything else as written.

my $content = "$RT::EtcPath/upgrade/6.0.4/content";
ok( -e $content, "Found upgrade content file at $content" );

my $run_step = sub {
    # InsertData loads Perl data files with require, so a second run in
    # this process would otherwise do nothing.
    delete $INC{ Cwd::abs_path($content) };
    my ( $rv, $msg ) = RT->DatabaseHandle->InsertData( $content, undef, disconnect_after => 0 );
    ok( $rv, 'ran 6.0.4 upgrade step' ) or diag "Error: $msg";
};

my $attribute = sub {
    my $name = shift;
    RT->System->ClearAttributes;
    my $attr = RT->System->FirstAttribute($name);
    return $attr ? $attr->Content : undef;
};

# Each case starts with only the given UserCSS and ThemePalette.
my $setup = sub {
    my %args = @_;
    RT->System->DeleteAttribute($_) for qw(UserCSS UserCSSBackup-6.0.4 ThemePalette);
    RT->System->SetAttribute( Name => 'UserCSS', Description => 'User-provided css', Content => $args{UserCSS} )
        if defined $args{UserCSS};
    RT->System->SetAttribute( Name => 'ThemePalette', Description => 'Theme editor palette', Content => $args{ThemePalette} )
        if defined $args{ThemePalette};
};

my $nav = '#main-navigation #app-nav > li, #main-navigation #app-nav > li > a, #prefs-menu > li, #prefs-menu > li > a, #logo .rtname';
( my $nav_42 = $nav ) =~ s/#app-nav/#app-nav.sf-shadow/g;
( my $nav_40 = $nav ) =~ s/(#main-navigation)/body.aileron $1/g;
my $buttons = sub { qq{input[type="reset"], input[type="submit"], input[class="$_[0]"]} };
my $hover   = sub { qq{input[type="reset"]:hover, input[type="submit"]:hover, input[class="$_[0]"]:hover} };
my $portlet = '.titlebox .titlebox-title .left a, .titlebox .titlebox-title .left';
my $buttons_60 = $buttons->('btn');
my $hover_60   = $hover->('btn');

# The section lists of Admin/Tools/Theme.html in each release that changed them.
my %sections = (
    '4.0' => [
        [ 'Page'         => ['body'] ],
        [ 'Header'       => [ 'div#quickbar', $nav_40 ] ],
        [ 'Page title'   => ['div#header h1'] ],
        [ 'Page content' => ['div#body'] ],
        [ 'Buttons'      => [ $buttons->('button') ] ],
        [ 'Button hover' => [ $hover->('button') ] ],
    ],
    '4.2' => [
        [ 'Page'         => [ 'body', 'div#body' ] ],
        [ 'Menu bar'     => [ 'div#quickbar', $nav_42 ] ],
        [ 'Title bar'    => ['div#header'] ],
        [ 'Page title'   => ['div#header h1'] ],
        [ 'Page content' => ['div#body'] ],
        [ 'Buttons'      => [ $buttons->('button') ] ],
        [ 'Button hover' => [ $hover->('button') ] ],
    ],
);
$sections{'4.4.4'} = [
    @{ $sections{'4.2'} },
    [ 'Search results' => ['table.collection-as-table th.collection-as-table a'] ],
    [ 'Portlet Text'   => [$portlet] ],
];
$sections{'5.0'} = [
    ( map { $_->[0] eq 'Page content' ? [ 'Page content' => ['div#body, .body-content-class'] ] : $_ } @{ $sections{'4.4.4'} } ),
    [ 'Selected bubble'          => ['.selectize-control.multi .selectize-input [data-value]'] ],
    [ 'Selected bubble (active)' => ['.selectize-control.multi .selectize-input [data-value].active'] ],
];
$sections{'6.0'} = [
    map {
          $_->[0] eq 'Menu bar'                 ? [ 'Menu bar'     => [ 'div#quickbar', $nav ] ]
        : $_->[0] eq 'Buttons'                  ? [ 'Buttons'      => [ $buttons->('btn') ] ]
        : $_->[0] eq 'Button hover'             ? [ 'Button hover' => [ $hover->('btn') ] ]
        : $_->[0] eq 'Selected bubble'          ? [ 'Selected bubble' => ['.ts-wrapper.multi .ts-control > .item'] ]
        : $_->[0] eq 'Selected bubble (active)' ? [ 'Selected bubble (active)' => ['.ts-wrapper.multi .ts-control > .item.active'] ]
        :                                         $_
    } @{ $sections{'5.0'} }
];

# What the editor put in the Custom CSS box before any color was picked.
my $default_box = sub {
    my $version = shift;
    return join "\n\n", map {
        my ( $name, $selectors ) = @$_;
        join "\n", "/* $name */", map {"$_ {}"} @$selectors;
    } @{ $sections{$version} };
};

my $editor_comment = <<'CSS';
/* These colors were set with the theme editor in an earlier version of
 * RT. They override the colors on the Basic and Advanced tabs of the
 * Theme page; remove them once those colors are set there. */
CSS
my $custom_comment = <<'CSS';
/* These styles were copied from an earlier version of RT. The CSS as it
 * was before the upgrade to RT 6.0.4 is kept in the UserCSSBackup-6.0.4
 * attribute. */
CSS

diag 'no UserCSS: nothing to do';
{
    $setup->();
    $run_step->();
    is( $attribute->('UserCSS'),             undef, 'no UserCSS created' );
    is( $attribute->('UserCSSBackup-6.0.4'), undef, 'no backup created' );
    is( $attribute->('ThemePalette'),        undef, 'no palette created' );
}

diag 'default box from each editor version: UserCSS removed, original backed up';
for my $version ( '4.0', '4.2', '4.4.4', '5.0', '6.0' ) {
    my $box = $default_box->($version);
    $setup->( UserCSS => $box );
    $run_step->();
    is( $attribute->('UserCSS'),             undef, "$version: UserCSS deleted" );
    is( $attribute->('UserCSSBackup-6.0.4'), $box,  "$version: backup holds the original" );
    is( $attribute->('ThemePalette'),        undef, "$version: no palette created" );
}

diag 'editor colors are kept as written under the editor comment';
{
    my $css = <<"CSS";
/* Page */
body { background: #ffffff }
div#body, .body-content-class { background: rgb(240, 240, 240); color: rgb(0, 0, 0) }

/* Menu bar */
div#quickbar { background: rgb(4, 108, 68); color: rgb(255, 255, 255); border: none; }
$nav {}

/* Title bar */
div#header { background: #123; color: #fff }

/* Buttons */
$buttons_60 { background: #f55f0a; color: }

/* Button hover */
$hover_60 {}
CSS
    $setup->( UserCSS => $css );
    $run_step->();
    is( $attribute->('UserCSS'), $editor_comment . <<"CSS", 'colored editor rules kept in order, stubs and section comments removed' );
body { background: #ffffff }
div#body, .body-content-class { background: rgb(240, 240, 240); color: rgb(0, 0, 0) }
div#quickbar { background: rgb(4, 108, 68); color: rgb(255, 255, 255); border: none; }
div#header { background: #123; color: #fff }
$buttons_60 { background: #f55f0a; color: }
CSS
    is( $attribute->('UserCSSBackup-6.0.4'), $css, 'backup holds the original' );
}

diag 'portlet title color moves to the palette';
{
    my $css = <<"CSS";
/* Page */
body {}

/* Portlet Text */
$portlet { /* color: #212934; */ color: #6a459b; }
CSS
    $setup->( UserCSS => $css, ThemePalette => { dark => { '--bs-primary' => '#111111' } } );
    $run_step->();
    is( $attribute->('UserCSS'), undef, 'nothing left in UserCSS' );
    is_deeply(
        $attribute->('ThemePalette'),
        { light => { '--rt-widget-title-color' => '#6a459b' }, dark => { '--bs-primary' => '#111111' } },
        'widget title color added to the light palette; other values untouched'
    );
    is( $attribute->('UserCSSBackup-6.0.4'), $css, 'backup holds the original' );
}

diag 'portlet title color stays in UserCSS when the palette already sets it';
{
    my $css     = "$portlet { color: rgb(0, 122, 159) }\n";
    my $palette = { light => { '--rt-widget-title-color' => '#000000' } };
    $setup->( UserCSS => $css, ThemePalette => $palette );
    $run_step->();
    is( $attribute->('UserCSS'), $editor_comment . $css, 'portlet rule kept as an editor rule' );
    is_deeply( $attribute->('ThemePalette'), $palette, 'palette unchanged' );
}

diag 'hand-edited and dead editor rules are copied unchanged';
{
    my $hand = <<"CSS";
body { font-family: Arial, sans-serif; }
.selectize-control.multi .selectize-input [data-value] {
background-image: linear-gradient(to bottom,#6b459b,#6b459b);
}
$nav_42 { color: #ffffff }
$nav_40 { color: rgb(255, 255, 255) }
.selectize-control.multi .selectize-input [data-value].active { background: rgb(4, 108, 68); color: rgb(255, 255, 255) }
div#header h1 { color: red }
$portlet { /* color: #212934; */ }
CSS
    $setup->( UserCSS => "/* Page */\ndiv#body {}\n\n" . $hand );
    $run_step->();
    chomp( my $expected = $hand );
    is( $attribute->('UserCSS'), $custom_comment . $expected . "\n", 'every rule moved unchanged to the custom section' );
    is( $attribute->('ThemePalette'), undef, 'no palette created' );
}

diag 'custom CSS keeps its comments, nesting, at-rules and strings';
{
    my $custom = <<'CSS';
/* Hide fields we don't use */
#UpdateBcc { display: none; }
.note::before { content: "} body {"; }

@media print {
    #header { display: none; }
}
html:not([data-bs-theme="dark"]) {
    .messagebox { color: #333; }
}
CSS
    $setup->( UserCSS => <<"CSS" . $custom . "\n/* Buttons */\n" . $buttons_60 . " {}\n" );
/* Page */
body { background: #eeeeee }
div#body {}

/* Title bar */
div#header {}

CSS
    $run_step->();
    chomp( my $expected = $custom );
    is( $attribute->('UserCSS'), $editor_comment . "body { background: #eeeeee }\n\n" . $custom_comment . $expected . "\n",
        'editor rule first, then custom CSS verbatim' );
}

diag 'CRLF line endings, as saved from the browser form';
{
    my $css = join "\r\n", '/* Page */', 'body {}', 'div#body {}', '', '.current-user {', '   color: white', '}', '',
        '/* Title bar */', 'div#header { background: #fcfefc; color: #000 }', '',
        '/* Selected bubble */', '.selectize-control.multi .selectize-input [data-value] { background: #046c44 }', '';
    $setup->( UserCSS => $css );
    $run_step->();
    ( my $editor = $editor_comment ) =~ s/\n/\r\n/g;
    ( my $custom = $custom_comment ) =~ s/\n/\r\n/g;
    is( $attribute->('UserCSS'),
        $editor . "div#header { background: #fcfefc; color: #000 }\r\n\r\n"
            . $custom . ".current-user {\r\n   color: white\r\n}\r\n\r\n"
            . ".selectize-control.multi .selectize-input [data-value] { background: #046c44 }\r\n",
        'no gaps left and the new comments use CRLF' );
}

diag 'a closing style tag and what follows are kept at the end';
{
    my $tail = qq{</style><script>window.marker = 1;</script><style>\n};
    $setup->( UserCSS => "/* Page */\nbody {}\n.unrelated { color: blue; }\n" . $tail );
    $run_step->();
    is( $attribute->('UserCSS'), $custom_comment . ".unrelated { color: blue; }\n" . $tail, 'tail appended unchanged' );

    $setup->( UserCSS => "/* Page */\nbody {}\n" . $tail . "/* Page */\nbody {}\n" );
    $run_step->();
    is( $attribute->('UserCSS'), $tail . "/* Page */\nbody {}\n", 'only the tail is left; nothing after the closing tag is changed' );
}

diag 'CSS with no theme editor rules is left alone';
{
    my $css = ".unrelated { color: blue; }\n/* Hidden */\n#UpdateBcc { display: none; }\n";
    $setup->( UserCSS => $css );
    $run_step->();
    is( $attribute->('UserCSS'),             $css,  'UserCSS unchanged' );
    is( $attribute->('UserCSSBackup-6.0.4'), undef, 'no backup needed' );
}

diag 'CSS with an @import is left alone';
{
    my $css = qq{\@import url("https://example.com/site.css");\n/* Page */\nbody {}\n};
    $setup->( UserCSS => $css );
    $run_step->();
    is( $attribute->('UserCSS'),             $css,  'UserCSS unchanged' );
    is( $attribute->('UserCSSBackup-6.0.4'), undef, 'no backup' );
}

diag 'running the step again changes nothing';
{
    my $css = "/* Page */\nbody { background: #ffffff }\ndiv#body {}\n.unrelated { color: blue; }\n";
    $setup->( UserCSS => $css );
    $run_step->();
    my $first = $attribute->('UserCSS');
    is( $first, $editor_comment . "body { background: #ffffff }\n\n" . $custom_comment . ".unrelated { color: blue; }\n",
        'first run result' );
    $run_step->();
    is( $attribute->('UserCSS'),             $first, 'second run leaves UserCSS as it was' );
    is( $attribute->('UserCSSBackup-6.0.4'), $css,   'backup still holds the original' );
}

done_testing;
