use strict;
use warnings;

use RT::Test tests => undef, config => 'Set( $Timezone, "UTC" );';
use Config;
use File::Path 'mkpath';
use File::Spec;
use Time::Local 'timegm';

# Consecutive Mondays, then consecutive weekdays, all at 06:15. The timezone is
# pinned to UTC in the test config so these are stable and DST can't shift the
# hour a process is due.
my $week1 = timegm( 0, 15, 6, 5, 0, 2026 );    # Mon 2026-01-05 06:15
my $week2 = $week1 + 7 * 24 * 60 * 60;         # Mon 2026-01-12 06:15
my $week3 = $week1 + 14 * 24 * 60 * 60;        # Mon 2026-01-19 06:15
my $day1  = $week3 + 1 * 24 * 60 * 60;         # Tue 2026-01-20 06:15
my $day2  = $week3 + 2 * 24 * 60 * 60;         # Wed 2026-01-21 06:15
my $day3  = $week3 + 3 * 24 * 60 * 60;         # Thu 2026-01-22 06:15

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded queue General';

# rt-crontool maps the invoking unix user to an RT user via Gecos
my $root = RT::User->new( RT->SystemUser );
$root->Load('root');
ok $root->id, 'loaded root user';
$root->SetGecos( ( getpwuid($<) )[0] );

# Each process bumps its own ticket's priority by 1 using RT::Action::AddPriority,
# so priority records how many times the process actually ran, independently of
# the Counter the scheduler keeps.
sub create_scheduled_process {
    my %content = (
        Description        => '',
        SearchModule       => 'FromSQL',
        SearchModuleArg    => '',
        ConditionModule    => '',
        ConditionModuleArg => '',
        ActionModule       => 'AddPriority',
        ActionModuleArg    => 1,
        Frequency          => 'daily',
        Monday             => 1,
        Tuesday            => 1,
        Wednesday          => 1,
        Thursday           => 1,
        Friday             => 1,
        Saturday           => 1,
        Sunday             => 1,
        Hour               => '06',
        Minute             => '15',
        Dow                => 'Monday',
        Dom                => 1,
        Fow                => 1,
        Counter            => 0,
        Transaction        => 'first',
        TransactionTypes   => 'all',
        Template           => '',
        ReloadTicket       => 0,
        Disabled           => 0,
        @_,
    );

    my $process = RT::Attribute->new( RT->SystemUser );
    my ( $ok, $msg ) = $process->Create(
        Name        => 'Crontool',
        Description => $content{Description},
        ContentType => 'storable',
        Object      => RT->SystemUser,
        Content     => \%content,
    );
    ok $ok, "created scheduled process '$content{Description}': $msg";

    return $process;
}

sub run_scheduled_processes {
    my $time = shift;
    my ( $exit, $output ) = RT::Test->run_and_capture(
        command => "$RT::BinPath/rt-run-scheduled-processes",
        args    => "--time $time",
    );
    is $exit >> 8, 0, "rt-run-scheduled-processes exited 0 for time $time";
    diag $output if $output && $ENV{'TEST_VERBOSE'};

    # the run happened in a child process, so drop anything we have cached
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    return $output;
}

sub reload {
    my ( $ticket, $process ) = @_;
    $ticket->Load( $ticket->id );
    $process->Load( $process->id );
    return;
}

diag 'A weekly process with Fow = 2 must run only every other week';

my $weekly_ticket = RT::Test->create_ticket(
    Queue    => $queue->id,
    Subject  => 'Weekly scheduled process target',
    Priority => 0,
);
ok $weekly_ticket && $weekly_ticket->id, 'created ticket for the weekly process';
is $weekly_ticket->Priority, 0, 'ticket starts at priority 0';

my $weekly = create_scheduled_process(
    Description     => 'Add priority every other Monday',
    SearchModuleArg => 'id = ' . $weekly_ticket->id,
    Frequency       => 'weekly',
    Dow             => 'Monday',
    Fow             => 2,
);

