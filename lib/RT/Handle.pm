# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2022 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

RT::Handle - RT's database handle

=head1 SYNOPSIS

    use RT;
    BEGIN { RT::LoadConfig() };
    use RT::Handle;

=head1 DESCRIPTION

C<RT::Handle> is RT specific wrapper over one of L<DBIx::SearchBuilder::Handle>
classes. As RT works with different types of DBs we subclass repsective handler
from L<DBIx::SearchBuilder>. Type of the DB is defined by L<RT's DatabaseType
config option|RT_Config/DatabaseType>. You B<must> load this module only when
the configs have been loaded.

=cut

package RT::Handle;

use strict;
use warnings;

use File::Spec;
use Cwd;

=head1 METHODS

=head2 FinalizeDatabaseType

Sets RT::Handle's superclass to the correct subclass of
L<DBIx::SearchBuilder::Handle>, using the C<DatabaseType> configuration.

=cut

sub FinalizeDatabaseType {
    my $db_type = RT->Config->Get('DatabaseType');
    my $package = "DBIx::SearchBuilder::Handle::$db_type";

    $package->require or
        die "Unable to load DBIx::SearchBuilder database handle for '$db_type'.\n".
            "Perhaps you've picked an invalid database type or spelled it incorrectly.\n".
            $@;

    @RT::Handle::ISA = ($package);

    # We use COLLATE NOCASE to enforce case insensitivity on the normally
    # case-sensitive SQLite, LOWER() approach works, but lucks performance
    # due to absence of functional indexes
    if ($db_type eq 'SQLite') {
        no strict 'refs'; no warnings 'redefine';
        *DBIx::SearchBuilder::Handle::SQLite::CaseSensitive = sub {0};
    }
}

=head2 Connect

Connects to RT's database using credentials and options from the RT config.
Takes nothing.

=cut

sub Connect {
    my $self = shift;
    my %args = (@_);

    my $db_type = RT->Config->Get('DatabaseType');
    if ( $db_type eq 'Oracle' ) {
        $ENV{'NLS_LANG'} = "AMERICAN_AMERICA.AL32UTF8";
        $ENV{'NLS_NCHAR'} = "AL32UTF8";
    }

    $self->SUPER::Connect(
        User => RT->Config->Get('DatabaseUser'),
        Password => RT->Config->Get('DatabasePassword'),
        DisconnectHandleOnDestroy => 1,
        %args,
    );

    if ( $db_type eq 'mysql' ) {
        # set the character set
        $self->dbh->do("SET NAMES 'utf8mb4'");
    }
    elsif ( $db_type eq 'Pg' ) {
        my $version = $self->DatabaseVersion;
        ($version) = $version =~ /^(\d+\.\d+)/;
        $self->dbh->do("SET bytea_output = 'escape'") if $version >= 9.0;
    }

    $self->dbh->{'LongReadLen'} = RT->Config->Get('MaxAttachmentSize');
}

=head2 BuildDSN

Build the DSN for the RT database. Doesn't take any parameters, draws all that
from the config.

=cut


sub BuildDSN {
    my $self = shift;
    # Unless the database port is a positive integer, we really don't want to pass it.
    my $db_port = RT->Config->Get('DatabasePort');
    $db_port = undef unless (defined $db_port && $db_port =~ /^(\d+)$/);
    my $db_host = RT->Config->Get('DatabaseHost');
    $db_host = undef unless $db_host;
    my $db_name = RT->Config->Get('DatabaseName');
    my $db_type = RT->Config->Get('DatabaseType');
    $db_name = File::Spec->catfile($RT::VarPath, $db_name)
        if $db_type eq 'SQLite' && !File::Spec->file_name_is_absolute($db_name);

    my %args = (
        Host       => $db_host,
        Database   => $db_name,
        Port       => $db_port,
        Driver     => $db_type,
    );
    if ( $db_type eq 'Oracle' && $db_host ) {
        $args{'SID'} = delete $args{'Database'};
    }
    $self->SUPER::BuildDSN( %args );

    if (RT->Config->Get('DatabaseExtraDSN')) {
        my %extra = RT->Config->Get('DatabaseExtraDSN');
        $self->{'dsn'} .= ";$_=$extra{$_}"
            for sort keys %extra;
    }
    return $self->{'dsn'};
}

=head2 DSN

Returns the DSN for this handle. In order to get correct value you must
build DSN first, see L</BuildDSN>.

This is method can be called as class method, in this case creates
temporary handle object, L</BuildDSN builds DSN> and returns it.

=cut

sub DSN {
    my $self = shift;
    return $self->SUPER::DSN if ref $self;

    my $handle = $self->new;
    $handle->BuildDSN;
    return $handle->DSN;
}

=head2 SystemDSN

Returns a DSN suitable for database creates and drops
and user creates and drops.

Gets RT's DSN first (see L<DSN>) and then change it according
to requirements of a database system RT's using.

=cut

sub SystemDSN {
    my $self = shift;

    my $db_name = RT->Config->Get('DatabaseName');
    my $db_type = RT->Config->Get('DatabaseType');

    my $dsn = $self->DSN;
    if ( $db_type eq 'mysql' ) {
        # with mysql, you want to connect sans database to funge things
        $dsn =~ s/dbname=\Q$db_name//;
    }
    elsif ( $db_type eq 'Pg' ) {
        # with postgres, you want to connect to template1 database
        $dsn =~ s/dbname=\Q$db_name/dbname=template1/;
    }
    return $dsn;
}

=head2 Database compatibility and integrity checks



=cut

sub CheckIntegrity {
    my $self = shift;

    unless ($RT::Handle and $RT::Handle->dbh) {
        local $@;
        unless ( eval { RT::ConnectToDatabase(); 1 } ) {
            return (0, 'no connection', "$@");
        }
    }

    require RT::CurrentUser;
    my $test_user = RT::CurrentUser->new;
    $test_user->Load('RT_System');
    unless ( $test_user->id ) {
        return (0, 'no system user', "Couldn't find RT_System user in the DB '". $RT::Handle->DSN ."'");
    }

    $test_user = RT::CurrentUser->new;
    $test_user->Load('Nobody');
    unless ( $test_user->id ) {
        return (0, 'no nobody user', "Couldn't find Nobody user in the DB '". $RT::Handle->DSN ."'");
    }

    return 1;
}

sub CheckCompatibility {
    my $self = shift;
    my $dbh = shift;
    my $state = shift || 'post';

    my $db_type = RT->Config->Get('DatabaseType');
    if ( $db_type eq "mysql" ) {
        # Check which version we're running
        my $version = ($dbh->selectrow_array("show variables like 'version'"))[1];
        return (0, "couldn't get version of the mysql server")
            unless $version;

        # MySQL and MariaDB are both 'mysql' type.
        # the minimum version supported is MySQL 5.7.7 / MariaDB 10.2.5
        # the version string for MariaDB includes "MariaDB" in Debian/RedHat
        my $is_mariadb        = $version =~ m{mariadb}i ? 1 : 0;
        my $mysql_min_version = '5.7.7';    # so index sizes allow for VARCHAR(255) fields
        my $mariadb_min_version = '10.2.5'; # uses innodb by default

        return ( 0, "RT 5.0.0 is unsupported on MySQL versions before $mysql_min_version.  Your version is $version.")
            if !$is_mariadb && cmp_version( $version, $mysql_min_version ) < 0;
        return ( 0, "RT 5.0.0 is unsupported on MariaDB versions before $mariadb_min_version.  Your version is $version.")
            if $is_mariadb && cmp_version( $version, $mariadb_min_version ) < 0;

        # MySQL must have InnoDB support
        local $dbh->{FetchHashKeyName} = 'NAME_lc';
        my $innodb = lc($dbh->selectall_hashref("SHOW ENGINES", "engine")->{InnoDB}{support} || "no");
        if ( $innodb eq "no" ) {
            return (0, "RT requires that MySQL be compiled with InnoDB table support.\n".
                "See <http://dev.mysql.com/doc/mysql/en/innodb-storage-engine.html>\n".
                "and check that there are no 'skip-innodb' lines in your my.cnf.");
        } elsif ( $innodb eq "disabled" ) {
            return (0, "RT requires that MySQL InnoDB table support be enabled.\n".
                "Remove the 'skip-innodb' or 'innodb = OFF' line from your my.cnf file, restart MySQL, and try again.\n");
        }

        if ( $state eq 'post' ) {
            my $show_table = sub { $dbh->selectrow_arrayref("SHOW CREATE TABLE $_[0]")->[1] };
            unless ( $show_table->("Tickets") =~ /(?:ENGINE|TYPE)\s*=\s*InnoDB/i ) {
                return (0, "RT requires that all its tables be of InnoDB type. Upgrade RT tables.");
            }

            unless ( $show_table->("Attachments") =~ /\bContent\b[^,]*BLOB/i ) {
                return (0, "RT since version 3.8 has new schema for MySQL versions after 4.1.0\n"
                    ."Follow instructions in the UPGRADING.mysql file.");
            }
        }

        if ($state =~ /^(create|post)$/) {
            my $show_var = sub { $dbh->selectrow_arrayref("SHOW VARIABLES LIKE ?",{},$_[0])->[1] };

            my $max_packet = $show_var->("max_allowed_packet");
            if ($max_packet <= (5 * 1024 * 1024)) {
                $max_packet = sprintf("%.1fM", $max_packet/1024/1024);
                warn "max_allowed_packet is set to $max_packet, which limits the maximum attachment or email size that RT can process.  Consider adjusting MySQL's max_allowed_packet setting.\n";
            }
        }
    }
    return (1)
}

sub CheckSphinxSE {
    my $self = shift;

    my $dbh = $RT::Handle->dbh;
    local $dbh->{'RaiseError'} = 0;
    local $dbh->{'PrintError'} = 0;
    my $has = ($dbh->selectrow_array("show variables like 'have_sphinx'"))[1];
    $has ||= ($dbh->selectrow_array(
        "select 'yes' from INFORMATION_SCHEMA.PLUGINS where PLUGIN_NAME = 'sphinx' AND PLUGIN_STATUS='active'"
    ))[0];

    return 0 unless lc($has||'') eq "yes";
    return 1;
}

=head2 Database maintanance

=head3 CreateDatabase $DBH

Creates a new database. This method can be used as class method.

Takes DBI handle. Many database systems require special handle to
allow you to create a new database, so you have to use L<SystemDSN>
method during connection.

Fetches type and name of the DB from the config.

=cut

sub CreateDatabase {
    my $self = shift;
    my $dbh  = shift or return (0, "No DBI handle provided");
    my $db_type = RT->Config->Get('DatabaseType');
    my $db_name = RT->Config->Get('DatabaseName');

    my $status;
    if ( $db_type eq 'SQLite' ) {
        return (1, 'Skipped as SQLite doesn\'t need any action');
    }
    elsif ( $db_type eq 'Oracle' ) {
        my $db_user = RT->Config->Get('DatabaseUser');
        my $db_pass = RT->Config->Get('DatabasePassword');
        $status = $dbh->do(
            "CREATE USER $db_user IDENTIFIED BY $db_pass"
            ." default tablespace USERS"
            ." temporary tablespace TEMP"
            ." quota unlimited on USERS"
        );
        unless ( $status ) {
            return $status, "Couldn't create user $db_user identified by $db_pass."
                ."\nError: ". $dbh->errstr;
        }
        $status = $dbh->do( "GRANT connect, resource TO $db_user" );
        unless ( $status ) {
            return $status, "Couldn't grant connect and resource to $db_user."
                ."\nError: ". $dbh->errstr;
        }
        return (1, "Created user $db_user. All RT's objects should be in his schema.");
    }
    elsif ( $db_type eq 'Pg' ) {
        $status = $dbh->do("CREATE DATABASE $db_name WITH ENCODING='UNICODE' TEMPLATE template0");
    }
    elsif ( $db_type eq 'mysql' ) {
        $status = $dbh->do("CREATE DATABASE `$db_name` DEFAULT CHARACTER SET utf8");
    }
    else {
        $status = $dbh->do("CREATE DATABASE $db_name");
    }
    return ($status, $DBI::errstr);
}

