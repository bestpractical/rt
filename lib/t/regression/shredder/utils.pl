#!/usr/bin/perl

use strict;
use warnings;

require File::Spec;
require File::Path;
require File::Copy;
require Cwd;

BEGIN {
### after: 	push @INC, qw(@RT_LIB_PATH@);
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

  lib/t/regression/shredder/utils.pl - this file, utilities
  t/00skeleton.t - skeleteton .t file for new test files

All tests runs by next algorithm:

  require "lib/t/regression/shredder/utils.pl"; # plug in utilities
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
	config_set( '$LogStackTraces' , 1 );
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
	RT::ConnectToDatabase();
	__init_schema( $RT::Handle->dbh );

    require RT::CurrentUser;

	__insert_initial_data();
	RT::Init();
	my $fname = File::Spec->catfile( $RT::EtcPath, 'initialdata' );
	__insert_data( $fname );
	$fname = File::Spec->catfile( $RT::LocalEtcPath, 'initialdata' );
	__insert_data( $fname ) if -f $fname && -r _;
	RT::Init();
	$SIG{__WARN__} = sub { $RT::Logger->warning( @_ ); warn @_ };
	$SIG{__DIE__} = sub { $RT::Logger->crit( @_ ) unless $^S; die @_ };
}

sub __init_schema
{
	my $dbh = shift;
	my (@schema);

	my $fname = File::Spec->catfile( $RT::EtcPath, "schema.SQLite" );
	if( -f $fname && -r _ ) {
		open my $fh, "<$fname" or die "Couldn't open '$fname': $!";
		push @schema, <$fh>;
		close $fh;
	} else {
		die "Couldn't find '$fname'";
	}
	$fname = File::Spec->catfile( $RT::LocalEtcPath, "schema.SQLite" );
	if( -f $fname && -r _ ) {
		open my $fh, "<$fname" or die "Couldn't open '$fname': $!";
		push @schema, <$fh>;
		close $fh;
	}

	my $statement = "";
	foreach my $line (splice @schema) {
		$line =~ s/\#.*//g;
		$line =~ s/--.*//g;
		$statement .= $line;
		if( $line =~ /;(\s*)$/ ) {
			$statement =~ s/;(\s*)$//g;
			push @schema, $statement;
			$statement = "";
		}
	}

	$dbh->begin_work or die $dbh->errstr;
	foreach my $statement (@schema) {
		my $sth = $dbh->prepare($statement) or die $dbh->errstr;
		unless ( $sth->execute ) {
			die "Couldn't execute statement '$statement':" . $sth->errstr;
		}
	}
	$dbh->commit or die $dbh->errstr;
}

sub __insert_initial_data
{
	my $CurrentUser = new RT::CurrentUser();

	my $RT_System = new RT::User($CurrentUser);

	my ( $status, $msg ) = $RT_System->_BootstrapCreate(
		Name     => 'RT_System',
		Creator => '1',
		RealName => 'The RT System itself',
		Comments => "Do not delete or modify this user. It is integral to RT's internal database structures",
		LastUpdatedBy => '1' );
	unless ($status) {
		die "Couldn't create RT::SystemUser: $msg";
	}
	my $equiv_group = RT::Group->new($RT_System);
	$equiv_group->LoadACLEquivalenceGroup($RT_System);

	my $superuser_ace = RT::ACE->new($CurrentUser);
	($status, $msg) = $superuser_ace->_BootstrapCreate(
		PrincipalId => $equiv_group->Id,
		PrincipalType => 'Group',
		RightName     => 'SuperUser',
		ObjectType    => 'RT::System',
		ObjectId      => '1' );
	unless ($status) {
		die "Couldn't grant RT::SystemUser with SuperUser right: $msg";
	}
}