diag 'Week 1: the process is due, so it runs';
run_scheduled_processes($week1);
reload( $weekly_ticket, $weekly );
is $weekly_ticket->Priority,      1, 'priority bumped once on the first Monday';
is $weekly->SubValue('Counter'),  1, 'Counter advanced to 1 after the run';

diag 'Week 2: "every 2 weeks" means this Monday is skipped';
run_scheduled_processes($week2);
reload( $weekly_ticket, $weekly );
is $weekly_ticket->Priority,     1, 'priority unchanged on the second Monday';
is $weekly->SubValue('Counter'), 2, 'Counter advanced to 2 for the skipped week';

diag 'Week 3: the process is due again';
run_scheduled_processes($week3);
reload( $weekly_ticket, $weekly );
is $weekly_ticket->Priority,     2, 'priority bumped a second time on the third Monday';
is $weekly->SubValue('Counter'), 3, 'Counter advanced to 3 after the second run';

# Disable it so the daily process below is exercised in isolation
my ( $disabled_ok, $disabled_msg ) = $weekly->SetSubValues( Disabled => 1 );
ok $disabled_ok, "disabled the weekly process: $disabled_msg";
my $weekly_priority = $weekly_ticket->Priority;

diag 'Counter must advance on every successful run, with no Fow arithmetic in the way';

# A daily process never consults Counter when deciding whether to run, so its
# schedule is correct either way. That isolates the counter itself: the process
# fires on all three days, and Counter is the only thing that can be wrong.
my $daily_ticket = RT::Test->create_ticket(
    Queue    => $queue->id,
    Subject  => 'Daily scheduled process target',
    Priority => 0,
);
ok $daily_ticket && $daily_ticket->id, 'created ticket for the daily process';
is $daily_ticket->Priority, 0, 'ticket starts at priority 0';

my $daily = create_scheduled_process(
    Description     => 'Add priority every day',
    SearchModuleArg => 'id = ' . $daily_ticket->id,
    Frequency       => 'daily',
);

is $daily->SubValue('Counter'), 0, 'Counter starts at 0';

my $run = 0;
for my $time ( $day1, $day2, $day3 ) {
    $run++;

    run_scheduled_processes($time);
    reload( $daily_ticket, $daily );

    is $daily_ticket->Priority, $run, "daily process ran on day $run";
    is $daily->SubValue('Counter'), $run,
        "Counter advanced to $run after $run successful run(s)";
}

diag 'The disabled weekly process stayed out of the daily runs';
reload( $weekly_ticket, $weekly );
is $weekly_ticket->Priority, $weekly_priority, 'weekly process did not run again while disabled';

# Disable it so the failing process below is exercised in isolation
my ( $daily_off_ok, $daily_off_msg ) = $daily->SetSubValues( Disabled => 1 );
ok $daily_off_ok, "disabled the daily process: $daily_off_msg";

diag 'A failed run must not advance the counter, so the week is not consumed';

my $failing_ticket = RT::Test->create_ticket(
    Queue    => $queue->id,
    Subject  => 'Failing scheduled process target',
    Priority => 0,
);
ok $failing_ticket && $failing_ticket->id, 'created ticket for the failing process';

# RT::Action::NoSuchAction does not exist, so rt-crontool dies while loading
# modules and exits non-zero without ever reaching the ticket.
my $failing = create_scheduled_process(
    Description     => 'Fail to add priority every other Monday',
    SearchModuleArg => 'id = ' . $failing_ticket->id,
    ActionModule    => 'NoSuchAction',
    Frequency       => 'weekly',
    Dow             => 'Monday',
    Fow             => 2,
);

is $failing->SubValue('Counter'), 0, 'Counter starts at 0';

diag 'Week 1: the process is due, but rt-crontool fails';
my $failed_output = run_scheduled_processes($week1);
reload( $failing_ticket, $failing );
like $failed_output, qr/RT::Action::NoSuchAction/, 'rt-crontool reported the failure';
is $failing_ticket->Priority,     0, 'failed run left the ticket alone';
is $failing->SubValue('Counter'), 0, 'Counter did not advance after a failed run';