=head3 DropDatabase $DBH

Drops RT's database. This method can be used as class method.

Takes DBI handle as first argument. Many database systems require
a special handle to allow you to drop a database, so you may have
to use L<SystemDSN> when acquiring the DBI handle.

Fetches the type and name of the database from the config.

=cut

sub DropDatabase {
    my $self = shift;
    my $dbh  = shift or return (0, "No DBI handle provided");

    my $db_type = RT->Config->Get('DatabaseType');
    my $db_name = RT->Config->Get('DatabaseName');

    if ( $db_type eq 'Oracle' ) {
        my $db_user = RT->Config->Get('DatabaseUser');
        my $status = $dbh->do( "DROP USER $db_user CASCADE" );
        unless ( $status ) {
            return 0, "Couldn't drop user $db_user."
                ."\nError: ". $dbh->errstr;
        }
        return (1, "Successfully dropped user '$db_user' with his schema.");
    }
    elsif ( $db_type eq 'SQLite' ) {
        my $path = $db_name;
        $path = "$RT::VarPath/$path" unless substr($path, 0, 1) eq '/';
        unlink $path or return (0, "Couldn't remove '$path': $!");
        return (1);
    } elsif ( $db_type eq 'mysql' ) {
        $dbh->do("DROP DATABASE `$db_name`")
            or return (0, $DBI::errstr);
    } else {
        $dbh->do("DROP DATABASE ". $db_name)
            or return (0, $DBI::errstr);
    }
    return (1);
}

=head2 InsertACL

=cut

sub InsertACL {
    my $self      = shift;
    my $dbh       = shift;
    my $base_path = shift || $RT::EtcPath;

    my $db_type = RT->Config->Get('DatabaseType');
    return (1) if $db_type eq 'SQLite';

    $dbh = $self->dbh if !$dbh && ref $self;
    return (0, "No DBI handle provided") unless $dbh;

    return (0, "'$base_path' doesn't exist") unless -e $base_path;

    my $path;
    if ( -d $base_path ) {
        $path = File::Spec->catfile( $base_path, "acl.$db_type");
        $path = $self->GetVersionFile($dbh, $path);

        $path = File::Spec->catfile( $base_path, "acl")
            unless $path && -e $path;
        return (0, "Couldn't find ACLs for $db_type")
            unless -e $path;
    } else {
        $path = $base_path;
    }

    # Get the full path since . is no longer in @INC after perl 5.24
    $path = Cwd::abs_path($path);

    local *acl;
    do $path || return (0, "Couldn't load ACLs: " . $@);
    my @acl = acl($dbh);
    foreach my $statement (@acl) {
        my $sth = $dbh->prepare($statement)
            or return (0, "Couldn't prepare SQL query:\n $statement\n\nERROR: ". $dbh->errstr);
        unless ( $sth->execute ) {
            return (0, "Couldn't run SQL query:\n $statement\n\nERROR: ". $sth->errstr);
        }
    }
    return (1);
}

=head2 InsertSchema

=cut

sub InsertSchema {
    my $self = shift;
    my $dbh  = shift;
    my $base_path = (shift || $RT::EtcPath);

    $dbh = $self->dbh if !$dbh && ref $self;
    return (0, "No DBI handle provided") unless $dbh;

    my $db_type = RT->Config->Get('DatabaseType');

    my $file;
    if ( -d $base_path ) {
        $file = $base_path . "/schema." . $db_type;
    } else {
        $file = $base_path;
    }

    $file = $self->GetVersionFile( $dbh, $file );
    unless ( $file ) {
        return (0, "Couldn't find schema file(s) '$file*'");
    }
    unless ( -f $file && -r $file ) {
        return (0, "File '$file' doesn't exist or couldn't be read");
    }

    my (@schema);

    open( my $fh_schema, '<', $file ) or die $!;

    my $has_local = 0;
    open( my $fh_schema_local, "<" . $self->GetVersionFile( $dbh, $RT::LocalEtcPath . "/schema." . $db_type ))
        and $has_local = 1;

    my $statement = "";
    foreach my $line ( <$fh_schema>, ($_ = ';;'), $has_local? <$fh_schema_local>: () ) {
        $line =~ s/\#.*//g;
        $line =~ s/--.*//g;
        $statement .= $line;
        if ( $line =~ /;(\s*)$/ ) {
            $statement =~ s/;(\s*)$//g;
            push @schema, $statement;
            $statement = "";
        }
    }
    close $fh_schema; close $fh_schema_local;

    if ( $db_type eq 'Oracle' ) {
        my $db_user = RT->Config->Get('DatabaseUser');
        my $status = $dbh->do( "ALTER SESSION SET CURRENT_SCHEMA=$db_user" );
        unless ( $status ) {
            return $status, "Couldn't set current schema to $db_user."
                ."\nError: ". $dbh->errstr;
        }
    }

    local $SIG{__WARN__} = sub {};
    my $is_local = 0;
    $dbh->begin_work or return (0, "Couldn't begin transaction: ". $dbh->errstr);
    foreach my $statement (@schema) {
        if ( $statement =~ /^\s*;$/ ) {
            $is_local = 1; next;
        }

        my $sth = $dbh->prepare($statement)
            or return (0, "Couldn't prepare SQL query:\n$statement\n\nERROR: ". $dbh->errstr);
        unless ( $sth->execute or $is_local ) {
            return (0, "Couldn't run SQL query:\n$statement\n\nERROR: ". $sth->errstr);
        }
    }
    $dbh->commit or return (0, "Couldn't commit transaction: ". $dbh->errstr);
    return (1);
}

sub InsertIndexes {
    my $self      = shift;
    my $dbh       = shift;
    my $base_path = shift || $RT::EtcPath;

    my $db_type = RT->Config->Get('DatabaseType');

    $dbh = $self->dbh if !$dbh && ref $self;
    return (0, "No DBI handle provided") unless $dbh;

    return (0, "'$base_path' doesn't exist") unless -e $base_path;

    my $path;
    if ( -d $base_path ) {
        $path = File::Spec->catfile( $base_path, "indexes");
        return (0, "Couldn't find indexes file")
            unless -e $path;
    } else {
        $path = $base_path;
    }

    if ( $db_type eq 'Oracle' ) {
        my $db_user = RT->Config->Get('DatabaseUser');
        my $status = $dbh->do( "ALTER SESSION SET CURRENT_SCHEMA=$db_user" );
        unless ( $status ) {
            return $status, "Couldn't set current schema to $db_user."
                ."\nError: ". $dbh->errstr;
        }
    }

    # Get the full path since . is no longer in @INC after perl 5.24
    $path = Cwd::abs_path($path);

    local $@;
    eval { require $path; 1 }
        or return (0, "Couldn't execute '$path': " . $@);
    return (1);
}

=head1 GetVersionFile

Takes base name of the file as argument, scans for <base name>-<version> named
files and returns file name with closest version to the version of the RT DB.

=cut

sub GetVersionFile {
    my $self = shift;
    my $dbh = shift;
    my $base_name = shift;

    my $db_version = ref $self
        ? $self->DatabaseVersion
        : do {
            my $tmp = RT::Handle->new;
            $tmp->dbh($dbh);
            $tmp->DatabaseVersion;
        };

    require File::Glob;
    my @files = File::Glob::bsd_glob("$base_name*");
    return '' unless @files;

    my %version = map { $_ =~ /\.\w+-([-\w\.]+)$/; ($1||0) => $_ } @files;
    my $version;
    foreach ( reverse sort cmp_version keys %version ) {
        if ( cmp_version( $db_version, $_ ) >= 0 ) {
            $version = $_;
            last;
        }
    }

    return defined $version? $version{ $version } : undef;
}

{ my %word = (
    a     => -4,
    alpha => -4,
    b     => -3,
    beta  => -3,
    pre   => -2,
    rc    => -1,
    head  => 9999,
);
sub cmp_version($$) {
    my ($a, $b) = (@_);
    my @a = grep defined, map { /^[0-9]+$/? $_ : /^[a-zA-Z]+$/? $word{$_}|| -10 : undef }
        split /([^0-9]+)/, $a;
    my @b = grep defined, map { /^[0-9]+$/? $_ : /^[a-zA-Z]+$/? $word{$_}|| -10 : undef }
        split /([^0-9]+)/, $b;
    @a > @b
        ? push @b, (0) x (@a-@b)
        : push @a, (0) x (@b-@a);
    for ( my $i = 0; $i < @a; $i++ ) {
        return $a[$i] <=> $b[$i] if $a[$i] <=> $b[$i];
    }
    return 0;
}

sub version_words {
    return keys %word;
}

}


=head2 InsertInitialData

Inserts system objects into RT's DB, like system user or 'nobody',
internal groups and other records required. However, this method
doesn't insert any real users like 'root' and you have to use
InsertData or another way to do that.

Takes no arguments. Returns status and message tuple.

It's safe to call this method even if those objects already exist.

=cut

