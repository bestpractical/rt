use strict;
use warnings;

# File-based session files are private to the web server user, while what
# Mason writes under $MasonDataDir keeps the permissions the process umask
# gives it.

use RT::Test
    tests  => undef,
    config => 'Set($DevelMode, 0); Set($WebSessionClass, "Apache::Session::File");';
use File::Find;
use File::Path qw(rmtree);
use File::Spec;
use JSON;

# A permissive umask, as inherited from most init systems.
umask(0022);

# The test server shares $MasonDataDir with other tests, so start from an
# empty object cache. Mason recreates it on startup.
my $obj = File::Spec->catdir( $RT::MasonDataDir, 'obj' );
rmtree($obj);

my ( $baseurl, $m ) = RT::Test->started_ok;
$m->login;

diag "session files";
{
    my $dir = $RT::MasonSessionDir;
    opendir my $dh, $dir or die "Can't read $dir: $!";
    my @files = grep { -f File::Spec->catfile( $dir, $_ ) } readdir $dh;
    closedir $dh;
    ok( scalar @files, 'session files were written' );
    for my $file (@files) {
        my $mode = ( stat File::Spec->catfile( $dir, $file ) )[2] & 07777;
        is( $mode, 0600, sprintf "session file %s is 0600 (got %04o)", $file, $mode );
    }
}

diag "Mason object files compiled during requests";
{
    ok( -d $obj, 'Mason object dir exists' );
    my @private;
    find(
        {
            no_chdir => 1,
            wanted   => sub {
                my $mode = ( stat $_ )[2] & 0777;
                push @private, sprintf( "%s (%04o)", $_, $mode )
                    if ( -d _ && ( $mode & 0055 ) != 0055 )
                    || ( -f _ && ( $mode & 0044 ) != 0044 );
            },
        },
        $obj
    );
    is( scalar @private, 0, 'nothing under the Mason object dir is private to the web user' )
        or diag join "\n", @private;
}

diag "Mason object dir recreated by the cache clear helper";
{
    sleep 1;    # Cache updates at most once per second.
    $m->post_ok( $baseurl . '/Admin/Helpers/ClearMasonCache' );
    is_deeply( from_json( $m->content ), { status => 1, message => 'Cache cleared' }, 'Cache cleared' );
    my $mode = ( stat $obj )[2] & 0777;
    is( $mode & 0055, 0055, sprintf "recreated Mason object dir is not private to the web user (got %04o)", $mode );
}

SKIP: {
    skip "umask is only observable in-process with the inline web handler", 1
        unless ( $ENV{RT_TEST_WEB_HANDLER} || '' ) eq 'inline';
    is( umask, 0022, 'process umask was left alone' );
}

done_testing;
