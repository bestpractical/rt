use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;

my @files;
find( sub { push @files, $File::Find::name if -f },
      qw{lib share t bin sbin devel/tools} );
if ( my $dir = `git rev-parse --git-dir 2>/dev/null` ) {
    # We're in a git repo, use the ignore list
    chomp $dir;
    my %ignores;
    $ignores{ $_ }++ for grep $_, split /\n/,
        `git ls-files -o -i --exclude-standard .`;
    @files = grep {not $ignores{$_}} @files;
}

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
            "$file has 'use strict'"
        ) if $check{strict};

        like(
            $content,
            qr/^use warnings(?:;|\s+)/m,
            "$file has 'use warnings'"
        ) if $check{warnings};

        if ($check{shebang} == 1) {
            like( $content, qr/^#!/, "$file has shebang" );
        } elsif ($check{shebang} == -1) {
            unlike( $content, qr/^#!/, "$file has no shebang" );
        }
    }

    my $executable = ( stat $file )[2] & 0100;
    if ($check{exec} == 1) {
        if ( $file =~ /\.in$/ ) {
            ok( !$executable, "$file permission is u-x (.in will add +x)" );
        } else {
            ok( $executable, "$file permission is u+x" );
        }
    } elsif ($check{exec} == -1) {
        ok( !$executable, "$file permission is u-x" );
    }
}

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 )
    for grep {m{^lib/.*\.pm$}} @files;

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1 )
    for grep {m{^t/.*\.t$}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 )
    for grep {m{^s?bin/}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1 )
    for grep {m{^devel/tools/} and not m{/(localhost\.(crt|key)|mime\.types)$}} @files;

check( $_, exec => -1 )
    for grep {m{^share/}} @files;

check( $_, exec => -1 )
    for grep {m{^t/data/}} @files;