sub InsertInitialData {
    my $self    = shift;

    my @warns;

    # avoid trying to canonicalize system users through ExternalAuth
    no warnings 'redefine';
    local *RT::User::CanonicalizeUserInfo = sub { 1 };

    # create RT_System user and grant him rights
    {
        require RT::CurrentUser;

        my $test_user = RT::User->new( RT::CurrentUser->new() );
        $test_user->Load('RT_System');
        if ( $test_user->id ) {
            push @warns, "Found system user in the DB.";
        }
        else {
            my $user = RT::User->new( RT::CurrentUser->new() );
            my ( $val, $msg ) = $user->_BootstrapCreate(
                Name     => 'RT_System',
                RealName => 'The RT System itself',
                Comments => 'Do not delete or modify this user. '
                    . 'It is integral to RT\'s internal database structures',
                Creator  => '1',
                LastUpdatedBy => '1',
            );
            return ($val, $msg) unless $val;
        }
        DBIx::SearchBuilder::Record::Cachable->FlushCache;
    }

    # init RT::SystemUser and RT::System objects
    RT::InitSystemObjects();
    unless ( RT->SystemUser->id ) {
        return (0, "Couldn't load system user");
    }

    # grant SuperUser right to system user
    {
        my $test_ace = RT::ACE->new( RT->SystemUser );
        $test_ace->LoadByCols(
            PrincipalId   => ACLEquivGroupId( RT->SystemUser->Id ),
            PrincipalType => 'Group',
            RightName     => 'SuperUser',
            ObjectType    => 'RT::System',
            ObjectId      => 1,
        );
        if ( $test_ace->id ) {
            push @warns, "System user has global SuperUser right.";
        } else {
            my $ace = RT::ACE->new( RT->SystemUser );
            my ( $val, $msg ) = $ace->_BootstrapCreate(
                PrincipalId   => ACLEquivGroupId( RT->SystemUser->Id ),
                PrincipalType => 'Group',
                RightName     => 'SuperUser',
                ObjectType    => 'RT::System',
                ObjectId      => 1,
            );
            return ($val, $msg) unless $val;
        }
        DBIx::SearchBuilder::Record::Cachable->FlushCache;
    }

    # system groups
    # $self->loc('Everyone'); # For the string extractor to get a string to localize
    # $self->loc('Privileged'); # For the string extractor to get a string to localize
    # $self->loc('Unprivileged'); # For the string extractor to get a string to localize
    foreach my $name (qw(Everyone Privileged Unprivileged)) {
        my $group = RT::Group->new( RT->SystemUser );
        $group->LoadSystemInternalGroup( $name );
        if ( $group->id ) {
            push @warns, "System group '$name' already exists.";
            next;
        }

        $group = RT::Group->new( RT->SystemUser );
        my ( $val, $msg ) = $group->_Create(
            Domain      => 'SystemInternal',
            Description => 'Pseudogroup for internal use',  # loc
            Name        => $name,
            Instance    => '',
        );
        return ($val, $msg) unless $val;
    }

    # nobody
    {
        my $user = RT::User->new( RT->SystemUser );
        $user->Load('Nobody');
        if ( $user->id ) {
            push @warns, "Found 'Nobody' user in the DB.";
        }
        else {
            my ( $val, $msg ) = $user->Create(
                Name     => 'Nobody',
                RealName => 'Nobody in particular',
                Comments => 'Do not delete or modify this user. It is integral '
                    .'to RT\'s internal data structures',
                Privileged => 0,
            );
            return ($val, $msg) unless $val;
        }

        if ( $user->HasRight( Right => 'OwnTicket', Object => $RT::System ) ) {
            push @warns, "User 'Nobody' has global OwnTicket right.";
        } else {
            my ( $val, $msg ) = $user->PrincipalObj->GrantRight(
                Right => 'OwnTicket',
                Object => $RT::System,
            );
            return ($val, $msg) unless $val;
        }
    }

    # rerun to get init Nobody as well
    RT::InitSystemObjects();

    # system role groups
    foreach my $name (qw(Owner Requestor Cc AdminCc)) {
        my $group = RT->System->RoleGroup( $name );
        if ( $group->id ) {
            push @warns, "System role '$name' already exists.";
            next;
        }

        $group = RT::Group->new( RT->SystemUser );
        my ( $val, $msg ) = $group->CreateRoleGroup(
            Name                => $name,
            Object              => RT->System,
            Description         => 'SystemRolegroup for internal use',  # loc
            InsideTransaction   => 0,
        );
        return ($val, $msg) unless $val;
    }

    # assets role groups
    foreach my $name (RT::Asset->Roles) {
        next if $name eq "Owner";

        my $group = RT->System->RoleGroup( $name );
        if ( $group->id ) {
            push @warns, "Assets role '$name' already exists.";
            next;
        }

        $group = RT::Group->new( RT->SystemUser );
        my ($val, $msg) = $group->CreateRoleGroup(
            Object              => RT->System,
            Name                => $name,
            InsideTransaction   => 0,
        );
        return ($val, $msg) unless $val;
    }

    push @warns, "You appear to have a functional RT database."
        if @warns;

    return (1, join "\n", @warns);
}

=head2 InsertData

Load some sort of data into the database, takes path to a file.

=cut