sub __insert_data
{
	my $datafile = shift;
	require $datafile
	  || die "Couldn't load datafile '$datafile' for import: $@";
	our (@Groups, @Users, @Queues,
		@ACL, @CustomFields, @ScripActions,
		@ScripConditions, @Templates, @Scrips,
		@Attributes);

	if (@Groups) {
		for my $item (@Groups) {
			my $new_entry = RT::Group->new($RT::SystemUser);
			my ( $return, $msg ) = $new_entry->_Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@Users) {
		for my $item (@Users) {
			my $new_entry = new RT::User($RT::SystemUser);
			my ( $return, $msg ) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@Queues) {
		for my $item (@Queues) {
			my $new_entry = new RT::Queue($RT::SystemUser);
			my ( $return, $msg ) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@ACL) {
		for my $item (@ACL) {
			my ($princ, $object);

			# Global rights or Queue rights?
			if ($item->{'Queue'}) {
				$object = RT::Queue->new($RT::SystemUser);
				$object->Load( $item->{'Queue'} );
			} else {
				$object = $RT::System;
			}

			# Group rights or user rights?
			if ($item->{'GroupDomain'}) {
				$princ = RT::Group->new($RT::SystemUser);
				if ($item->{'GroupDomain'} eq 'UserDefined') {
					$princ->LoadUserDefinedGroup( $item->{'GroupId'} );
				} elsif ($item->{'GroupDomain'} eq 'SystemInternal') {
					$princ->LoadSystemInternalGroup( $item->{'GroupType'} );
				} elsif ($item->{'GroupDomain'} eq 'RT::System-Role') {
					$princ->LoadSystemRoleGroup( $item->{'GroupType'} );
				} elsif ($item->{'GroupDomain'} eq 'RT::Queue-Role' &&
					$item->{'Queue'}) {
					$princ->LoadQueueRoleGroup( Type => $item->{'GroupType'},
						Queue => $object->id);
				} else {
					$princ->Load( $item->{'GroupId'} );
				}
			} else {
				$princ = RT::User->new($RT::SystemUser);
				$princ->Load( $item->{'UserId'} );
			}

			# Grant it
			my ( $return, $msg ) = $princ->PrincipalObj->GrantRight(
				Right => $item->{'Right'},
				Object => $object );
			die "$msg" unless $return;
		}
	}
	if (@CustomFields) {
		for my $item (@CustomFields) {
			my $new_entry = new RT::CustomField($RT::SystemUser);
			my $values    = $item->{'Values'};
			delete $item->{'Values'};
			my $q     = $item->{'Queue'};
			my $q_obj = RT::Queue->new($RT::SystemUser);
			$q_obj->Load($q);
			if ( $q_obj->Id ) {
				$item->{'Queue'} = $q_obj->Id;
			}
			elsif ( $q == 0 ) {
				$item->{'Queue'} = 0;
			}
			else {
				die "Couldn't find queue '$q'" unless $q_obj->Id;
			}
			my ( $return, $msg ) = $new_entry->Create(%$item);
			die "$msg" unless $return;

			foreach my $value ( @{$values} ) {
				my ( $eval, $emsg ) = $new_entry->AddValue(%$value);
				die "$emsg" unless $eval;
			}
		}
	}
	if (@ScripActions) {
		for my $item (@ScripActions) {
			my $new_entry = RT::ScripAction->new($RT::SystemUser);
			my ($return, $msg) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@ScripConditions) {
		for my $item (@ScripConditions) {
			my $new_entry = RT::ScripCondition->new($RT::SystemUser);
			my ($return, $msg) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@Templates) {
		for my $item (@Templates) {
			my $new_entry = new RT::Template($RT::SystemUser);
			my ($return, $msg) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@Scrips) {
		for my $item (@Scrips) {
			my $new_entry = new RT::Scrip($RT::SystemUser);
			my ( $return, $msg ) = $new_entry->Create(%$item);
			die "$msg" unless $return;
		}
	}
	if (@Attributes) {
		my $sys = RT::System->new($RT::SystemUser);
		for my $item (@Attributes) {
			my $obj = delete $item->{Object}; # XXX: make this something loadable
			$obj ||= $sys;
			my ( $return, $msg ) = $obj->AddAttribute (%$item);
			die "$msg" unless $return;
		}
	}
}

=head3 db_name

Returns absolute file path to the current DB.
It is C<cwd() .'/t/data/tmp/'. test_name() .'.db'>.
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
    $obj->SetFile( FileName => $file, FromStorage => 0 );
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
It is C<cwd(). "t/data/tmp">.

=cut

sub tmpdir { return File::Spec->catdir(Cwd::cwd(), qw(lib t data shredder)) }

=head2 create_tmpdir

Creates tmp dir if doesn't exist. Returns tmpdir absolute path.

=cut

sub create_tmpdir { my $n = tmpdir(); File::Path::mkpath( $n );	return $n }

=head3 cleanup_tmp

Delete all tmp files that match C<t/data/tmp/test_name.*> mask.
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
See also perldoc lib/t/regression/shredder/utils.pl to know how to use this info.
END
}

=head3 note_not_patched

Returns note about patch if RT looks like not patched.

=cut

sub note_not_patched
{
	return <<END;
Couldn't find deleted ticket, may be you didn't patch
your RT. Please, read README about how, when and why you
have to patch your RT.
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

1;
