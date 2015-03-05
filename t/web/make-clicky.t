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
    my $url = 'http://bestpractical.com/rt/download.html?foo=bar,baz&bat=1.2';
    my $escaped_url = $url;
    RT::Interface::Web::EscapeHTML( \$escaped_url );
    is_string(
        make_clicky($m, "Refer to $url.  A following sentence."),
        qq[Refer to <span class="clickylink"><a target="_blank" href="$escaped_url">$escaped_url</a></span>.  A following sentence.],
        "Punctuation in middle of URL",
    );
}

sub make_clicky {
    my $m    = shift;
    my $text = shift;
    RT::Interface::Web::EscapeURI(\$text);
    $m->get_ok("/makeclicky?content=$text", "made clicky")
        or diag $m->status;
    return $m->success ? $m->content : "";
}

undef $m;
done_testing();
