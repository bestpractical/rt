use strict;
use warnings;

use Test::More;
use IPC::Run3;

my @files = files();
plan tests => 1 + @files * 3;

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

sub files {
    use File::Find;
    my @res;
    find(
        sub { push @res, $File::Find::name if -f && $_ eq 'content' },
        'etc/upgrade/'
    );
    return @res;
}