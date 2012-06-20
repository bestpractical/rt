use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;

sub check {
    my $file = shift;
    my %check = (
        strict   => 0,
        warnings => 0,
        shebang  => 0,
        exec     => 0,
        @_,
    );

    if ($check{strict} or $check{warnings} or $check{shebang}) {
        local $/;
        open my $fh, '<', $file or die $!;
        my $content = <$fh>;

        like(
            $content,
            qr/^use strict(?:;|\s+)/m,
            "$File::Find::name has 'use strict'"
        ) if $check{strict};

        like(
            $content,
            qr/^use warnings(?:;|\s+)/m,
            "$File::Find::name has 'use warnings'"
        ) if $check{warnings};

        if ($check{shebang} == 1) {
            like( $content, qr/^#!/, "$File::Find::name has shebang" );
        } elsif ($check{shebang} == -1) {
            unlike( $content, qr/^#!/, "$File::Find::name has no shebang" );
        }
    }

    my $executable = ( stat $file )[2] & 0100;
    if ($check{exec} == 1) {
        if ( $file =~ /\.in$/ ) {
            ok( !$executable, "$File::Find::name permission is u-x (.in will add +x)" );
        } else {
            ok( $executable, "$File::Find::name permission is u+x" );
        }
    } elsif ($check{exec} == -1) {
        ok( !$executable, "$File::Find::name permission is u-x" );
    }
}

find(
    sub {
        return unless -f && /\.pm$/;
        check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 );
    },
    'lib',
);

find(
    sub {
        return unless -f && /\.t$/;
        check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 );
    },
    't',
);

find(
    sub {
        return unless -f;
        check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 );
    },
    'bin',
    'sbin',
);

find(
    sub {
        return unless -f && $_ !~ m{/(localhost\.(crt|key)|mime\.types)$};
        check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 );
    },
    'devel/tools',
);
