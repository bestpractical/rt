#!/usr/bin/perl

use strict;
use warnings;

use File::Spec;
use File::Temp 0.19 ();
require File::Path;
require File::Copy;
require Cwd;

BEGIN {
### after:     push @INC, qw(@RT_LIB_PATH@);
    push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
}
use RT::Shredder;

# where to keep temporary generated test data
my $tmpdir = '';

=head1 DESCRIPTION

RT::Shredder test suite utilities

=head1 TESTING

Since RT:Shredder 0.01_03 we have a test suite. You
can run tests and see if everything works as expected
before you try shredder on your actual data.
Tests also help in the development process.

The test suite uses SQLite databases to store data in individual files,
so you could sun tests on your production servers without risking
damage to your production data.

You'll want to run the test suite almost every time you install or update
the shredder distribution, especialy if you have local customizations of
the DB schema and/or RT code.

Tests are one thing you can write even if you don't know much perl,
but want to learn more about RT's internals. New tests are very welcome.

=head2 WRITING TESTS

The shredder distribution has several files to help write new tests.

  t/shredder/utils.pl - this file, utilities
  t/00skeleton.t - skeleteton .t file for new tests

All tests follow this algorithm:

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
  # then you can create another object and delete it, then check again

Savepoints are named and you can create two or more savepoints.

=head1 FUNCTIONS

=head2 RT CONFIG

=head3 rewrite_rtconfig

Call this sub after C<RT::LoadConfig>. It changes the RT config
options necessary to switch to a local SQLite database.

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

This sub is a helper used by C<rewrite_rtconfig>. You shouldn't
need to use it elsewhere unless you need to change other RT
configuration variables.

=cut

sub config_set {
    my $opt = shift;
    $opt =~ s/^[\$\%\@]//;
    RT->Config->Set($opt, @_)
}

=head2 DATABASES

=head3 init_db

Creates a new RT DB with initial data in a new test tmp dir.
Also runs RT::Init() and RT::InitLogging().

This is all you need to call to setup a testing environment
in most situations.

=cut

sub init_db
{
    create_tmpdir();
    RT::LoadConfig();
    rewrite_rtconfig();
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
    my $rt_setup_database = RT::Test::get_relocatable_file(
        'rt-setup-database', (File::Spec->updir(), File::Spec->updir(), 'sbin'));
    my $cmd =  "$^X $rt_setup_database --action init 2>&1";

    my ($child_out, $child_in);
    my $pid = open2($child_out, $child_in, $cmd);
    close $child_in;
    my $result = do { local $/; <$child_out> };
    return $result;
}

=head3 db_name

Returns the absolute file path to the current DB.
It is <$tmpdir . test_name() .'.db'>.

See also the C<test_name> function.

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

Creates and returns a new RT::Shredder object.

=cut

sub shredder_new
{
    my $obj = new RT::Shredder;

    my $file = File::Spec->catfile( create_tmpdir(), test_name() .'.XXXX.sql' );
    $obj->AddDumpPlugin( Arguments => {
        file_name    => $file,
        from_storage => 0,
    } );

    return $obj;
}


=head2 TEST FILES

=head3 test_name

Returns name of the test file running now with file extension and
directory names stripped.

For example, it returns '00load' for the test file 't/00load.t'.

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

Returns the absolute path to a tmp dir used in tests.

=cut

sub tmpdir {
    if (-d $tmpdir) {
        return $tmpdir;
    } else {
        $tmpdir = File::Temp->newdir(TEMPLATE => 'shredderXXXXX', CLEANUP => 0);
        return $tmpdir;
    }
}

=head2 create_tmpdir

Creates a tmp dir if one doesn't exist already. Returns tmpdir path.

=cut

sub create_tmpdir { my $n = tmpdir(); File::Path::mkpath( [$n] ); return $n }

=head3 cleanup_tmp

Deletes all the tmp dir used in the tests.
See also the C<test_name> function.

=cut

sub cleanup_tmp
{
    my $dir = File::Spec->catdir(tmpdir(), test_name());
    return File::Path::rmtree( File::Spec->catdir( tmpdir(), test_name() ));
}

=head2 SAVEPOINTS

=head3 savepoint_name

Returns the absolute path to the named savepoint DB file.
Takes one argument - savepoint name, by default C<sp>.

=cut

sub savepoint_name
{
    my $name = shift || 'sp';
    return File::Spec->catfile( create_tmpdir(), test_name() .".$name.db" );
}

=head3 create_savepoint

Creates savepoint DB from the current DB.
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

Returns DB dump as a complex hash structure:
    {
    TableName => {
        #id => {
            lc_field => 'value',
        }
    }
    }

Takes named argument C<CleanDates>. If true, clean all date fields from
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

Function that returns debug notes.

=head3 note_on_fail

Returns a note about debug info that you can display if tests fail.

=cut

sub note_on_fail
{
    my $name = test_name();
    my $tmpdir = tmpdir();
    return <<END;
Some tests in '$0' file failed.
You can find debug info in '$tmpdir' dir.
There should be:
    $name.log - RT debug log file
    $name.db - latest RT DB used while testing
    $name.*.db - savepoint databases
See also perldoc t/shredder/utils.pl for how to use this info.
END
}

=head2 OTHER

=head3 all_were_successful

Returns true if all tests that have already run were successful.

=cut

sub all_were_successful
{
    use Test::Builder;
    my $Test = Test::Builder->new;
    return grep( !$_, $Test->summary )? 0: 1;
}

END {
    return unless -e tmpdir();
    if ( all_were_successful() ) {
            cleanup_tmp();
    } else {
            diag( note_on_fail() );
    }
}

1;
