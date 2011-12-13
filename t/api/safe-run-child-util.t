#!/usr/bin/perl

use strict;
use warnings;

use RT::Test tests => 27;
use Test::Warn;

use RT::Util qw(safe_run_child);

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

sub is_handle_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $test = $RT::Handle->dbh->selectall_arrayref(
        "SELECT id FROM Users WHERE Name = 'Nobody'"
    );
    ok $test && $test->[0][0], "selected, DB is there";
}

