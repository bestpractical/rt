use strict;
use warnings;

use RT::Test
    tests   => 'no_declare',
    plugins => ["MakeClicky"],
    config  => 'Set( @Active_MakeClicky => "httpurl_overwrite" );';

use Test::LongString;

my ($base, $m) = RT::Test->started_ok;
$m->login;
$m->get_ok("/");

diag "Trailing punctuation";
{
    my $url = 'http://bestpractical.com/rt';
    for my $punc (qw( . ! ? ), ",") {
        is_string(
            make_clicky($m, "Refer to $url$punc  A following sentence."),
            qq[Refer to <span class="clickylink"><a target="_blank" href="$url">$url</a></span>$punc  A following sentence.],
            "$punc not included in url",
        );
    }
}

diag "Punctuation as part of the url";
{
    my $url = 'http://bestpractical.com/rt/download.html?foo=bar,baz.2';
    is_string(
        make_clicky($m, "Refer to $url.  A following sentence."),
        qq[Refer to <span class="clickylink"><a target="_blank" href="$url">$url</a></span>.  A following sentence.],
        "Punctuation in middle of URL",
    );
}

diag "Anchor in URL";
{
    my $url = 'http://wiki.bestpractical.com/test#anchor';
    is_string(
        make_clicky($m, "Anchor $url here"),
        qq[Anchor <span class="clickylink"><a target="_blank" href="$url">$url</a></span> here],
        "Captured anchor in URL",
    );
}

diag "Query parameters in URL";
for my $html (0, 1) {
    my $url = "https://wiki.bestpractical.com/?q=test&search=1";
    my $escaped_url = $url;
    RT::Interface::Web::EscapeHTML( \$escaped_url );
    is_string(
        make_clicky($m, $html ? $escaped_url : $url, $html),
        qq[<span class="clickylink"><a target="_blank" href="$escaped_url">$escaped_url</a></span>],
        "Single escaped @{[$html ? 'HTML' : 'text']} query parameters",
    );
}

diag "Found in href";
{
    my $url = '<a href="http://bestpractical.com/rt">Best Practical</a>';
    is_string( make_clicky($m, $url, 1), $url, "URL in existing href is a no-op" );
}

diag "Found in other attribute";
{
    my $url = '<img src="http://bestpractical.com/rt" alt="Some image" />';
    is_string( make_clicky($m, $url, 1), $url, "URL in image src= is a no-op" );
}

diag "Do not double encode &amp test";
{
    my $url = 'http://bestpractical.com/search?q=me&amp;irene;token=foo';
    my $string = qq[<span class="clickylink"><a target="_blank" href="http://bestpractical.com/search?q=me&amp;irene;token=foo">http://bestpractical.com/search?q=me&amp;irene;token=foo</a></span>];
    is_string( make_clicky($m,$url, 1), $string, "URL with &amp; should not rencode" );

}

sub make_clicky {
    my $m    = shift;
    my $text = shift;
    my $html = shift || 0;
    RT::Interface::Web::EscapeURI(\$text);
    $m->get_ok("/makeclicky?content=$text&html=$html", "made clicky")
        or diag $m->status;
    return $m->success ? $m->content : "";
}

done_testing();
