use warnings;
use strict;

use RT::Test nodata => 1, tests => 11;
use RT::I18N;

my %map = (
    'euc-cn'  => 'gbk',
    'gb-2312' => 'gbk',
    gb2312  => 'gbk',
    utf8    => 'utf-8',
    'utf-8' => 'utf-8',
);

for my $charset ( keys %map ) {
    is( RT::I18N::_CanonicalizeCharset($charset),
        $map{$charset}, "$charset => $map{$charset}" );
    is( RT::I18N::_CanonicalizeCharset( uc $charset ),
        $map{$charset}, uc( $charset ) . " => $map{$charset}" );
}

my $mime   = MIME::Entity->build(
    Type => 'text/plain; charset=gb2312',
    Data => [Encode::encode("gbk", Encode::decode( "UTF-8", "法新社倫敦11日電"))],
);

RT::I18N::SetMIMEEntityToUTF8($mime);
is( $mime->stringify_body, '法新社倫敦11日電', 'gb2312 => gbk in mail'  );

