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
    my $executable = ( stat $file )[2] & 0100;
    if ( $type eq 'script' ) {
        like( $content, qr/^#!/, $File::Find::name . ' has shebang' );
        if ( $file =~ /\.in/ ) {
            ok( !$executable, $File::Find::name . ' permission is not u+x' );
        }
        else {
            ok( $executable, $File::Find::name . ' permission is u+x' );
        }
    }
    elsif ( $type eq 'devel' ) {
        like(
            $content,
            qr{^#!/usr/bin/env perl},
            $File::Find::name . ' has shebang'
        );
        ok( $executable, $File::Find::name . ' permission is u+x' );
    }
    else {
        unlike( $content, qr/^#!/, $File::Find::name . ' has no shebang' );
        ok( !$executable, $File::Find::name . ' permission is not u+x' );
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