# With "every 2 weeks" a *successful* run in week 1 would have taken the counter
# to 1 and skipped this Monday. The failed run did not consume the week, so the
# process is due again and tries once more.
diag 'Week 2: the failed week was not consumed, so the process is due again';
$failed_output = run_scheduled_processes($week2);
reload( $failing_ticket, $failing );
like $failed_output, qr/RT::Action::NoSuchAction/, 'the process was retried a week later';
is $failing_ticket->Priority,     0, 'second failed run left the ticket alone';
is $failing->SubValue('Counter'), 0, 'Counter still at 0 after a second failed run';

# Disable it so the process below is exercised in isolation
my ( $failing_off_ok, $failing_off_msg ) = $failing->SetSubValues( Disabled => 1 );
ok $failing_off_ok, "disabled the failing process: $failing_off_msg";

diag 'A run3 that dies must not be read as a successful run';

# Monkeypatch run3 to die before it starts anything, which is how the real one
# behaves when it can't set up the child's file handles. Nothing is executed, so
# $? keeps the status of whatever ran before it -- zero. Without the eval guard
# in RunCrontoolJob that stale zero reads as a successful run and advances the
# counter for a process that never ran.
#
# The patch has to happen inside rt-run-scheduled-processes, so it is delivered
# with PERL5OPT. That runs before the script is compiled, so IPC::Run3 is already
# patched by the time the script imports run3 from it -- patching any later would
# not be seen, because the import aliases the original sub into the script.
#
# It only breaks the rt-crontool call. RT::Crypt::SMIME::Probe also goes through
# run3, and it runs from a Crypt PostLoadCheck during RT::LoadConfig, so breaking
# run3 wholesale kills the script before it reaches any scheduled process.
my $patch_lib = File::Spec->catdir( RT::Test->temp_directory . '', 'patch-lib' );
mkpath($patch_lib);

my $patch_path = File::Spec->catfile( $patch_lib, 'BreakRun3.pm' );
open my $patch_fh, '>', $patch_path or die "Couldn't write $patch_path: $!";
print $patch_fh <<'PATCH' or die "Couldn't write $patch_path: $!";
package BreakRun3;
use strict;
use warnings;
require IPC::Run3;
my $orig = \&IPC::Run3::run3;
no warnings 'redefine';
*IPC::Run3::run3 = sub {
    my $cmd = shift;
    die "run3(): patched by the test to fail\n"
        if ref $cmd eq 'ARRAY' && $cmd->[0] =~ m{rt-crontool$};
    return $orig->( $cmd, @_ );
};
1;
PATCH
close $patch_fh or die "Couldn't close $patch_path: $!";

my $broken_ticket = RT::Test->create_ticket(
    Queue    => $queue->id,
    Subject  => 'Unstartable scheduled process target',
    Priority => 0,
);
ok $broken_ticket && $broken_ticket->id, 'created ticket for the unstartable process';

my $broken_process = create_scheduled_process(
    Description     => 'Add priority every day, with run3 broken',
    SearchModuleArg => 'id = ' . $broken_ticket->id,
    Frequency       => 'daily',
);

is $broken_process->SubValue('Counter'), 0, 'Counter starts at 0';

my $broken_output;
{
    local $ENV{PERL5LIB} = join $Config{path_sep}, grep { defined && length }
        $patch_lib, $ENV{PERL5LIB};
    local $ENV{PERL5OPT} = join ' ', grep { defined && length }
        '-MBreakRun3', $ENV{PERL5OPT};

    $broken_output = run_scheduled_processes($day1);
}
reload( $broken_ticket, $broken_process );

like $broken_output, qr/rt-crontool failed to run/, 'the run3 failure was logged';
is $broken_ticket->Priority, 0, 'nothing ran, so the ticket was left alone';
is $broken_process->SubValue('Counter'), 0,
    'Counter did not advance for a run that never started';

done_testing;
