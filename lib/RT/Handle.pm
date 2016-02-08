# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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
from L<DBIx::SerachBuilder>. Type of the DB is defined by C<DatabasseType> RT's
config option. You B<must> load this module only when the configs have been
loaded.

=cut

package RT::Handle;

use strict;
use warnings;

use File::Spec;

=head1 METHODS

=head2 FinalizeDatabaseType

Sets RT::Handle's superclass to the correct subclass of
L<DBIx::SearchBuilder::Handle>, using the C<DatabaseType> configuration.

=cut

sub FinalizeDatabaseType {
    eval {
        use base "DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType');
    };

    if ($@) {
        die "Unable to load DBIx::SearchBuilder database handle for '". RT->Config->Get('DatabaseType') ."'.\n".
            "Perhaps you've picked an invalid database type or spelled it incorrectly.\n".
            $@;
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
        my $version = $self->DatabaseVersion;
        ($version) = $version =~ /^(\d+\.\d+)/;
        $self->dbh->do("SET NAMES 'utf8'") if $version >= 4.1;
    }


    if ( $db_type eq 'Pg' ) {
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
        RequireSSL => RT->Config->Get('DatabaseRequireSSL'),
    );
    if ( $db_type eq 'Oracle' && $db_host ) {
        $args{'SID'} = delete $args{'Database'};
    }
    $self->SUPER::BuildDSN( %args );
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
    $self = new $self unless ref $self;

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
        return (0, 'no system user', "Couldn't find RT_System user in the DB '". $self->DSN ."'");
    }

    $test_user = RT::CurrentUser->new;
    $test_user->Load('Nobody');
    unless ( $test_user->id ) {
        return (0, 'no nobody user', "Couldn't find Nobody user in the DB '". $self->DSN ."'");
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

        ($version) = $version =~ /^(\d+\.\d+)/;
        return (0, "RT is unsupported on MySQL versions before 4.1.  Your version is $version.")
            if $version < 4.1;

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
            my $create_table = $dbh->selectrow_arrayref("SHOW CREATE TABLE Tickets")->[1];
            unless ( $create_table =~ /(?:ENGINE|TYPE)\s*=\s*InnoDB/i ) {
                return (0, "RT requires that all its tables be of InnoDB type. Upgrade RT tables.");
            }

            $create_table = $dbh->selectrow_arrayref("SHOW CREATE TABLE Attachments")->[1];
            unless ( $create_table =~ /\bContent\b[^,]*BLOB/i ) {
                return (0, "RT since version 3.8 has new schema for MySQL versions after 4.1.0\n"
                    ."Follow instructions in the UPGRADING.mysql file.");
            }
        }

        my $max_packet = ($dbh->selectrow_array("show variables like 'max_allowed_packet'"))[1];
        if ($state =~ /^(create|post)$/ and $max_packet <= (1024 * 1024)) {
            my $max_packet = sprintf("%.1fM", $max_packet/1024/1024);
            warn "max_allowed_packet is set to $max_packet, which limits the maximum attachment or email size that RT can process.  Consider adjusting MySQL's max_allowed_packet setting.\n";
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
        $status = $dbh->do("CREATE DATABASE $db_name DEFAULT CHARACTER SET utf8");
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
            Type        => $name,
            Domain      => 'SystemInternal',
            Description => 'Pseudogroup for internal use',  # loc
            Name        => '',
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
        my $group = RT::Group->new( RT->SystemUser );
        $group->LoadSystemRoleGroup( $name );
        if ( $group->id ) {
            push @warns, "System role '$name' already exists.";
            next;
        }

        $group = RT::Group->new( RT->SystemUser );
        my ( $val, $msg ) = $group->_Create(
            Type        => $name,
            Domain      => 'RT::System-Role',
            Description => 'SystemRolegroup for internal use',  # loc
            Name        => '',
            Instance    => '',
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
        @_
    );

    # Slurp in stuff to insert from the datafile. Possible things to go in here:-
    our (@Groups, @Users, @Members, @ACL, @Queues, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);
    local (@Groups, @Users, @Members, @ACL, @Queues, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);

    local $@;
    $RT::Logger->debug("Going to load '$datafile' data file");
    eval { require $datafile }
      or return (0, "Couldn't load data from '$datafile' for import:\n\nERROR:". $@);

    if ( @Initial ) {
        $RT::Logger->debug("Running initial actions...");
        foreach ( @Initial ) {
            local $@;
            eval { $_->(); 1 } or return (0, "One of initial functions failed: $@");
        }
        $RT::Logger->debug("Done.");
    }
    if ( @Groups ) {
        $RT::Logger->debug("Creating groups...");
        foreach my $item (@Groups) {
            my $new_entry = RT::Group->new( RT->SystemUser );
            $item->{Domain} ||= 'UserDefined';
            my $member_of = delete $item->{'MemberOf'};
            my $members = delete $item->{'Members'};
            my ( $return, $msg ) = $new_entry->_Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
                next;
            } else {
                $RT::Logger->debug($return .".");
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
            if ( $item->{'Name'} eq 'root' && $root_password ) {
                $item->{'Password'} = $root_password;
            }
            my $new_entry = RT::User->new( RT->SystemUser );
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @Members ) {
        $RT::Logger->debug("Adding users and groups to groups...");
        for my $item (@Members) {
            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadUserDefinedGroup( delete $item->{Group} );
            unless ($group->Id) {
                RT->Logger->error("Unable to find group '$group' to add members to");
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
    if ( @Queues ) {
        $RT::Logger->debug("Creating queues...");
        for my $item (@Queues) {
            my $new_entry = RT::Queue->new(RT->SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless ( $return ) {
                $RT::Logger->error( $msg );
            } else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }
    if ( @CustomFields ) {
        $RT::Logger->debug("Creating custom fields...");
        for my $item ( @CustomFields ) {
            my $new_entry = RT::CustomField->new( RT->SystemUser );
            my $values    = delete $item->{'Values'};

            my @queues;
            # if ref then it's list of queues, so we do things ourself
            if ( exists $item->{'Queue'} && ref $item->{'Queue'} ) {
                $item->{'LookupType'} ||= 'RT::Queue-RT::Ticket';
                @queues = @{ delete $item->{'Queue'} };
            }

            if ( $item->{'BasedOn'} ) {
                if ( $item->{'BasedOn'} =~ /^\d+$/) {
                    # Already have an ID -- should be fine
                } elsif ( $item->{'LookupType'} ) {
                    my $basedon = RT::CustomField->new($RT::SystemUser);
                    my ($ok, $msg ) = $basedon->LoadByCols( Name => $item->{'BasedOn'},
                                                            LookupType => $item->{'LookupType'} );
                    if ($ok) {
                        $item->{'BasedOn'} = $basedon->Id;
                    } else {
                        $RT::Logger->error("Unable to load $item->{BasedOn} as a $item->{LookupType} CF.  Skipping BasedOn: $msg");
                        delete $item->{'BasedOn'};
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
                my ( $return, $msg ) = $new_entry->AddValue(%$value);
                $RT::Logger->error( $msg ) unless $return;
            }

            # apply by default
            if ( !@queues && !exists $item->{'Queue'} && $item->{LookupType} ) {
                my $ocf = RT::ObjectCustomField->new(RT->SystemUser);
                $ocf->Create( CustomField => $new_entry->Id );
            }

            for my $q (@queues) {
                my $q_obj = RT::Queue->new(RT->SystemUser);
                $q_obj->Load($q);
                unless ( $q_obj->Id ) {
                    $RT::Logger->error("Could not find queue ". $q );
                    next;
                }
                my $OCF = RT::ObjectCustomField->new(RT->SystemUser);
                ( $return, $msg ) = $OCF->Create(
                    CustomField => $new_entry->Id,
                    ObjectId    => $q_obj->Id,
                );
                $RT::Logger->error( $msg ) unless $return and $OCF->Id;
            }
        }

        $RT::Logger->debug("done.");
    }
    if ( @ACL ) {
        $RT::Logger->debug("Creating ACL...");
        for my $item (@ACL) {

            my ($princ, $object);

            # Global rights or Queue rights?
            if ( $item->{'CF'} ) {
                $object = RT::CustomField->new( RT->SystemUser );
                my @columns = ( Name => $item->{'CF'} );
                push @columns, Queue => $item->{'Queue'} if $item->{'Queue'} and not ref $item->{'Queue'};
                $object->LoadByName( @columns );
            } elsif ( $item->{'Queue'} ) {
                $object = RT::Queue->new(RT->SystemUser);
                $object->Load( $item->{'Queue'} );
            } else {
                $object = $RT::System;
            }

            $RT::Logger->error("Couldn't load object") and next unless $object and $object->Id;

            # Group rights or user rights?
            if ( $item->{'GroupDomain'} ) {
                $princ = RT::Group->new(RT->SystemUser);
                if ( $item->{'GroupDomain'} eq 'UserDefined' ) {
                  $princ->LoadUserDefinedGroup( $item->{'GroupId'} );
                } elsif ( $item->{'GroupDomain'} eq 'SystemInternal' ) {
                  $princ->LoadSystemInternalGroup( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::System-Role' ) {
                  $princ->LoadSystemRoleGroup( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::Queue-Role' &&
                          $item->{'Queue'} )
                {
                  $princ->LoadQueueRoleGroup( Type => $item->{'GroupType'},
                                              Queue => $object->id);
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

            # Grant it
            my ( $return, $msg ) = $princ->PrincipalObj->GrantRight(
                Right => $item->{'Right'},
                Object => $object
            );
            unless ( $return ) {
                $RT::Logger->error( $msg );
            }
            else {
                $RT::Logger->debug( $return ."." );
            }
        }
        $RT::Logger->debug("done.");
    }

    if ( @ScripActions ) {
        $RT::Logger->debug("Creating ScripActions...");

        for my $item (@ScripActions) {
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
            my $new_entry = RT::Scrip->new(RT->SystemUser);

            my @queues = ref $item->{'Queue'} eq 'ARRAY'? @{ $item->{'Queue'} }: $item->{'Queue'} || 0;
            push @queues, 0 unless @queues; # add global queue at least

            foreach my $q ( @queues ) {
                my ( $return, $msg ) = $new_entry->Create( %$item, Queue => $q );
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
    if ( @Attributes ) {
        $RT::Logger->debug("Creating attributes...");
        my $sys = RT::System->new(RT->SystemUser);

        for my $item (@Attributes) {
            my $obj = delete $item->{Object}; # XXX: make this something loadable
            $obj ||= $sys;
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
            eval { $_->(); };
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

__PACKAGE__->FinalizeDatabaseType;

RT::Base->_ImportOverlays();

1;
