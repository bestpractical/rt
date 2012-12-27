use strict;
use warnings;

use RT::Test tests => 35;
use Test::Warn;

use RT::Util qw(safe_run_child);
use POSIX qw//;

is_handle_ok();

{
    my $res = safe_run_child { return 1 };
    is $res, 1, "correct return value";
    is_handle_ok();
}

# test context
{
    my $context;
    my $sub = sub {
        if ( wantarray ) {
            $context = 'array'; return 1, 2, 3;
        } elsif ( defined wantarray ) {
            $context = 'scalar'; return 'foo';
        } elsif ( !wantarray ) {
            $context = 'void'; return;
        }
    };
    is_deeply [ safe_run_child { $sub->(@_) } ], [1, 2, 3];
    is $context, 'array';
    is_handle_ok();

    is scalar safe_run_child {$sub->(@_)}, 'foo';
    is $context, 'scalar';
    is_handle_ok();

    safe_run_child {$sub->(@_)};
    is $context, 'void';
    is_handle_ok();
}

# fork+child returns
{
    my $res = safe_run_child {
        if (fork) { wait; return 'parent' }

        open my $fh, '>', RT::Test->temp_directory .'/tttt';
        print $fh "child";
        close $fh;

        return 'child';
    };
    is $res, 'parent', "correct return value";
    is( RT::Test->file_content([RT::Test->temp_directory, 'tttt'], unlink => 1 ),
        'child',
        'correct file content',
    );
    is_handle_ok();
}

# fork+child dies
{
    warning_like {
        my $res = safe_run_child {
            if (fork) { wait; return 'parent' }

            open my $fh, '>', RT::Test->temp_directory .'/tttt';
            print $fh "child";
            close $fh;

            die 'child';
        };
        is $res, 'parent', "correct return value";
        is( RT::Test->file_content([RT::Test->temp_directory, 'tttt'], unlink => 1 ),
            'child',
            'correct file content',
        );
    } qr/System Error: child/;
    is_handle_ok();
}

# fork+child exits
{
    my $res = safe_run_child {
        if (fork) { wait; return 'parent' }

        open my $fh, '>', RT::Test->temp_directory .'/tttt';
        print $fh "child";
        close $fh;

        exit 0;
    };
    is $res, 'parent', "correct return value";
    is( RT::Test->file_content([RT::Test->temp_directory, 'tttt'], unlink => 1 ),
        'child',
        'correct file content',
    );
    is_handle_ok();
}

# parent dies
{
    my $res = eval { safe_run_child { die 'parent'; } };
    is $res, undef, "correct return value";
    like $@, qr'System Error: parent', "correct error message value";
    is_handle_ok();
}

# fork+exec
{
    my $script = RT::Test->temp_directory .'/true.pl';
    open my $fh, '>', $script;
    print $fh <<END;
#!$^X

open my \$fh, '>', '$script.res';
print \$fh "child";
close \$fh;

exit 0;
END
    close $fh;
    chmod 0777, $script;

    my $res = safe_run_child {
        if (fork) { wait; return 'parent' }
        exec $script;
    };
    is $res, 'parent', "correct return value";
    is( RT::Test->file_content([$script .'.res'], unlink => 1 ),
        'child',
        'correct file content',
    );
    is_handle_ok();
}

# fork+parent that doesn't wait()
{
    require Time::HiRes;
    my $start = Time::HiRes::time();
    my $pid;

    # Set up a poor man's semaphore
    my $all_set = 0;
    $SIG{USR1} = sub {$all_set++};

    my $res = safe_run_child {
        if ($pid = fork) { return 'parent' }

        open my $fh, '>', RT::Test->temp_directory .'/first';
        print $fh "child";
        close $fh;
        # Signal that the first file is now all set; we need to do this
        # to avoid a race condition
        kill POSIX::SIGUSR1(), getppid();

        sleep 5;

        open $fh, '>', RT::Test->temp_directory .'/second';
        print $fh "child";
        close $fh;

        exit 0;
    };
    ok( Time::HiRes::time() - $start < 5, "Didn't wait until child finished" );

    # Wait for up to 3 seconds to get signaled that the child has made
    # the file (the USR1 will break out of the sleep()).  This _should_
    # be immediate, but there's a race between the parent and child
    # here, since there's no wait()'ing.  There's still a tiny race
    # where the signal could come in betwene the $all_set check and the
    # sleep, but that just means we sleep for 3 seconds uselessly.
    sleep 3 unless $all_set;

    is $res, 'parent', "correct return value";
    is( RT::Test->file_content([RT::Test->temp_directory, 'first'], unlink => 1 ),
        'child',
        'correct file content',
    );
    ok( not(-f RT::Test->temp_directory.'/second'), "Second file does not exist yet");
    is_handle_ok();

    ok(waitpid($pid,0), "Waited until child finished to reap");
    is( RT::Test->file_content([RT::Test->temp_directory, 'second'], unlink => 1 ),
        'child',
        'correct file content',
    );
    is_handle_ok();
}

sub is_handle_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $test = $RT::Handle->dbh->selectall_arrayref(
        "SELECT id FROM Users WHERE Name = 'Nobody'"
    );
    ok $test && $test->[0][0], "selected, DB is there";
}

