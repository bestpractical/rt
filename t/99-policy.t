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
    elsif ( $type eq 'devel' ) {
        like(
            $content,
            qr{^#!/usr/bin/env perl},
            $File::Find::name . ' has shebang'
        );
        is( $mode, '0755', $File::Find::name . ' permission is 0755' );
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
    'sbin',
);

find(
    sub {
        return unless -f && $_ !~ m{/(localhost\.(crt|key)|mime\.types)$};
        check( $_, 'devel' );
    },
    'devel/tools',
);
