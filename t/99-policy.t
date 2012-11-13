use strict;
use warnings;

use RT::Test nodb => 1;
use File::Find;
use IPC::Run3;

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
        bps_tag  => 0,
        @_,
    );

    if ($check{strict} or $check{warnings} or $check{shebang} or $check{bps_tag}) {
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

        $check{bps_tag} = -1 if $check{bps_tag} == 1
            and not $content =~ /Copyright\s+\(c\)\s+\d\d\d\d-\d\d\d\d Best Practical Solutions/i
                and $file =~ /(?:FCKEditor|scriptaculous|superfish|tablesorter|farbtastic)/i;
        $check{bps_tag} = -1 if $check{bps_tag} == 1
            and not $content =~ /Copyright\s+\(c\)\s+\d\d\d\d-\d\d\d\d Best Practical Solutions/i
                and ($content =~ /\b(copyright|GPL|Public Domain)\b/i
                  or /\(c\)\s+\d\d\d\d(?:-\d\d\d\d)?/i);
        if ($check{bps_tag} == 1) {
            like( $content, qr/[B]EGIN BPS TAGGED BLOCK {{{/, "$file has BPS license tag");
        } elsif ($check{bps_tag} == -1) {
            unlike( $content, qr/[B]EGIN BPS TAGGED BLOCK {{{/, "$file has no BPS license tag");
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

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1, bps_tag => 1 )
    for grep {m{^lib/.*\.pm$}} @files;

check( $_, shebang => -1, exec => -1, warnings => 1, strict => 1, bps_tag => -1 )
    for grep {m{^t/.*\.t$}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1, bps_tag => 1 )
    for grep {m{^s?bin/}} @files;

check( $_, shebang => 1, exec => 1, warnings => 1, strict => 1, bps_tag => 1 )
    for grep {m{^devel/tools/} and not m{/(localhost\.(crt|key)|mime\.types)$}} @files;

check( $_, exec => -1, bps_tag => not m{\.(png|gif|jpe?g)$} )
    for grep {m{^share/html/}} @files;

check( $_, exec => -1 )
    for grep {m{^share/(po|fonts)/}} @files;

check( $_, exec => -1 )
    for grep {m{^t/data/}} @files;

{ # Check to make sure all our upgrade files compile
my @files = upgrade_files();
ok( scalar @files, "found content files" );

test_it($_) foreach @files;

sub test_it {
    my $file = shift;

    my ($input, $output, $error) = ('', '', '');
    run3(
        [$^X, '-Ilib', '-Mstrict', '-Mwarnings', '-c', $file],
        \$input, \$output, \$error,
    );
    is $error, "$file syntax OK\n", "syntax is OK";

    open my $fh, "<", $file or die "$!";
    my ($first, $second) = (grep /\S/, map { chomp; $_ } <$fh>);
    close $fh;

    is $first, 'use strict;', 'first not empty line is "use strict;"';
    is $second, 'use warnings;', 'second not empty line is "use warnings;"';
}

sub upgrade_files {
    my @res;
    find(
        sub { push @res, $File::Find::name if -f && $_ eq 'content' },
        'etc/upgrade/'
    );
    return @res;
}
}
