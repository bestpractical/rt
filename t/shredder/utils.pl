#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
require File::Path;
require File::Copy;
require Cwd;

BEGIN {
### after:     push @INC, qw(@RT_LIB_PATH@);
    push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
}
use RT::Shredder;

=head1 DESCRIPTION

RT::Shredder test suite utilities.

=head1 TESTING

Since RT:Shredder 0.01_03 we have test suite. You 
can run tests and see if everything works as expected
before you try shredder on your actual data.
Tests also help in the development process.

Test suite uses SQLite databases to store data in individual files,
so you could sun tests on your production servers and be in safe.

You want to run test suite almost everytime you install/update
shredder distribution. Especialy you want do it if you have local
customizations of the DB schema and/or RT code.

Tests is one thing you can write even if don't know perl much,
but want to learn more about RT. New tests are very welcome.

=head2 WRITING TESTS

Shredder distribution has several files to help write new tests.

  t/shredder/utils.pl - this file, utilities
  t/00skeleton.t - skeleteton .t file for new test files

All tests runs by next algorithm:

  require "t/shredder/utils.pl"; # plug in utilities
  init_db(); # create new tmp RT DB and init RT API
  # create RT data you want to be always in the RT DB
  # ...
  create_savepoint('mysp'); # create DB savepoint
  # create data you want delete with shredder
  # ...
  # run shredder on the objects you've created
  # ...
  # check that shredder deletes things you want
  # this command will compare savepoint DB with current
  cmp_deeply( dump_current_and_savepoint('mysp'), "current DB equal to savepoint");
  # then you can create another data and delete it then check again

Savepoints are named and you can create two or more savepoints.

=head1 FUNCTIONS

=head2 RT CONFIG

=head3 rewrite_rtconfig

Call this sub after C<RT::LoadConfig>. Function changes
RT config option to switch to local SQLite database.

=cut

sub rewrite_rtconfig
{
    # database
    config_set( '$DatabaseType'       , 'SQLite' );
    config_set( '$DatabaseHost'       , 'localhost' );
    config_set( '$DatabaseRTHost'     , 'localhost' );
    config_set( '$DatabasePort'       , '' );
    config_set( '$DatabaseUser'       , 'rt_user' );
    config_set( '$DatabasePassword'   , 'rt_pass' );
    config_set( '$DatabaseRequireSSL' , undef );
    # database file name
    config_set( '$DatabaseName'       , db_name() );

    # generic logging
    config_set( '$LogToSyslog'    , undef );
    config_set( '$LogToScreen'    , 'error' );
    config_set( '$LogStackTraces' , 'crit' );
    # logging to standalone file
    config_set( '$LogToFile'      , 'debug' );
    my $fname = File::Spec->catfile(create_tmpdir(), test_name() .".log");
    config_set( '$LogToFileNamed' , $fname );
}

=head3 config_set

=cut

sub config_set {
    my $opt = shift;
    $opt =~ s/^[\$\%\@]//;
    RT->Config->Set($opt, @_)
}

=head2 DATABASES

=head3 init_db

Creates new RT DB with initial data in the test tmp dir.
Remove old files in the tmp dir if exist.
Also runs RT::Init() and init logging.
This is all you need to call to setup testing environment
in common situation.

=cut

sub init_db
{
    RT::LoadConfig();
    rewrite_rtconfig();
    cleanup_tmp();
    RT::InitLogging();

    _init_db();

    RT::Init();
    $SIG{__WARN__} = sub { $RT::Logger->warning( @_ ); warn @_ };
    $SIG{__DIE__} = sub { $RT::Logger->crit( @_ ) unless $^S; die @_ };
}

use IPC::Open2;
sub _init_db
{


    foreach ( qw(Type Host Port Name User Password) ) {
        $ENV{ "RT_DB_". uc $_ } = RT->Config->Get("Database$_");
    }
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    my $rt_setup_database = File::Spec->catfile(
        File::Spec->catdir(File::Spec->curdir(), $directories, File::Spec->updir(),
        File::Spec->updir(), "sbin"), "rt-setup-database");
    my $cmd =  "$^X $rt_setup_database --action init";

    my ($child_out, $child_in);
    my $pid = open2($child_out, $child_in, $cmd);
    close $child_in;
    my $result = do { local $/; <$child_out> };
    return $result;
}

=head3 db_name

Returns absolute file path to the current DB.
It is C<cwd() .'/t/data/shredder/'. test_name() .'.db'>.
See also C<test_name> function.

=cut

sub db_name { return File::Spec->catfile(create_tmpdir(), test_name() .".db") }

=head3 connect_sqlite

Returns connected DBI DB handle.
Takes path to sqlite db.

=cut

sub connect_sqlite
{
    return DBI->connect("dbi:SQLite:dbname=". shift, "", "");
}

=head2 SHREDDER

=head3 shredder_new

=cut

sub shredder_new
{
    my $obj = new RT::Shredder;

    my $file = File::Spec->catfile( tmpdir(), test_name() .'.XXXX.sql' );
    $obj->AddDumpPlugin( Arguments => {
        file_name    => $file,
        from_storage => 0,
    } );

    return $obj;
}


=head2 TEST FILES

=head3 test_name

Returns name of the test file running now
with stripped extension and dir names.
For exmple returns '00load' for 't/00load.t' test file.

=cut

sub test_name
{
    my $name = $0;
    $name =~ s/^.*[\\\/]//;
    $name =~ s/\..*$//;
    return $name;
}

