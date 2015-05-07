
use strict;
use warnings;

use RT::Test tests => undef;
plan skip_all => 'Not mysql' unless RT->Config->Get('DatabaseType') eq 'mysql';
plan skip_all => "No SphinxSE in mysql" unless $RT::Handle->CheckSphinxSE;

my %sphinx;
$sphinx{'searchd'} = RT::Test->find_executable('searchd');
$sphinx{'indexer'} = RT::Test->find_executable('indexer');

plan skip_all => "No searchd and indexer under PATH"
    unless $sphinx{'searchd'} && $sphinx{'indexer'};

plan skip_all => "Can't determine sphinx version"
    unless `$sphinx{searchd} --version` =~ /Sphinx (\d+)\.(\d+)(?:\.(\d+))?/;

$sphinx{version} = sprintf "%d.%03d%03d", $1, $2, ($3 || 0);

plan tests => 15;

setup_indexing();

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';
my $queue = $q->Name;

sub setup_indexing {
    # Since we're not running a webserver in this test, use the
    # known-safe port we determined at test setup
    my $port = $RT::Test::port;
    my ($exit_code, $output) = RT::Test->run_and_capture(
        'no-ask'       => 1,
        command        => $RT::SbinPath .'/rt-setup-fulltext-index',
        dba            => $ENV{'RT_DBA_USER'},
        'dba-password' => $ENV{'RT_DBA_PASSWORD'},
        url            => "sphinx://127.0.0.1:$port/rt",
        'index-type'   => 'sphinx',
    );
    ok(!$exit_code, "setted up index");
    diag "output: $output" if $ENV{'TEST_VERBOSE'};

    my $tmp = $sphinx{'directory'} = File::Spec->catdir( RT::Test->temp_directory, 'sphinx' );
    mkdir $tmp;

    my $sphinx_conf = $output;
    $sphinx_conf =~ s/.*?source rt \{/source rt {/ms;
    $sphinx_conf =~ s{\Q$RT::VarPath\E/sphinx/}{$tmp/}g;

    # Remove lines for different versions of sphinx than we're running
    $sphinx_conf =~ s{^(\s+ \# \s+ for \s+ sphinx \s+
                          (<=?|>=?|=) \s*
                          (\d+) \. (\d+) (?:\. (\d+))?
                          .* \n)
                      ((?:^\s* \w .*\n)+)}{
        my $v = sprintf "%d.%03d%03d", $3, $4, ($5 || 0);
        my $prefix = eval "$sphinx{version} $2 $v" ? "" : "#";
        $1 . join("\n",map{"$prefix$_"} split "\n", $6) . "\n";
    }emix;

    $sphinx{'config'} = File::Spec->catfile( $tmp, 'sphinx.conf' );
    {
        open my $fh, ">", $sphinx{'config'};
        print $fh $sphinx_conf;
        close $fh;
    }

    sync_index();

    {
        my ($exit_code, $output) = RT::Test->run_and_capture(
            command => $sphinx{'searchd'},
            config => $sphinx{'config'},
        );
        ok(!$exit_code, "setted up index") or diag "output: $output";
        $sphinx{'started'} = 1 if !$exit_code;
    }
}

sub sync_index {
    local $SIG{'CHLD'} = 'DEFAULT';
    local $SIG{'PIPE'} = 'DEFAULT';
    open my $fh, '-|',  $sphinx{'indexer'}, '--all',
        '--config' => $sphinx{'config'},
        $sphinx{'started'}? ('--rotate') : (),
    ;
    my $output = <$fh>;
    close $fh;
    my $exit_code = $?>>8;
    ok(!$exit_code, "indexed") or diag "output: $output";

    # We may need to wait a second for searchd to pick up the changes
    sleep 1;
}

sub run_tests {
    my @test = @_;
    while ( my ($query, $checks) = splice @test, 0, 2 ) {
        run_test( $query, %$checks );
    }
}

my @tickets;
sub run_test {
    my ($query, %checks) = @_;
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;

    my $tix = RT::Tickets->new(RT->SystemUser);
    $tix->FromSQL( "( $query_prefix ) AND ( $query )" );

    my $error = 0;

    my $count = 0;
    $count++ foreach grep $_, values %checks;
    is($tix->Count, $count, "found correct number of ticket(s) by '$query'") or $error = 1;

    my $good_tickets = ($tix->Count == $count);
    while ( my $ticket = $tix->Next ) {
        next if $checks{ $ticket->Subject };
        diag $ticket->Subject ." ticket has been found when it's not expected";
        $good_tickets = 0;
    }
    ok( $good_tickets, "all tickets are good with '$query'" ) or $error = 1;

    diag "Wrong SQL query for '$query':". $tix->BuildSelectQuery if $error;
}

@tickets = RT::Test->create_tickets(
    { Queue => $q->id },
    { Subject => 'book', Content => 'book' },
    { Subject => 'bar', Content => 'bar' },
);
sync_index();

RT->Config->Set( FullTextSearch => Enable => 1, Indexed => 1, Table => 'AttachmentsIndex', MaxMatches => 1000, Sphinx => 1 );

run_tests(
    "Content LIKE 'book'" => { book => 1, bar => 0 },
    "Content LIKE 'bar'" => { book => 0, bar => 1 },
);

END {
    my $Test = RT::Test->builder;
    return if $Test->{Original_Pid} != $$;
    return unless $sphinx{'started'};

    my $pid = int RT::Test->file_content([$sphinx{'directory'}, 'searchd.pid']);
    kill TERM => $pid if $pid;
}