sub InsertData {
    my $self     = shift;
    my $datafile = shift;
    my $root_password = shift;
    my %args     = (
        disconnect_after => 1,
        admin_dbh        => undef,
        @_
    );

    # Slurp in stuff to insert from the datafile. Possible things to go in here:-
    our (@Groups, @Users, @Members, @ACL, @Queues, @Classes, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @CustomRoles, @Scrips, @Attributes, @Initial, @Final,
           @Catalogs, @Assets, @Articles, @OCFVs, @Topics, @ObjectTopics);
    local (@Groups, @Users, @Members, @ACL, @Queues, @Classes, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @CustomRoles, @Scrips, @Attributes, @Initial, @Final,
           @Catalogs, @Assets, @Articles, @OCFVs, @Topics, @ObjectTopics);

    local $@;

    # Get the full path since . is no longer in @INC after perl 5.24
    $datafile = Cwd::abs_path($datafile);
    $RT::Logger->debug("Going to load '$datafile' data file");

    my $datafile_content = do {
        local $/;
        open (my $f, '<:encoding(UTF-8)', $datafile)
            or die "Cannot open initialdata file '$datafile' for read: $@";
        <$f>;
    };

    my $format_handler;
    my $handlers = RT->Config->Get('InitialdataFormatHandlers');

    foreach my $handler_candidate (@$handlers) {
        next if $handler_candidate eq 'perl';
        $handler_candidate->require
            or die "Config option InitialdataFormatHandlers lists '$handler_candidate', but it failed to load:\n$@\n";

        if ($handler_candidate->CanLoad($datafile_content)) {
            $RT::Logger->debug("Initialdata file '$datafile' can be loaded by $handler_candidate");
            $format_handler = $handler_candidate;
            last;
        } else {
            $RT::Logger->debug("Initialdata file '$datafile' can not be loaded by $handler_candidate");
        }
    }

    if ( $format_handler ) {
        $format_handler->Load(
            $datafile_content,
            {
                Groups          => \@Groups,
                Users           => \@Users,
                Members         => \@Members,
                ACL             => \@ACL,
                Queues          => \@Queues,
                Classes         => \@Classes,
                ScripActions    => \@ScripActions,
                ScripConditions => \@ScripConditions,
                Templates       => \@Templates,
                CustomFields    => \@CustomFields,
                CustomRoles     => \@CustomRoles,
                Scrips          => \@Scrips,
                Attributes      => \@Attributes,
                Initial         => \@Initial,
                Final           => \@Final,
                Catalogs        => \@Catalogs,
                Assets          => \@Assets,
                Articles        => \@Articles,
                OCFVs           => \@OCFVs,
                Topics          => \@Topics,
                ObjectTopics    => \@ObjectTopics,
            },
        ) or return (0, "Couldn't load data from '$datafile' for import:\n\nERROR:" . $@);
    }

    if ( !$format_handler and grep(/^perl$/, @$handlers) ) {
        # Use perl-style initialdata
        # Note: eval of perl initialdata should only be done once

        # Get the full path since . is no longer in @INC after perl 5.24
        $datafile = Cwd::abs_path($datafile);
        eval { require $datafile }
          or return (0, "Couldn't load data from '$datafile':\nERROR:" . $@ . "\n\nDo you have the correct initialdata handler in RT_Config for this type of file?");
    }

    if ( @Initial ) {
        $RT::Logger->debug("Running initial actions...");
        foreach ( @Initial ) {
            local $@;
            eval { $_->( admin_dbh => $args{admin_dbh} ); 1 } or return (0, "One of initial functions failed: $@");
        }
        $RT::Logger->debug("Done.");
    }
    if ( @Groups ) {
        $RT::Logger->debug("Creating groups...");
        foreach my $item (@Groups) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Group', $item,
                    { CustomFields => \@OCFVs, Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $ocfvs = delete $item->{ CustomFields };

            my $new_entry = RT::Group->new( RT->SystemUser );
            $item->{'Domain'} ||= 'UserDefined';
            my $member_of = delete $item->{'MemberOf'};
            my $members = delete $item->{'Members'};
            my ( $return, $msg ) = $new_entry->_Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
                next;
            } else {
                $RT::Logger->debug($return .".");
                $_->{Object} = $new_entry for @{$attributes || []};
                push @Attributes, @{$attributes || []};
                $_->{Object} = $new_entry for @{$ocfvs || []};
                push @OCFVs, @{$ocfvs || []};
            }
            if ( $member_of ) {
                $member_of = [ $member_of ] unless ref $member_of eq 'ARRAY';
                foreach( @$member_of ) {
                    my $parent = RT::Group->new(RT->SystemUser);
                    if ( ref $_ eq 'HASH' ) {
                        $parent->LoadByCols( %$_ );
                    }
                    elsif ( !ref $_ ) {
                        $parent->LoadUserDefinedGroup( $_ );
                    }
                    else {
                        $RT::Logger->error(
                            "(Error: wrong format of MemberOf field."
                            ." Should be name of user defined group or"
                            ." hash reference with 'column => value' pairs."
                            ." Use array reference to add to multiple groups)"
                        );
                        next;
                    }
                    unless ( $parent->Id ) {
                        $RT::Logger->error("(Error: couldn't load group to add member)");
                        next;
                    }
                    my ( $return, $msg ) = $parent->AddMember( $new_entry->Id );
                    unless ( $return ) {
                        $RT::Logger->error( $msg );
                    } else {
                        $RT::Logger->debug( $return ."." );
                    }
                }
            }
            push @Members, map { +{Group => $new_entry->id,
                                   Class => "RT::User", Name => $_} }
                @{ $members->{Users} || [] };
            push @Members, map { +{Group => $new_entry->id,
                                   Class => "RT::Group", Name => $_} }
                @{ $members->{Groups} || [] };
        }
        $RT::Logger->debug("done.");
    }
    if ( @Users ) {
        $RT::Logger->debug("Creating users...");
        foreach my $item (@Users) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::User', $item,
                    { CustomFields => \@OCFVs, Attributes => \@Attributes } );
                next;
            }

            my $member_of = delete $item->{'MemberOf'};
            if ( $item->{'Name'} eq 'root' && $root_password ) {
                $item->{'Password'} = $root_password;
            }
            my $attributes = delete $item->{ Attributes };
            my $ocfvs = delete $item->{ CustomFields };

            no warnings 'redefine';
            local *RT::User::CanonicalizeUserInfo = sub { 1 }
                if delete $item->{ SkipCanonicalize };

            my $new_entry = RT::User->new( RT->SystemUser );
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );
                $_->{Object} = $new_entry for @{$attributes || []};
                push @Attributes, @{$attributes || []};
                $_->{Object} = $new_entry for @{$ocfvs || []};
                push @OCFVs, @{$ocfvs || []};
            }
            if ( $member_of ) {
                $member_of = [ $member_of ] unless ref $member_of eq 'ARRAY';
                foreach( @$member_of ) {
                    my $parent = RT::Group->new($RT::SystemUser);
                    if ( ref $_ eq 'HASH' ) {
                        $parent->LoadByCols( %$_ );
                    }
                    elsif ( !ref $_ ) {
                        $parent->LoadUserDefinedGroup( $_ );
                    }
                    else {
                        $RT::Logger->error(
                            "(Error: wrong format of MemberOf field."
                            ." Should be name of user defined group or"
                            ." hash reference with 'column => value' pairs."
                            ." Use array reference to add to multiple groups)"
                        );
                        next;
                    }
                    unless ( $parent->Id ) {
                        $RT::Logger->error("(Error: couldn't load group to add member)");
                        next;
                    }
                    my ( $return, $msg ) = $parent->AddMember( $new_entry->Id );
                    unless ( $return ) {
                        $RT::Logger->error( $msg );
                    } else {
                        $RT::Logger->debug( $return ."." );
                    }
                }
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @Queues ) {
        $RT::Logger->debug("Creating queues...");
        for my $item (@Queues) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Queue', $item,
                    { CustomFields => \@OCFVs, Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $ocfvs = delete $item->{ CustomFields };

            my $new_entry = RT::Queue->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );
                $_->{Object} = $new_entry for @{$attributes || []};
                push @Attributes, @{$attributes || []};
                $_->{Object} = $new_entry for @{$ocfvs || []};
                push @OCFVs, @{$ocfvs || []};
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @Classes ) {
        $RT::Logger->debug("Creating classes...");
        for my $item (@Classes) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Class', $item, { Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            # Back-compat for the old "Queue" argument
            if ( exists $item->{'Queue'} ) {
                $item->{'ApplyTo'} = delete $item->{'Queue'};
            }

            my $apply_to = (delete $item->{'ApplyTo'}) || 0;
            $apply_to = [ $apply_to ] unless ref $apply_to;

            my $new_entry = RT::Class->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );

                for my $name ( @{ $apply_to } ) {
                    if ( !$name ) {
                        ( $return, $msg) = $new_entry->AddToObject( RT::Queue->new(RT->SystemUser) );
                        $RT::Logger->error( $msg ) unless $return;
                    } else {
                        my $queue = RT::Queue->new( RT->SystemUser );
                        $queue->Load( $name );
                        if ( $queue->id ) {
                            ( $return, $msg) = $new_entry->AddToObject( $queue );
                            $RT::Logger->error( $msg ) unless $return;
                        }
                        else {
                            $RT::Logger->error( "Could not find RT::Queue $name to apply " . $new_entry->Name . " to" );
                        }
                    }
                }
                $_->{Object} = $new_entry for @{$attributes || []};
                push @Attributes, @{$attributes || []};
            }
        }
        $RT::Logger->debug("done.");
    }

    if ( @Catalogs ) {
        $RT::Logger->debug("Creating Catalogs...");

        for my $item (@Catalogs) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Catalog', $item, { Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $new_entry = RT::Catalog->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }

            $_->{Object} = $new_entry for @{$attributes || []};
            push @Attributes, @{$attributes || []};
        }

        $RT::Logger->debug("done.");
    }

    if ( @Topics ) {
        $RT::Logger->debug("Creating Topics...");

        for my $item ( @Topics ) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Topic', $item );
                next;
            }

            my $obj = delete $item->{Object};

            if ( ref $obj eq 'CODE' ) {
                $obj = $obj->();
            }
            elsif ( !ref $obj ) {
                my $class = RT::Class->new(RT->SystemUser);
                $class->Load($obj);
                if ( $class->id ) {
                    $obj = $class;
                }
            }

            if ( !$obj ) {
                $RT::Logger->error( "Invalid class $obj" );
                next;
            }

            if ( $item->{Parent} && $item->{Parent} =~ /\D/ ) {
                my $topic = RT::Topic->new( RT->SystemUser );
                $topic->LoadByCols( Name => $item->{Parent} );
                if ( $topic->id ) {
                    $item->{Parent} = $topic->id;
                }
                else {
                    $RT::Logger->error( "Invalid parent $item->{Parent}" );
                    next;
                }
            }

            my $new_entry  = RT::Topic->new( RT->SystemUser );
            my ( $return, $msg ) = $new_entry->Create( %$item, ObjectType => ref $obj, ObjectId => $obj->id );
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return . "." );
            }
        }

        $RT::Logger->debug("done.");
    }

    if ( @Assets ) {
        $RT::Logger->debug("Creating Assets...");

        for my $item (@Assets) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Asset', $item,
                    { CustomFields => \@OCFVs, Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $ocfvs = delete $item->{ CustomFields };

            my $new_entry = RT::Asset->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }

            $_->{Object} = $new_entry for @{$attributes || []};
            push @Attributes, @{$attributes || []};
            $_->{Object} = $new_entry for @{$ocfvs || []};
            push @OCFVs, @{$ocfvs || []};
        }

        $RT::Logger->debug("done.");
    }

    if ( @Articles ) {
        $RT::Logger->debug("Creating Articles...");

        for my $item (@Articles) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Article', $item,
                    { CustomFields => \@OCFVs, Attributes => \@Attributes, ObjectTopics => \@ObjectTopics } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $ocfvs = delete $item->{ CustomFields };
            my $object_topics = delete $item->{ Topics };

            my $new_entry = RT::Article->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }

            $_->{Object} = $new_entry for @{$attributes || []};
            push @Attributes, @{$attributes || []};
            $_->{Object} = $new_entry for @{$ocfvs || []};
            push @OCFVs, @{$ocfvs || []};
            $_->{Object} = $new_entry for @{$object_topics || []};
            push @ObjectTopics, @{$object_topics || []};
        }

        $RT::Logger->debug("done.");
    }


    if ( @CustomFields ) {
        $RT::Logger->debug("Creating custom fields...");
        my @deferred_BasedOn;

        for my $item ( @CustomFields ) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::CustomField', $item, { Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $new_entry = RT::CustomField->new( RT->SystemUser );
            my $values    = delete $item->{'Values'};

            # Back-compat for the old "Queue" argument
            if ( exists $item->{'Queue'} ) {
                $item->{'LookupType'} ||= 'RT::Queue-RT::Ticket';
                $RT::Logger->warn("Queue provided for non-ticket custom field")
                    unless $item->{'LookupType'} =~ /^RT::Queue-/;
                $item->{'ApplyTo'} = delete $item->{'Queue'};
            }

            my $apply_to = delete $item->{'ApplyTo'};

            if ( $item->{'BasedOn'} ) {
                if ( $item->{'BasedOn'} =~ /^\d+$/) {
                    # Already have an ID -- should be fine
                } elsif ( $item->{'LookupType'} ) {
                    my $basedon = RT::CustomField->new($RT::SystemUser);
                    my ($ok, $msg ) = $basedon->LoadByCols(
                        Name => $item->{'BasedOn'},
                        LookupType => $item->{'LookupType'},
                        Disabled => 0 );
                    if ($ok) {
                        $item->{'BasedOn'} = $basedon->Id;
                    } else {
                        push @deferred_BasedOn, [$new_entry, delete $item->{'BasedOn'}];
                    }
                } else {
                    $RT::Logger->error("Unable to load CF $item->{BasedOn} because no LookupType was specified.  Skipping BasedOn");
                    delete $item->{'BasedOn'};
                }

            } 

            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless( $return ) {
                $RT::Logger->error( $msg );
                next;
            }

            foreach my $value ( @{$values} ) {
                ( $return, $msg ) = $new_entry->AddValue(%$value);
                $RT::Logger->error( $msg ) unless $return;
            }

            my $class = $new_entry->RecordClassFromLookupType;
            if ($class) {
                $apply_to = [ $apply_to ] unless ref $apply_to;
                for my $name ( @{ $apply_to } ) {
                    my $ocf = RT::ObjectCustomField->new(RT->SystemUser);

                    # global CF
                    if (!$name) {
                        ( $return, $msg ) = $ocf->Create(
                            CustomField => $new_entry->Id,
                        );
                        $RT::Logger->error( $msg ) unless $return and $ocf->Id;
                    }
                    else {
                        if ($new_entry->IsOnlyGlobal) {
                            $RT::Logger->warn("ApplyTo '$name' provided for global custom field ".$new_entry->Name );
                        }

                        my $obj = $class->new(RT->SystemUser);
                        $obj->Load($name);
                        if ( $obj->Id ) {
                            ( $return, $msg ) = $ocf->Create(
                                CustomField => $new_entry->Id,
                                ObjectId    => $obj->Id,
                            );
                            $RT::Logger->error( $msg ) unless $return and $ocf->Id;
                        } else {
                            $RT::Logger->error("Could not find $class $name to apply ".$new_entry->Name." to" );
                        }
                    }
                }
            }

            $_->{Object} = $new_entry for @{$attributes || []};
            push @Attributes, @{$attributes || []};
        }

        for ( @deferred_BasedOn ) {
            my ($cf, $name) = @$_;
            my $basedon = RT::CustomField->new($RT::SystemUser);
            my ($ok, $msg ) = $basedon->LoadByCols(
                Name => $name,
                LookupType => $cf->LookupType,
                Disabled => 0,
            );
            if ($ok) {
                ($ok, $msg) = $cf->SetBasedOn($basedon->Id);
                $RT::Logger->error("Unable to set $name as a " . $cf->LookupType . " BasedOn CF: $msg") if !$ok;
            }
            else {
                $RT::Logger->error("Unable to load $name as a " . $cf->LookupType . " CF.  Skipping BasedOn: $msg");
            }
        }

        $RT::Logger->debug("done.");
    }

    if ( @CustomRoles ) {
        $RT::Logger->debug("Creating custom roles...");
        for my $item ( @CustomRoles ) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::CustomRole', $item, { Attributes => \@Attributes } );
                next;
            }

            my $attributes = delete $item->{ Attributes };
            my $apply_to = delete $item->{'ApplyTo'};

            my $new_entry = RT::CustomRole->new( RT->SystemUser );

            my ( $ok, $msg ) = $new_entry->Create(%$item, Disabled => 0);
            if (!$ok) {
                $RT::Logger->error($msg);
                next;
            }

            if ($apply_to) {
                $apply_to = [ $apply_to ] unless ref $apply_to;
                for my $name ( @{ $apply_to } ) {
                    my ($ok, $msg) = $new_entry->AddToObject($name);
                    $RT::Logger->error( $msg ) if !$ok;
                }
            }

            $_->{Object} = $new_entry for @{$attributes || []};
            push @Attributes, @{$attributes || []};

            if ( $item->{Disabled} ) {
                ( $ok, $msg ) = $new_entry->SetDisabled( $item->{Disabled} );
                if ( !$ok ) {
                    $RT::Logger->error( "Couldn't set Disabled to custom role $item->{Name}: $msg" );
                }
            }
        }

        $RT::Logger->debug("done.");
    }

    if ( @Members ) {
        $RT::Logger->debug("Adding users and groups to groups...");
        for my $item (@Members) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::GroupMember', $item );
                next;
            }

            my $name = delete $item->{Group};
            my $domain = delete $item->{GroupDomain} || 'UserDefined';
            my $instance = delete $item->{GroupInstance};

            if ($domain =~ /^(.+)-Role$/) {
                 my $class = $1;
                 if (!$class->DOES("RT::Record::Role::Roles")) {
                     RT->Logger->error("Invalid group domain '$domain' for group $name; skipping adding membership");
                     next;
                 }
                 my $object = $class->new(RT->SystemUser);
                 $object->Load($instance);
                 $instance = $object->Id;
            }

            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadByCols(
                $name =~ /\D/ ? ( Name => $name ) : ( id => $name ),
                Domain => $domain,
                (defined $instance ? (Instance => $instance) : ()),
            );
            unless ($group->Id) {
                RT->Logger->error("Unable to find $domain group '$name' to add members to");
                next;
            }

            my $class = delete $item->{Class} || 'RT::User';
            my $member = $class->new( RT->SystemUser );
            $item->{Domain} = 'UserDefined' if $member->isa("RT::Group");
            $member->LoadByCols( %$item );
            unless ($member->Id) {
                RT->Logger->error("Unable to find $class '".($item->{id} || $item->{Name})."' to add to ".$group->Name);
                next;
            }

            my ( $return, $msg) = $group->AddMember( $member->PrincipalObj->Id );
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );
            }
        }
    }

    if ( @ACL ) {
        $RT::Logger->debug("Creating ACL...");
        for my $item (@ACL) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::ACE', $item );
                next;
            }

            my ($princ, $object);

            # Global rights or Queue rights?
            if ( $item->{'CF'} ) {
                $object = RT::CustomField->new( RT->SystemUser );
                my @columns = ( Name => $item->{'CF'} );
                push @columns, LookupType => $item->{'LookupType'} if $item->{'LookupType'};
                push @columns, ObjectId => $item->{'ObjectId'} if $item->{'ObjectId'};
                push @columns, Queue => $item->{'Queue'} if $item->{'Queue'} and not ref $item->{'Queue'};
                my ($ok, $msg) = $object->LoadByName( @columns );
                unless ( $ok ) {
                    RT->Logger->error("Unable to load CF ".$item->{CF}.": $msg");
                    next;
                }
            } elsif ( $item->{'Queue'} ) {
                $object = RT::Queue->new(RT->SystemUser);
                my ($ok, $msg) = $object->Load( $item->{'Queue'} );
                unless ( $ok ) {
                    RT->Logger->error("Unable to load queue ".$item->{Queue}.": $msg");
                    next;
                }
            } elsif ( $item->{'Group'} || ($item->{ObjectType}||'') eq 'RT::Group') {
                my $name = $item->{'Group'} || $item->{ObjectId};
                $object = RT::Group->new(RT->SystemUser);
                my ($ok, $msg) = $object->LoadUserDefinedGroup($name);
                unless ( $ok ) {
                    RT->Logger->error("Unable to load user-defined group $name: $msg");
                    next;
                }
            } elsif ( $item->{ObjectType} and $item->{ObjectId}) {
                $object = $item->{ObjectType}->new(RT->SystemUser);
                my ($ok, $msg) = $object->Load( $item->{ObjectId} );
                unless ( $ok ) {
                    RT->Logger->error("Unable to load ".$item->{ObjectType}." ".$item->{ObjectId}.": $msg");
                    next;
                }
            } else {
                $object = $RT::System;
            }

            # Group rights or user rights?
            if ( $item->{'GroupDomain'} ) {
                if (my $role_name = delete $item->{CustomRole}) {
                    my $role = RT::CustomRole->new(RT->SystemUser);
                    $role->Load($role_name);
                    $item->{'GroupType'} = $role->GroupType;
                }

                $princ = RT::Group->new(RT->SystemUser);
                if ( $item->{'GroupDomain'} eq 'UserDefined' ) {
                  $princ->LoadUserDefinedGroup( $item->{'GroupId'} );
                } elsif ( $item->{'GroupDomain'} eq 'SystemInternal' ) {
                  $princ->LoadSystemInternalGroup( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::System-Role' ) {
                  $princ->LoadRoleGroup( Object => RT->System, Name => $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} =~ /-Role$/ ) {
                  $princ->LoadRoleGroup( Object => $object, Name => $item->{'GroupType'} );
                } else {
                  $princ->Load( $item->{'GroupId'} );
                }
                unless ( $princ->Id ) {
                    RT->Logger->error("Unable to load Group: GroupDomain => $item->{GroupDomain}, GroupId => $item->{GroupId}, Queue => $item->{Queue}");
                    next;
                }
            } else {
                $princ = RT::User->new(RT->SystemUser);
                my ($ok, $msg) = $princ->Load( $item->{'UserId'} );
                unless ( $ok ) {
                    RT->Logger->error("Unable to load user: $item->{UserId} : $msg");
                    next;
                }
            }

            $item->{Right} = delete $item->{RightName} if $item->{RightName};

            # Grant it
            my @rights = ref($item->{'Right'}) eq 'ARRAY' ? @{$item->{'Right'}} : $item->{'Right'};
            foreach my $right ( @rights ) {
                my ( $return, $msg ) = $princ->PrincipalObj->GrantRight(
                    Right => $right,
                    Object => $object
                );
                unless ( $return ) {
                    $RT::Logger->error( $msg );
                }
                else {
                    $RT::Logger->debug( $return ."." );
                }
            }
        }
        $RT::Logger->debug("done.");
    }

    if ( @ScripActions ) {
        $RT::Logger->debug("Creating ScripActions...");

        for my $item (@ScripActions) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::ScripAction', $item );
                next;
            }

            my $new_entry = RT::ScripAction->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }

        $RT::Logger->debug("done.");
    }

    if ( @ScripConditions ) {
        $RT::Logger->debug("Creating ScripConditions...");

        for my $item (@ScripConditions) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::ScripCondition', $item );
                next;
            }

            my $new_entry = RT::ScripCondition->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }

        $RT::Logger->debug("done.");
    }

    if ( @Templates ) {
        $RT::Logger->debug("Creating templates...");

        for my $item (@Templates) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Template', $item );
                next;
            }

            my $new_entry = RT::Template->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @Scrips ) {
        $RT::Logger->debug("Creating scrips...");

        for my $item (@Scrips) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Scrip', $item );
                next;
            }

            my $new_entry = RT::Scrip->new(RT->SystemUser);

            my @queues = ref $item->{'Queue'} eq 'ARRAY'
                       ? @{ $item->{'Queue'} }
                       : ($item->{'Queue'})
                if $item->{'Queue'};

            if (!@queues) {
                push @queues, 0 unless $item->{'NoAutoGlobal'};
            }

            my $remove_global = (delete $item->{'NoAutoGlobal'}) && !@queues;

            my %args = %$item;
            $args{Queue} = shift @queues;
            if (ref($args{Queue})) {
                # transform ScripObject->Create API into Scrip->Create API
                $args{Queue}{Queue} = delete $args{Queue}{ObjectId};
                $args{Queue}{ObjectSortOrder} = delete $args{Queue}{SortOrder};
                %args = (
                    %args,
                    %{ $args{Queue} },
                );
            }

            my ( $return, $msg ) = $new_entry->Create(%args);
            unless ( $return ) {
                $RT::Logger->error( $msg );
                next;
            }
            else {
                $RT::Logger->debug( $return ."." );
            }

            if ($remove_global) {
                my ($return, $msg) = $new_entry->RemoveFromObject(ObjectId => 0);
                $RT::Logger->error( "Couldn't unapply scrip globally: $msg" )
                    unless $return;
            }

            foreach my $q ( @queues ) {
                my %args = (
                    Stage => $item->{'Stage'},
                    (ref($q) ? %$q : (ObjectId => $q)),
                );

                my ($return, $msg) = $new_entry->AddToObject(%args);

                $RT::Logger->error( "Couldn't apply scrip to $args{ObjectId}: $msg" )
                    unless $return;
            }
        }
        $RT::Logger->debug("done.");
    }

    if ( @ObjectTopics ) {
        $RT::Logger->debug( "Creating ObjectTopics..." );

        for my $item ( @ObjectTopics ) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::ObjectTopic', $item );
                next;
            }

            my $obj = delete $item->{Object};

            if ( ref $obj eq 'CODE' ) {
                $obj = $obj->();
            }

            my $topic = RT::Topic->new( RT->SystemUser );
            if ( $item->{Topic} =~ /\D/ ) {
                $topic->LoadByCols( Name => $item->{Topic} );
            }
            else {
                $topic->Load( $item->{Topic} );
            }

            if ( !$topic->id ) {
                $RT::Logger->error( "Couldn't load topic $item->{Topic}" );
                next;
            }

            $item->{Topic} = $topic->id;

            my ( $return, $msg ) = $obj->AddTopic( %$item );
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return . "." );
            }

        }

        $RT::Logger->debug( "done." );
    }

    if ( @OCFVs ) {
        $RT::Logger->debug("Creating ObjectCustomFieldValues...");

        for my $item (@OCFVs) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::ObjectCustomFieldValue', $item );
                next;
            }

            my $obj = delete $item->{Object};

            if ( ref $obj eq 'CODE' ) {
                $obj = $obj->();
            }

            $item->{Field} = delete $item->{CustomField} if $item->{CustomField};
            $item->{Value} = delete $item->{Content} if $item->{Content};

            $self->_CanonilizeObjectCustomFieldValue( $item );

            my ( $return, $msg ) = $obj->AddCustomFieldValue (%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }

    if ( @Attributes ) {
        $RT::Logger->debug("Creating attributes...");
        my $sys = RT::System->new(RT->SystemUser);

        my %order = (
            'Dashboard'             => 1,
            'DefaultDashboard'      => 2,
            'Pref-DefaultDashboard' => 2,
            'DashboardsInMenu'      => 2,
            'Pref-DashboardsInMenu' => 2,
            'Subscription'          => 2,
        );

        my $order = sub {
            my $name = shift;
            return $order{$name} if exists $order{$name};

            # Handle customized default dashboards like RTIRDefaultDashboard later than Dashboards.
            if ( $name =~ /DefaultDashboard$/ ) {
                return 2;
            }
            return 0;
        };

        for my $item ( sort { $order->( $a->{Name} ) <=> $order->( $b->{Name} ) } @Attributes ) {
            if ( $item->{_Original} ) {
                $self->_UpdateOrDeleteObject( 'RT::Attribute', $item );
                next;
            }

            my $obj = delete $item->{Object};

            if ( ref $obj eq 'CODE' ) {
                $obj = $obj->();
            }
            elsif ( $obj && !ref $obj ) {
                if ( $obj eq 'RT::System' ) {
                    $obj = RT->System;
                }
                elsif ( my $class = delete $item->{ObjectType} ) {
                    my $id = $obj;
                    $obj = $class->new( RT->SystemUser );
                    if ( $class eq 'RT::Group') {
                        $obj->LoadUserDefinedGroup( $id );
                    }
                    else {
                        $obj->Load( $id );
                    }
                    if ( !$obj->id ) {
                        $RT::Logger->error( "Failed to load object $class-$id" );
                        next;
                    }
                }
                else {
                    $RT::Logger->error( "Invalid object $obj" );
                    next;
                }
            }

            $obj ||= $sys;

            $self->_CanonilizeAttributeContent($item);

            my ( $return, $msg ) = $obj->AddAttribute (%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @Final ) {
        $RT::Logger->debug("Running final actions...");
        for ( @Final ) {
            local $@;
            eval { $_->( admin_dbh => $args{admin_dbh} ); };
            $RT::Logger->error( "Failed to run one of final actions: $@" )
                if $@;
        }
        $RT::Logger->debug("done.");
    }

    # XXX: This disconnect doesn't really belong here; it's a relict from when
    # this method was extracted from rt-setup-database.  However, too much
    # depends on it to change without significant testing.  At the very least,
    # we can provide a way to skip the side-effect.
    if ( $args{disconnect_after} ) {
        my $db_type = RT->Config->Get('DatabaseType');
        $RT::Handle->Disconnect() unless $db_type eq 'SQLite';
    }

    $RT::Logger->debug("Done setting up database content.");

# TODO is it ok to return 1 here? If so, the previous codes in this sub
# should return (0, $msg) if error happens instead of just warning.
# anyway, we need to return something here to tell if everything is ok
    return( 1, 'Done inserting data' );
}

=head2 ACLEquivGroupId

Given a userid, return that user's acl equivalence group

=cut

sub ACLEquivGroupId {
    my $id = shift;

    my $cu = RT->SystemUser;
    unless ( $cu ) {
        require RT::CurrentUser;
        $cu = RT::CurrentUser->new;
        $cu->LoadByName('RT_System');
        warn "Couldn't load RT_System user" unless $cu->id;
    }

    my $equiv_group = RT::Group->new( $cu );
    $equiv_group->LoadACLEquivalenceGroup( $id );
    return $equiv_group->Id;
}

=head2 QueryHistory

Returns the SQL query history associated with this handle. The top level array
represents a lists of request. Each request is a hash with metadata about the
request (such as the URL) and a list of queries. You'll probably not be using this.

=cut

sub QueryHistory {
    my $self = shift;

    return $self->{QueryHistory};
}

=head2 AddRequestToHistory

Adds a web request to the query history. It must be a hash with keys Path (a
string) and Queries (an array reference of arrays, where elements are time,
sql, bind parameters, and duration).

=cut

sub AddRequestToHistory {
    my $self    = shift;
    my $request = shift;

    push @{ $self->{QueryHistory} }, $request;
}

=head2 Quote

Returns the parameter quoted by DBI. B<You almost certainly do not need this.>
Use bind parameters (C<?>) instead. This is used only outside the scope of interacting
with the database.

=cut

sub Quote {
    my $self = shift;
    my $value = shift;

    return $self->dbh->quote($value);
}

=head2 FillIn

Takes a SQL query and an array reference of bind parameters and fills in the
query's C<?> parameters.

=cut

sub FillIn {
    my $self = shift;
    my $sql  = shift;
    my $bind = shift;

    my $b = 0;

    # is this regex sufficient?
    $sql =~ s{\?}{$self->Quote($bind->[$b++])}eg;

    return $sql;
}

sub Indexes {
    my $self = shift;

    my %res;

    my $db_type = RT->Config->Get('DatabaseType');
    my $dbh = $self->dbh;

    my $list;
    if ( $db_type eq 'mysql' ) {
        $list = $dbh->selectall_arrayref(
            'select distinct table_name, index_name from information_schema.statistics where table_schema = ?',
            undef, scalar RT->Config->Get('DatabaseName')
        );
    }
    elsif ( $db_type eq 'Pg' ) {
        $list = $dbh->selectall_arrayref(
            'select tablename, indexname from pg_indexes',
            undef,
        );
    }
    elsif ( $db_type eq 'SQLite' ) {
        $list = $dbh->selectall_arrayref(
            'select tbl_name, name from sqlite_master where type = ?',
            undef, 'index'
        );
    }
    elsif ( $db_type eq 'Oracle' ) {
        $list = $dbh->selectall_arrayref(
            'select table_name, index_name from all_indexes where index_name NOT LIKE ? AND lower(Owner) = ?',
            undef, 'SYS_%$$', lc RT->Config->Get('DatabaseUser'),
        );
    }
    else {
        die "Not implemented";
    }
    push @{ $res{ lc $_->[0] } ||= [] }, lc $_->[1] foreach @$list;
    return %res;
}

sub IndexesThatBeginWith {
    my $self = shift;
    my %args = (Table => undef, Columns => [], @_);

    my %indexes = $self->Indexes;

    my @check = @{ $args{'Columns'} };

    my @list;
    foreach my $index ( @{ $indexes{ lc $args{'Table'} } || [] } ) {
        my %info = $self->IndexInfo( Table => $args{'Table'}, Name => $index );
        next if @{ $info{'Columns'} } < @check;
        my $check = join ',', @check;
        next if join( ',', @{ $info{'Columns'} } ) !~ /^\Q$check\E(?:,|$)/i;

        push @list, \%info;
    }
    return sort { @{ $a->{'Columns'} } <=> @{ $b->{'Columns'} } } @list;
}

sub IndexInfo {
    my $self = shift;
    my %args = (Table => undef, Name => undef, @_);

    my $db_type = RT->Config->Get('DatabaseType');
    my $dbh = $self->dbh;

    my %res = (
        Table => lc $args{'Table'},
        Name => lc $args{'Name'},
    );
    if ( $db_type eq 'mysql' ) {
        my $list = $dbh->selectall_arrayref(
            'select NON_UNIQUE, COLUMN_NAME, SUB_PART
            from information_schema.statistics
            where table_schema = ? AND LOWER(table_name) = ? AND index_name = ?
            ORDER BY SEQ_IN_INDEX',
            undef, scalar RT->Config->Get('DatabaseName'), lc $args{'Table'}, $args{'Name'},
        );
        return () unless $list && @$list;
        $res{'Unique'} = $list->[0][0]? 0 : 1;
        $res{'Functional'} = 0;
        $res{'Columns'} = [ map $_->[1], @$list ];
    }
    elsif ( $db_type eq 'Pg' ) {
        my $index = $dbh->selectrow_hashref(
            'select ix.*, pg_get_expr(ix.indexprs, ix.indrelid) as functions
            from
                pg_class t, pg_class i, pg_index ix
            where
                t.relname ilike ?
                and t.relkind = ?
                and i.relname ilike ?
                and ix.indrelid = t.oid
                and ix.indexrelid = i.oid
            ',
            undef, $args{'Table'}, 'r', $args{'Name'},
        );
        return () unless $index && keys %$index;
        $res{'Unique'} = $index->{'indisunique'};
        $res{'Functional'} = (grep $_ == 0, split ' ', $index->{'indkey'})? 1 : 0;
        $res{'Columns'} = [ map int($_), split ' ', $index->{'indkey'} ];
        my $columns = $dbh->selectall_hashref(
            'select a.attnum, a.attname
            from pg_attribute a where a.attrelid = ?',
            'attnum', undef, $index->{'indrelid'}
        );
        if ($index->{'functions'}) {
            # XXX: this is good enough for us
            $index->{'functions'} = [ split /,\s+/, $index->{'functions'} ];
        }
        foreach my $e ( @{ $res{'Columns'} } ) {
            if (exists $columns->{$e} ) {
                $e = $columns->{$e}{'attname'};
            }
            elsif ( !$e ) {
                $e = shift @{ $index->{'functions'} };
            }
        }

        foreach my $column ( @{$res{'Columns'}} ) {
            next unless $column =~ s/^lower\( \s* \(? (\w+) \)? (?:::text)? \s* \)$/$1/ix;
            $res{'CaseInsensitive'}{ lc $1 } = 1;
        }
    }
    elsif ( $db_type eq 'SQLite' ) {
        my $list = $dbh->selectall_arrayref("pragma index_info('$args{'Name'}')");
        return () unless $list && @$list;

        $res{'Functional'} = 0;
        $res{'Columns'} = [ map $_->[2], @$list ];

        $list = $dbh->selectall_arrayref("pragma index_list('$args{'Table'}')");
        $res{'Unique'} = (grep lc $_->[1] eq lc $args{'Name'}, @$list)[0][2]? 1 : 0;
    }
    elsif ( $db_type eq 'Oracle' ) {
        my $index = $dbh->selectrow_arrayref(
            'select uniqueness, funcidx_status from all_indexes
            where lower(table_name) = ? AND lower(index_name) = ? AND LOWER(Owner) = ?',
            undef, lc $args{'Table'}, lc $args{'Name'}, lc RT->Config->Get('DatabaseUser'),
        );
        return () unless $index && @$index;
        $res{'Unique'} = $index->[0] eq 'UNIQUE'? 1 : 0;
        $res{'Functional'} = $index->[1] ? 1 : 0;

        my %columns = map @$_, @{ $dbh->selectall_arrayref(
            'select column_position, column_name from all_ind_columns
            where lower(table_name) = ? AND lower(index_name) = ? AND LOWER(index_owner) = ?',
            undef, lc $args{'Table'}, lc $args{'Name'}, lc RT->Config->Get('DatabaseUser'),
        ) };
        $columns{ $_->[0] } = $_->[1] foreach @{ $dbh->selectall_arrayref(
            'select column_position, column_expression from all_ind_expressions
            where lower(table_name) = ? AND lower(index_name) = ? AND LOWER(index_owner) = ?',
            undef, lc $args{'Table'}, lc $args{'Name'}, lc RT->Config->Get('DatabaseUser'),
        ) };
        $res{'Columns'} = [ map $columns{$_}, sort { $a <=> $b } keys %columns ];

        foreach my $column ( @{$res{'Columns'}} ) {
            next unless $column =~ s/^lower\( \s* " (\w+) " \s* \)$/$1/ix;
            $res{'CaseInsensitive'}{ lc $1 } = 1;
        }
    }
    else {
        die "Not implemented";
    }
    $_ = lc $_ foreach @{ $res{'Columns'} };
    return %res;
}

sub DropIndex {
    my $self = shift;
    my %args = (Table => undef, Name => undef, @_);

    my $db_type = RT->Config->Get('DatabaseType');
    my $dbh = $self->dbh;
    local $dbh->{'PrintError'} = 0;
    local $dbh->{'RaiseError'} = 0;

    my $res;
    if ( $db_type eq 'mysql' ) {
        $args{'Table'} = $self->_CanonicTableNameMysql( $args{'Table'} );
        $res = $dbh->do(
            'drop index '. $dbh->quote_identifier($args{'Name'}) ." on $args{'Table'}",
        );
    }
    elsif ( $db_type eq 'Pg' ) {
        $res = $dbh->do("drop index $args{'Name'} CASCADE");
    }
    elsif ( $db_type eq 'SQLite' ) {
        $res = $dbh->do("drop index $args{'Name'}");
    }
    elsif ( $db_type eq 'Oracle' ) {
        my $user = RT->Config->Get('DatabaseUser');
        # Check if it has constraints associated with it
        my ($constraint) = $dbh->selectrow_arrayref(
            'SELECT constraint_name, table_name FROM all_constraints WHERE LOWER(owner) = ? AND LOWER(index_name) = ?',
            undef, lc $user, lc $args{'Name'}
        );
        if ($constraint) {
            my ($constraint_name, $table) = @{$constraint};
            $res = $dbh->do("ALTER TABLE $user.$table DROP CONSTRAINT $constraint_name");
        } else {
            $res = $dbh->do("DROP INDEX $user.$args{'Name'}");
        }
    }
    else {
        die "Not implemented";
    }
    my $desc = $self->IndexDescription( %args );
    return ($res, $res? "Dropped $desc" : "Couldn't drop $desc: ". $dbh->errstr);
}

sub _CanonicTableNameMysql {
    my $self = shift;
    my $table = shift;
    return $table unless $table;
    # table name can be case sensitivity in DDL
    # use LOWER to workaround mysql "bug"
    return ($self->dbh->selectrow_array(
        'SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = ? AND LOWER(table_name) = ?',
        undef, scalar RT->Config->Get('DatabaseName'), lc $table
    ))[0] || $table;
}

sub DropIndexIfExists {
    my $self = shift;
    my %args = (Table => undef, Name => undef, @_);

    my %indexes = $self->Indexes;
    return (1, ucfirst($self->IndexDescription( %args )) ." doesn't exists")
        unless grep $_ eq lc $args{'Name'},
        @{ $indexes{ lc $args{'Table'} } || []};
    return $self->DropIndex(%args);
}

sub CreateIndex {
    my $self = shift;
    my %args = ( Table => undef, Name => undef, Columns => [], CaseInsensitive => {}, @_ );

    $args{'Table'} = $self->_CanonicTableNameMysql( $args{'Table'} )
        if RT->Config->Get('DatabaseType') eq 'mysql';

    my $name = $args{'Name'};
    unless ( $name ) {
        my %indexes = $self->Indexes;
        %indexes = map { $_ => 1 } @{ $indexes{ lc $args{'Table'} } || [] };
        my $i = 1;
        $i++ while $indexes{ lc($args{'Table'}).$i };
        $name = lc($args{'Table'}).$i;
    }

    my @columns = @{ $args{'Columns'} };
    if ( $self->CaseSensitive ) {
        foreach my $column ( @columns ) {
            next unless $args{'CaseInsensitive'}{ lc $column };
            $column = "LOWER($column)";
        }
    }

    my $sql = "CREATE"
        . ($args{'Unique'}? ' UNIQUE' : '')
        ." INDEX $name ON $args{'Table'}"
        ."(". join( ', ', @columns ) .")"
    ;

    my $res = $self->dbh->do( $sql );
    unless ( $res ) {
        return (
            undef, "Failed to create ". $self->IndexDescription( %args )
                ." (sql: $sql): ". $self->dbh->errstr
        );
    }
    return ($name, "Created ". $self->IndexDescription( %args ) );
}

sub IndexDescription {
    my $self = shift;
    my %args = (@_);

    my $desc =
        ($args{'Unique'}? 'unique ' : '')
        .'index'
        . ($args{'Name'}? " $args{'Name'}" : '')
        . ( @{$args{'Columns'}||[]}?
            " ("
            . join(', ', @{$args{'Columns'}})
            . (@{$args{'Optional'}||[]}? '['. join(', ', '', @{$args{'Optional'}}).']' : '' )
            .")"
            : ''
        )
        . ($args{'Table'}? " on $args{'Table'}" : '')
    ;
    return $desc;
}

sub MakeSureIndexExists {
    my $self = shift;
    my %args = ( Table => undef, Columns => [], Optional => [], @_ );

    my @list = $self->IndexesThatBeginWith(
        Table => $args{'Table'}, Columns => [@{$args{'Columns'}}, @{$args{'Optional'}}],
    );
    if (@list) {
        RT->Logger->debug( ucfirst $self->IndexDescription(
            Table => $args{'Table'}, Columns => [@{$args{'Columns'}}, @{$args{'Optional'}}],
        ). ' exists.' );
        return;
    }

    @list = $self->IndexesThatBeginWith(
        Table => $args{'Table'}, Columns => $args{'Columns'},
    );
    if ( !@list ) {
        my ($status, $msg) = $self->CreateIndex(
            Table => $args{'Table'}, Columns => [@{$args{'Columns'}}, @{$args{'Optional'}}],
        );
        my $method = $status ? 'debug' : 'warning';
        RT->Logger->$method($msg);
    }
    else {
        RT->Logger->info(
            ucfirst $self->IndexDescription(
                %{$list[0]}
            )
            .' exists, you may consider replacing it with '
            . $self->IndexDescription(
                Table => $args{'Table'}, Columns => [@{$args{'Columns'}}, @{$args{'Optional'}}],
            )
        );
    }
}

sub DropIndexesThatArePrefix {
    my $self = shift;
    my %args = ( Table => undef, Columns => [], @_ );

    my @list = $self->IndexesThatBeginWith(
        Table => $args{'Table'}, Columns => [$args{'Columns'}[0]],
    );

    my $checking = join ',', map lc $_, @{ $args{'Columns'} }, '';
    foreach my $i ( splice @list ) {
        my $columns = join ',', @{ $i->{'Columns'} }, '';
        next unless $checking =~ /^\Q$columns/i;

        push @list, $i;
    }
    pop @list;

    foreach my $i ( @list ) {
        my ($status, $msg) = $self->DropIndex(
            Table => $i->{'Table'}, Name => $i->{'Name'},
        );
        my $method = $status ? 'debug' : 'warning';
        RT->Logger->$method($msg);
    }
}

# log a mason stack trace instead of a Carp::longmess because it's less painful
# and uses mason component paths properly
sub _LogSQLStatement {
    my $self = shift;
    my $statement = shift;
    my $duration = shift;
    my @bind = @_;

    require HTML::Mason::Exceptions;
    push @{$self->{'StatementLog'}} , ([Time::HiRes::time(), $statement, [@bind], $duration, HTML::Mason::Exception->new->as_string]);
}

# helper in a few cases where we do SQL by hand
sub __MakeClauseCaseInsensitive {
    my $self = shift;
    return join ' ', @_ unless $self->CaseSensitive;
    my ($field, $op, $value) = $self->_MakeClauseCaseInsensitive(@_);
    return "$field $op $value";
}

sub _TableNames {
    my $self = shift;
    my $dbh = shift || $self->dbh;

    {
        local $@;
        if (
            $dbh->{Driver}->{Name} eq 'Pg'
            && $dbh->{'pg_server_version'} >= 90200
            && !eval { DBD::Pg->VERSION('2.19.3'); 1 }
        ) {
            die "You're using PostgreSQL 9.2 or newer. You have to upgrade DBD::Pg module to 2.19.3 or newer: $@";
        }
    }

    my @res;

    my $sth = $dbh->table_info( '', undef, undef, "'TABLE'");
    while ( my $table = $sth->fetchrow_hashref ) {
        push @res, $table->{TABLE_NAME} || $table->{table_name};
    }

    return @res;
}

sub _UpdateOrDeleteObject {
    my $self = shift;
    my $class  = shift;
    my $values = shift;
    my $refs   = shift;

    if ( delete $values->{_Updated} ) {
        return $self->_UpdateObject( $class, $values, $refs );
    }
    elsif ( delete $values->{_Deleted} ) {
        return $self->_DeleteObject( $class, $values, $refs );
    }
    else {
        RT->Logger->error( "Unknown action in $class" );
        return;
    }
}

sub _UpdateObject {
    my $self   = shift;
    my $class  = shift;
    my $values = shift;
    my $refs   = shift;

    my $object = $self->_LoadObject($class, $values);
    return unless $object;

    my $original = delete $values->{_Original};

    for my $type ( qw/Attributes CustomFields Topics/ ) {
        if ( my $items = delete $values->{$type} ) {
            if ( $type eq 'Attributes' ) {
                for my $item ( @$items ) {
                    my $attributes = $object->Attributes->Clone;
                    $attributes->Limit( FIELD => 'Name',        VALUE => $item->{Name} );
                    $attributes->Limit( FIELD => 'Description', VALUE => $item->{Description} );
                    if ( my $attribute = $attributes->First ) {
                        $item->{_Updated}  = 1;
                        $item->{_Original} = {
                            Name        => $item->{Name},
                            Description => $item->{Description},
                            ObjectType  => $class,
                            ObjectId    => $object->Name,
                        };
                    }
                }
            }
            elsif ( $type eq 'CustomFields' ) {
                my @new_items;
                my ( %old, %new );

                for my $item ( @$items ) {
                    $self->_CanonilizeObjectCustomFieldValue( $item );
                    push @{ $new{ $item->{CustomField} } }, $item;
                }

                for my $name ( keys %new ) {
                    my $cf = $object->LoadCustomFieldByIdentifier( $name );
                    if ( $cf->id ) {
                        $old{$name} = $object->CustomFieldValues( $cf );
                    }
                }

                for my $item ( @$items ) {
                    next
                      if $old{ $item->{CustomField} }
                      && $old{ $item->{CustomField} }->HasEntry( $item->{Content}, $item->{LargeContent} );
                    push @new_items, $item;
                }

                for my $name ( keys %old ) {
                    my $ocfvs = $old{$name};
                    while ( my $ocfv = $ocfvs->Next ) {
                        next if grep {
                            ( $ocfv->Content // '' ) eq ( $_->{Content} // '' )
                              && ( $ocfv->LargeContent // '' ) eq ( $_->{LargeContent} // '' )
                        } @{ $new{$name} };

                        my ( $ret, $msg ) = $ocfv->Delete();
                        unless ( $ret ) {
                            RT->Logger->error( "Couldn't delete ocfv#" . $ocfv->id . ": $msg" );
                        }
                    }
                }
                @$items = @new_items;
            }
            elsif ( $type eq 'Topics' ) {
                my @new_items;
                my %old = map { $_->Topic->Name => 1 } @{ $object->Topics->ItemsArrayRef || [] };
                my %new = map { $_->{Topic} => 1 } @$items;

                for my $item ( @$items ) {
                    next if $old{ $item->{Topic} };
                    push @new_items, $item;
                }

                for my $name ( keys %old ) {
                    next if $new{$name};

                    my $topic = RT::Topic->new( RT->SystemUser );
                    $topic->Load( $name );
                    if ( $topic->id ) {
                        my ( $ret, $msg ) = $object->DeleteTopic( Topic => $topic->id );
                        unless ( $ret ) {
                            RT->Logger->error(
                                "Couldn't delete topic#" . $topic->id . "from object#" . $object->id . ": $msg" );
                        }
                    }
                    else {
                        RT->Logger->error( "Couldn't load topic $name" );
                    }
                }

                @$items = @new_items;
            }

            for my $item ( @$items ) {
                $item->{Object} = $object;
            }

            if ( $refs->{$type} ) {
                push @{ $refs->{$type} }, @$items;
            }
            else {
                RT->Logger->error( "$class doesn't support $type in initialdata" );
            }
        }
    }

    for my $field ( sort { $a eq 'ApplyTo' || $b eq 'ApplyTo' ? 1 : 0 } keys %$values ) {

        if ( $class eq 'RT::Attribute' ) {
            if ( $field eq 'Content' ) {
                $self->_CanonilizeAttributeContent( $values );
            }
        }

        my $value = $values->{$field};

        if ( $class eq 'RT::CustomField' ) {
            if ( $field eq 'ApplyTo' ) {
                my %current;
                my %new;

                my $ocfs = RT::ObjectCustomFields->new(RT->SystemUser);
                $ocfs->LimitToCustomField($object->id);

                while ( my $ocf = $ocfs->Next ) {
                    if ( $ocf->ObjectId == 0 ) {
                        $current{0} = 1;
                    }
                    else {
                        my $added = $object->RecordClassFromLookupType->new( RT->SystemUser );
                        $current{$ocf->ObjectId} = 1;
                    }
                }

                for my $item ( @{ $value || [] } ) {
                    if ( $item eq 0 ) {
                        $new{0} = 1;
                    }
                    else {
                        my $added = $object->RecordClassFromLookupType->new( RT->SystemUser );
                        $added->Load($item);
                        if ( $added->id ) {
                            $new{$added->id} = 1;
                        }
                    }
                }

                for my $id ( keys %current ) {
                    next if $new{$id};
                    my $ocf = RT::ObjectCustomField->new(RT->SystemUser);
                    $ocf->LoadByCols( CustomField => $object->id, ObjectId => $id );
                    if ( $ocf->id ) {
                        my ( $ret, $msg) = $ocf->Delete;
                        if ( !$ret ) {
                            RT->Logger->error( "Couldn't delete ObjectCustomField #" . $ocf->id . ": $msg" );
                        }
                    }
                }

                for my $id ( keys %new ) {
                    next if $current{$id};
                    my $ocf = RT::ObjectCustomField->new( RT->SystemUser );
                    $ocf->LoadByCols( CustomField => $object->id, ObjectId => $id );
                    if ( !$ocf->id ) {
                        my ( $ret, $msg ) = $ocf->Create( CustomField => $object->id, ObjectId => $id );
                        if ( !$ret ) {
                            RT->Logger->error( "Couldn't create ObjectCustomField for CustomField #"
                                  . $object->id
                                  . " and ObjectId #$id: $msg" );
                        }
                    }
                }
                next;
            }
            elsif ( $field eq 'Values' ) {
                my %current;
                my %new;

                my $cfvs = $object->Values;

                # Only support core cfvs for now
                next unless $cfvs->isa( 'RT::CustomFieldValues' );

                while ( my $cfv = $cfvs->Next ) {
                    $current{ $cfv->Name } = $cfv;
                }

                for my $item ( @{ $value || [] } ) {
                    $new{ $item->{Name} } = $item;
                }

                for my $name ( keys %current ) {
                    if ( $new{$name} ) {
                        for my $column ( qw/Description Category SortOrder/ ) {
                            if ( ( $current{$name}->$column // '' ) ne ( $new{$name}{$column} // '' ) ) {
                                my ( $ret, $msg ) =
                                  $current{$name}->_Set( Field => $column, Value => $new{$name}{$column} );
                                unless ( $ret ) {
                                    RT->Logger->error( "Couldn't update CustomFieldValue#"
                                          . $current{$name}->id
                                          . " $column to $new{$name}{$column}: $msg" );
                                    next;
                                }
                            }
                        }
                    }
                    else {
                        my ( $ret, $msg ) = $current{$name}->Delete;
                        if ( !$ret ) {
                            RT->Logger->error( "Couldn't delete CustomFieldValue #" . $current{$name}->id . ": $msg" );
                        }
                    }
                }

                for my $name ( keys %new ) {
                    next if $current{$name};
                    my ( $ret, $msg ) =
                      $object->AddValue( map { $_ => $new{$name}{$_} } qw/Name Description Category SortOrder/ );
                    if ( !$ret ) {
                        RT->Logger->error( "Couldn't create CustomFieldValue $new{$name}{Name} to CustomField #"
                              . $object->id
                              . ": $msg" );
                    }
                }
                next;
            }
        }

        next unless $object->can( $field ) || $object->_Accessible( $field, 'read' );
        my $old_value = $object->can( $field ) ? $object->$field : $object->_Value( $field );

        if ( ( $old_value // '' ) ne ( $values->{$field} // '' ) ) {
            my $set_method = "Set$field";
            if ( $object->can( $set_method ) || $object->_Accessible( $field, 'write' ) ) {
                my ( $ret, $msg );
                if ( $object->can( $set_method ) ) {
                    ( $ret, $msg ) = $object->$set_method( $values->{$field} );
                }
                elsif ( $object->_Accessible( $field, 'write' ) ) {
                    ( $ret, $msg ) = $object->_Set( Field => $field, Value => $value );
                }
                unless ( $ret ) {
                    RT->Logger->error( "Couldn't update $class#" . $object->id . " $field to $value: $msg" );
                    next;
                }
            }
            else {
                RT->Logger->error( "Couldn't update $field for $class" );
            }
        }
    }
}

sub _DeleteObject {
    my $self   = shift;
    my $class  = shift;
    my $values = shift;

    my $object = $self->_LoadObject( $class, $values );
    return unless $object;
    my ( $return, $msg ) = $object->Delete();
    unless ( $return ) {
        $RT::Logger->error( $msg );
    }
}

sub _LoadObject {
    my $self   = shift;
    my $class  = shift;
    my $values = shift;

    if ( $class eq 'RT::System' ) {
        return RT->System;
    }

    my $object = $class->new( RT->SystemUser );

    if ( !ref $values ) {
        if ( $class eq 'RT::Group' ) {
            $object->LoadUserDefinedGroup( $values );
        }
        else {
            $object->Load( $values );
        }
        return $object->id ? $object : undef;
    }

    if ( $class eq 'RT::ACE' ) {
        my ( $principal_id, $principal_type );
        if ( $values->{_Original}{UserId} ) {
            my $user = RT::User->new(RT->SystemUser);
            $user->Load( $values->{_Original}{UserId} );
            if ( $user->id ) {
                $principal_id = $user->PrincipalId;
                $principal_type = 'User';
            }
            else {
                RT->Logger->error( "Couldn't load user $values->{_Original}{UserId}" );
                return;
            }
        }
        elsif ( $values->{_Original}{GroupId} ) {
            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadByCols( Domain => $values->{_Original}{GroupDomain}, Name => $values->{_Original}{GroupId} );
            if ( $group->id ) {
                $principal_id = $group->PrincipalId;
                $principal_type = 'Group';
            }
            else {
                RT->Logger->error( "Couldn't load group $values->{_Original}{UserId}" );
                return;
            }
        }
        else {
            RT->Logger->error( "Invalid principal type in $class" );
            return;
        }

        $object->LoadByValues(
            PrincipalId   => $principal_id,
            PrincipalType => $principal_type,
            map { $_ => $values->{_Original}{$_} } grep { $values->{_Original}{$_} } qw/ObjectType ObjectId RightName/,
        );
    }
    elsif ( $class eq 'RT::GroupMember' ) {
        my $group = RT::Group->new( RT->SystemUser );
        $group->LoadUserDefinedGroup( $values->{_Original}{Group} );
        unless ( $group->id ) {
            RT->Logger->error( "Couldn't load group $values->{_Original}{Group}" );
            return;
        }

        my $member;
        if ( $values->{_Original}{Class} eq 'RT::User' ) {
            $member = RT::User->new( RT->SystemUser );
            $member->Load( $values->{_Original}{Name} );
            unless ( $member->id ) {
                RT->Logger->error( "Couldn't load user $values->{_Original}{Name}" );
                return;
            }
        }
        else {
            $member = RT::Group->new( RT->SystemUser );
            $member->LoadUserDefinedGroup( $values->{_Original}{Name} );
            unless ( $member->id ) {
                RT->Logger->error( "Couldn't load group $values->{_Original}{Name}" );
                return;
            }
        }
        $object->LoadByCols( Group => $group->PrincipalObj, Member => $member->PrincipalObj );
    }
    elsif ( $class eq 'RT::Template' ) {
        $object->LoadByName( Name => $values->{_Original}{Name}, Queue => $values->{_Original}{Queue} );
    }
    elsif ( $class eq 'RT::Scrip' ) {
        $object->LoadByCols( Description => $values->{_Original}{Description} );
    }
    else {
        if ( $class eq 'RT::Group' ) {
            $object->LoadByCols( Domain => $values->{Domain}, Name => $values->{_Original}{Name} );
        }
        elsif ( $class eq 'RT::Attribute' ) {
            my $obj = $values->{_Original}{Object};
            if ( $obj eq 'RT::System' ) {
                $obj = RT->System;
            }
            elsif ( my $class = $values->{_Original}{ObjectType} ) {
                my $id = $obj;
                $obj = $class->new( RT->SystemUser );
                if ( $class eq 'RT::Group' ) {
                    $obj->LoadUserDefinedGroup( $id );
                }
                else {
                    $obj->Load( $id );
                }
                if ( !$obj->id ) {
                    $RT::Logger->error( "Failed to load object $class-$id" );
                    return;
                }
            }
            else {
                $RT::Logger->error( "Invalid object $obj" );
                return;
            }
            my $attributes = $obj->Attributes->Clone;
            $attributes->Limit( FIELD => 'Name', VALUE => $values->{_Original}{Name} );
            $attributes->Limit( FIELD => 'Description', VALUE => $values->{_Original}{Description} );
            if ( my $attribute = $attributes->First ) {
                $object = $attribute;
            }
        }
        else {
            $object->Load( $values->{_Original}{Name} );
        }
    }

    return $object->id ? $object : undef;
}

sub _CanonilizeAttributeContent {
    my $self = shift;
    my $item = shift or return;
    if ( $item->{Name} eq 'Dashboard' ) {
        my $content = $item->{Content}{Panes};
        for my $type ( qw/body sidebar/ ) {
            if ( $content->{$type} && ref $content->{$type} eq 'ARRAY' ) {
                for my $entry ( @{ $content->{$type} } ) {
                    next unless $entry->{portlet_type} eq 'search';
                    if ( $entry->{ObjectType} && $entry->{ObjectId} && $entry->{Description} ) {
                        if ( my $object = $self->_LoadObject( $entry->{ObjectType}, $entry->{ObjectId} ) ) {
                            my $attributes = $object->Attributes->Clone;
                            $attributes->Limit( FIELD => 'Description', VALUE => $entry->{Description} );
                            if ( my $attribute = $attributes->First ) {
                                $entry->{id} = $attribute->id;
                                $entry->{privacy} = ref( $object ) . '-' . $object->Id;
                            }
                        }
                        delete $entry->{$_} for qw/ObjectType ObjectId Description/;
                    }
                }
            }
        }
    }
    elsif ( $item->{Name} =~ /^(?:Pref-)?DashboardsInMenu$/ ) {
        my @dashboards;
        for my $entry ( @{ $item->{Content}{dashboards} } ) {
            if ( $entry->{ObjectType} && $entry->{ObjectId} && $entry->{Description} ) {
                if ( my $object = $self->_LoadObject( $entry->{ObjectType}, $entry->{ObjectId} ) ) {
                    my $attributes = $object->Attributes->Clone;
                    $attributes->Limit( FIELD => 'Name', VALUE => 'Dashboard' );
                    $attributes->Limit( FIELD => 'Description', VALUE => $entry->{Description} );
                    if ( my $attribute = $attributes->First ) {
                        push @dashboards, $attribute->id;
                    }
                }
            }
        }
        $item->{Content}{dashboards} = \@dashboards;
    }
    elsif ( $item->{Name} =~ /DefaultDashboard$/ ) {
        my $entry = $item->{Content};
        if ( $entry->{ObjectType} && $entry->{ObjectId} && $entry->{Description} ) {
            if ( my $object = $self->_LoadObject( $entry->{ObjectType}, $entry->{ObjectId} ) ) {
                my $attributes = $object->Attributes->Clone;
                $attributes->Limit( FIELD => 'Name',        VALUE => 'Dashboard' );
                $attributes->Limit( FIELD => 'Description', VALUE => $entry->{Description} );
                if ( my $attribute = $attributes->First ) {
                    $item->{Content} = $attribute->id;
                }
            }
        }
    }
    elsif ( $item->{Name} eq 'Subscription' ) {
        my $entry = $item->{Content}{DashboardId};
        if ( $entry->{ObjectType} && $entry->{ObjectId} && $entry->{Description} ) {
            if ( my $object = $self->_LoadObject( $entry->{ObjectType}, $entry->{ObjectId} ) ) {
                my $attributes = $object->Attributes->Clone;
                $attributes->Limit( FIELD => 'Name',        VALUE => 'Dashboard' );
                $attributes->Limit( FIELD => 'Description', VALUE => $entry->{Description} );
                if ( my $attribute = $attributes->First ) {
                    $item->{Content}{DashboardId} = $attribute->Id;
                    $item->{Description} = 'Subscription to dashboard ' . $attribute->Id;
                }
            }
        }
    }
}

sub _CanonilizeObjectCustomFieldValue {
    my $self = shift;
    my $item = shift;
    if ( $item->{LargeContent} ) {
        if ( ( $item->{ContentEncoding} // '' ) eq 'base64' ) {
            $item->{LargeContent} = MIME::Base64::decode_base64( $item->{LargeContent} );
            delete $item->{ContentEncoding};
        }
        else {
            $item->{LargeContent} = Encode::encode( 'UTF-8', $item->{'LargeContent'} )
              if utf8::is_utf8( $item->{LargeContent} );
        }
    }
}

__PACKAGE__->FinalizeDatabaseType;

RT::Base->_ImportOverlays();

1;