=head2 TEMPORARY DIRECTORY

=head3 tmpdir

Return absolute path to tmp dir used in tests.
It is C<Cwd->getcwd()>. $directories . "../data/shredder", relative to the
location of this file, where $directories is the directory portion of $0.

=cut

sub tmpdir {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    return File::Spec->catdir(Cwd->getcwd(),
        $directories, File::Spec->updir(), qw(data shredder)) }

=head2 create_tmpdir

Creates tmp dir if doesn't exist. Returns tmpdir path.

=cut

sub create_tmpdir { my $n = tmpdir(); File::Path::mkpath( $n );    return $n }

=head3 cleanup_tmp

Delete all tmp files that match C<t/data/shredder/test_name.*> mask.
See also C<test_name> function.

=cut

sub cleanup_tmp
{
    my $mask = File::Spec->catfile( tmpdir(), test_name() ) .'.*';
    return unlink glob($mask);
}

=head2 SAVEPOINTS

=head3 savepoint_name

Returns absolute path to the named savepoint DB file.
Takes one argument - savepoint name, by default C<sp>.

=cut

sub savepoint_name
{
    my $name = shift || 'sp';
    return File::Spec->catfile( create_tmpdir(), test_name() .".$name.db" );
}

=head3 create_savepoint

Creates savepoint DB from the current.
Takes name of the savepoint as argument.

=head3 restore_savepoint

Restores current DB to savepoint state.
Takes name of the savepoint as argument.

=cut

sub create_savepoint { return __cp_db( db_name() => savepoint_name( shift ) ) }
sub restore_savepoint { return __cp_db( savepoint_name( shift ) => db_name() ) }
sub __cp_db
{
    my( $orig, $dest ) = @_;
    $RT::Handle->dbh->disconnect;
    # DIRTY HACK: undef Handles to force reconnect
    $RT::Handle = undef;
    %DBIx::SearchBuilder::DBIHandle = ();
    $DBIx::SearchBuilder::PrevHandle = undef;

    File::Copy::copy( $orig, $dest ) or die "Couldn't copy '$orig' => '$dest': $!";
    RT::ConnectToDatabase();
    return;
}


=head2 DUMPS

=head3 dump_sqlite

Returns DB dump as complex hash structure:
    {
    TableName => {
        #id => {
            lc_field => 'value',
        }
    }
    }

Takes named argument C<CleanDates>. If true clean all date fields from
dump. True by default.

=cut

sub dump_sqlite
{
    my $dbh = shift;
    my %args = ( CleanDates => 1, @_ );

    my $old_fhkn = $dbh->{'FetchHashKeyName'};
    $dbh->{'FetchHashKeyName'} = 'NAME_lc';

    my $sth = $dbh->table_info( '', '', '%', 'TABLE' ) || die $DBI::err;
    my @tables = keys %{$sth->fetchall_hashref( 'table_name' )};

    my $res = {};
    foreach my $t( @tables ) {
        next if lc($t) eq 'sessions';
        $res->{$t} = $dbh->selectall_hashref("SELECT * FROM $t", 'id');
        clean_dates( $res->{$t} ) if $args{'CleanDates'};
        die $DBI::err if $DBI::err;
    }

    $dbh->{'FetchHashKeyName'} = $old_fhkn;
    return $res;
}

=head3 dump_current_and_savepoint

Returns dump of the current DB and of the named savepoint.
Takes one argument - savepoint name.

=cut

sub dump_current_and_savepoint
{
    my $orig = savepoint_name( shift );
    die "Couldn't find savepoint file" unless -f $orig && -r _;
    my $odbh = connect_sqlite( $orig );
    return ( dump_sqlite( $RT::Handle->dbh, @_ ), dump_sqlite( $odbh, @_ ) );
}

=head3 dump_savepoint_and_current

Returns the same data as C<dump_current_and_savepoint> function,
but in reversed order.

=cut

sub dump_savepoint_and_current { return reverse dump_current_and_savepoint(@_) }

sub clean_dates
{
    my $h = shift;
    my $date_re = qr/^\d\d\d\d\-\d\d\-\d\d\s*\d\d\:\d\d(\:\d\d)?$/i;
    foreach my $id ( keys %{ $h } ) {
        next unless $h->{ $id };
        foreach ( keys %{ $h->{ $id } } ) {
            delete $h->{$id}{$_} if $h->{$id}{$_} &&
              $h->{$id}{$_} =~ /$date_re/;
        }
    }
}

=head2 NOTES

Function that return debug notes.

=head3 note_on_fail

Returns note about debug info you can find if test failed.

=cut

sub note_on_fail
{
    my $name = test_name();
    my $tmpdir = tmpdir();
    return <<END;
Some tests in '$0' file failed.
You can find debug info in '$tmpdir' dir.
There is should be:
    $name.log - RT debug log file
    $name.db - latest RT DB sed while testing
    $name.*.db - savepoint databases
See also perldoc t/shredder/utils.pl to know how to use this info.
END
}

=head2 OTHER

=head3 is_all_seccessful

Returns true if all tests you've already run are successful.

=cut

sub is_all_successful
{
    use Test::Builder;
    my $Test = Test::Builder->new;
    return grep( !$_, $Test->summary )? 0: 1;
}

END {
    return unless -e tmpdir();
    if( is_all_successful() ) {
            cleanup_tmp();
    } else {
            diag( note_on_fail() );
    }
}

1;
