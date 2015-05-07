use strict;
use warnings;

use RT::Test tests => undef;
use File::Find;
use IPC::Run3;

my @files;
find( { wanted   => sub {
            push @files, $File::Find::name if -f;
            $File::Find::prune = 1 if $_ eq "t/tmp" or m{/\.git$};
        },
        no_chdir => 1 },
      qw{etc lib share t bin sbin devel/tools docs devel/docs} );

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
        no_tabs  => 0,
        shebang  => 0,
        exec     => 0,
        bps_tag  => 0,
        compile_perl => 0,
        @_,
    );

    if ($check{strict} or $check{warnings} or $check{shebang} or $check{bps_tag} or $check{no_tabs}) {
        local $/;
        open my $fh, '<', $file or die $!;
        my $content = <$fh>;

        unless ($check{shebang} != -1 and $content =~ /^#!(?!.*perl)/i) {
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
        }

        if ($check{shebang} == 1) {
            like( $content, qr/^#!/, "$file has shebang" );
        } elsif ($check{shebang} == -1) {
            unlike( $content, qr/^#!/, "$file has no shebang" );
        }

        my $other_copyright = 0;
        $other_copyright = 1 if $file =~ /\.(css|js)$/
            and not $content =~ /Copyright\s+\(c\)\s+\d\d\d\d-\d\d\d\d Best Practical Solutions/i
                and $file =~ /(?:ckeditor|scriptaculous|superfish|tablesorter|farbtastic)/i;
        $other_copyright = 1 if $file =~ /\.(css|js)$/
            and not $content =~ /Copyright\s+\(c\)\s+\d\d\d\d-\d\d\d\d Best Practical Solutions/i
                and ($content =~ /\b(copyright|GPL|Public Domain)\b/i
                  or $content =~ /\(c\)\s+\d\d\d\d(?:-\d\d\d\d)?/i);
        $check{bps_tag} = -1 if $check{bps_tag} and $other_copyright;
        if ($check{bps_tag} == 1) {
            like( $content, qr/[B]EGIN BPS TAGGED BLOCK \{\{\{/, "$file has BPS license tag");
        } elsif ($check{bps_tag} == -1) {
            unlike( $content, qr/[B]EGIN BPS TAGGED BLOCK \{\{\{/, "$file has no BPS license tag"
                        . ($other_copyright ? " (other copyright)" : ""));
        }

        if (not $other_copyright and $check{no_tabs}) {
            unlike( $content, qr/\t/, "$file has no hard tabs" );
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

    if ($check{compile_perl}) {
        my ($input, $output, $error) = ('', '', '');
        my $pre_check = 1;
        if ( $file =~ /\bmysql\b/ ) {
            eval { require DBD::mysql };
            undef $pre_check if $@;
        }

        if ( $pre_check ) {
            run3( [ $^X, '-Ilib', '-Mstrict', '-Mwarnings', '-c', $file ], \$input, \$output, \$error, );
            is $error, "$file syntax OK\n", "$file syntax is OK";
        }
    }
}

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1, bps_tag => 1, no_tabs => 1 )
    for grep {m{^lib/.*\.pm$}} @files;

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1, bps_tag => -1, no_tabs => 1 )
    for grep {m{^t/.*\.t$}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1, bps_tag => 1, no_tabs => 1 )
    for grep {m{^s?bin/}} @files;

check( $_, compile_perl => 1, exec => 1 )
    for grep { -f $_ } map { s/\.in$//; $_ } grep {m{^s?bin/}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1, bps_tag => 1, no_tabs => 1 )
    for grep {m{^devel/tools/} and not m{/(localhost\.(crt|key)|mime\.types)$}} @files;

check( $_, exec => -1 )
    for grep {m{^share/static/}} @files;

check( $_, exec => -1, bps_tag => 1, no_tabs => 1 )
    for grep {m{^share/html/}} @files;

check( $_, exec => -1 )
    for grep {m{^share/(po|fonts)/}} @files;

check( $_, exec => -1 )
    for grep {m{^t/data/}} @files;

check( $_, exec => -1, bps_tag => -1 )
    for grep {m{^etc/[^/]+$}} @files;

check( $_, exec => -1, bps_tag => -1 )
    for grep {m{^etc/upgrade/[^/]+/}} @files;

check( $_, warnings => 1, strict => 1, compile_perl => 1, no_tabs => 1 )
    for grep {m{^etc/upgrade/.*/content$}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1, bps_tag => 1, no_tabs => 1 )
    for grep {m{^etc/upgrade/[^/]+$}} @files;

check( $_, compile_perl => 1, exec => 1 )
    for grep{ -f $_} map {s/\.in$//; $_} grep {m{^etc/upgrade/[^/]+$}} @files;

check( $_, exec => -1 )
    for grep {m{^(devel/)?docs/}} @files;

done_testing;
