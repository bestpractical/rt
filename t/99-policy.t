use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;

sub check {
    my $file = shift;
    my $type = shift;

    local $/;
    open my $fh, '<', $file or die $!;
    my $content = <$fh>;
    like(
        $content,
        qr/^use strict(?:;|\s+)/m,
        $File::Find::name . ' has "use strict"'
    );
    like(
        $content,
        qr/^use warnings(?:;|\s+)/m,
        $File::Find::name . ' has "use warnings"'
    );
    my $mode = sprintf( '%04o', ( stat $file )[2] & 07777 );
    if ( $type eq 'script' ) {
        like( $content, qr/^#!/, $File::Find::name . ' has shebang' );
        if ( $file =~ /\.in/ ) {
            is( $mode, '0644', $File::Find::name . ' permission is 0644' );
        }
        else {
            is( $mode, '0754', $File::Find::name . ' permission is 0754' );
        }
    }
    else {
        unlike( $content, qr/^#!/, $File::Find::name . ' has no shebang' );
        is( $mode, '0644', $File::Find::name . ' permission is 0644' );
    }
}

find(
    sub {
        return unless -f && /\.pm$/;
        check( $_, 'lib' );
    },
    'lib',
);

find(
    sub {
        return unless -f && /\.t$/;
        check( $_, 'test' );
    },
    't',
);

find(
    sub {
        return unless -f;
        check( $_, 'script' );
    },
    'bin',
    'sbin'
);

