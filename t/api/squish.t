use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => undef;
use Test::Warn;

use RT::Squish;

my $squish;
warning_like {
    $squish = RT::Squish->new();
} [qr/implement/], "warns this is only an abstract base class";

for my $method ( qw/Content ModifiedTime ModifiedTimeString Key/ ) {
    can_ok($squish, $method);
}
like( $squish->Key, qr/[a-f0-9]{32}/, 'Key is like md5' );
ok( (time()-$squish->ModifiedTime) <= 2, 'ModifiedTime' );

use RT::Squish::CSS;
can_ok('RT::Squish::CSS', 'Style');

# CSS::Minifier::XS strips the unit from bare "0px", turning the
# --ts-pr-clear-button / --ts-pr-caret defaults into unitless 0. Once they are
# substituted into max(var(--ts-pr-min), var(--ts-pr-clear-button) + var(--ts-pr-caret))
# in tom-select.bootstrap5.css, "0 + 0" resolves to a <number> and mixing that
# with a <length> makes max() type-invalid, so the padding-right declaration is
# dropped and the select text overlaps the caret. The missing-caret.patch wraps
# the zero-valued defaults in calc() so the unit survives minification.
{
    my $css = RT::Squish::CSS->new( Style => 'elevator' )->Content;

    like( $css, qr/\Q--ts-pr-clear-button:calc(0px)\E/, '--ts-pr-clear-button keeps its unit after minification' );
    like( $css, qr/\Q--ts-pr-caret:calc(0px)\E/,        '--ts-pr-caret keeps its unit after minification' );

    unlike( $css, qr/--ts-pr-clear-button:0[;}]/, '--ts-pr-clear-button is not minified to a unitless 0' );
    unlike( $css, qr/--ts-pr-caret:0[;}]/,        '--ts-pr-caret is not minified to a unitless 0' );
}

done_testing;
