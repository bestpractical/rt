# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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

use vars qw/@ISA/;
eval "use DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .";
\@ISA= qw(DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .");";

if ($@) {
    die "Unable to load DBIx::SearchBuilder database handle for '". RT->Config->Get('DatabaseType') ."'.\n".
        "Perhaps you've picked an invalid database type or spelled it incorrectly.\n".
        $@;
}

=head1 METHODS

=head2 Connect

Connects to RT's database using credentials and options from the RT config.
Takes nothing.

=cut

sub Connect {
    my $self = shift;

    if ( RT->Config->Get('DatabaseType') eq 'Oracle' ) {
        $ENV{'NLS_LANG'} = "AMERICAN_AMERICA.AL32UTF8";
        $ENV{'NLS_NCHAR'} = "AL32UTF8";
    }

    $self->SUPER::Connect(
            User => RT->Config->Get('DatabaseUser'),
        Password => RT->Config->Get('DatabasePassword'),
        );

    $self->dbh->{'LongReadLen'} = RT->Config->Get('MaxAttachmentSize');
}

=head2 BuildDSN

Build the DSN for the RT database. Doesn't take any parameters, draws all that
from the config.

=cut

require File::Spec;

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


    $self->SUPER::BuildDSN( Host       => $db_host,
                                        Database   => $db_name,
                            Port       => $db_port,
                            Driver     => $db_type,
                            RequireSSL => RT->Config->Get('DatabaseRequireSSL'),
                            DisconnectHandleOnDestroy => 1,
                          );
   

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
    elsif ( $db_type eq 'Informix' ) {
        # with Informix, you want to connect sans database:
        $dsn =~ s/Informix:\Q$db_name/Informix:/;
    }
    return $dsn;
}

=head2 Database compatibility and integrity checks



=cut

sub CheckIntegrity {
    my $self = shift;
    
    my $dsn = $self->DSN;
    my $user = RT->Config->Get('DatabaseUser');
    my $pass = RT->Config->Get('DatabasePassword');

    my $dbh = DBI->connect(
        $dsn, $user, $pass,
        { RaiseError => 0, PrintError => 0 },
    );
    unless ( $dbh ) {
        return (0, 'no connection', "Failed to connect to $dsn as user '$user': ". $DBI::errstr);
    }

    RT::ConnectToDatabase();
    RT::InitLogging();

    require RT::CurrentUser;
    my $test_user = new RT::CurrentUser;
    $test_user->Load('RT_System');
    unless ( $test_user->id ) {
        return (0, 'no system user', "Couldn't find RT_System user in the DB '$dsn'");
    }

    $test_user = new RT::CurrentUser;
    $test_user->Load('Nobody');
    unless ( $test_user->id ) {
        return (0, 'no nobody user', "Couldn't find Nobody user in the DB '$dsn'");
    }

    return $dbh;
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
        return (0, "RT is unsupported on MySQL versions before 4.0.x, it's $version")
            if $version < 4;

        # MySQL must have InnoDB support
        my $innodb = ($dbh->selectrow_array("show variables like 'have_innodb'"))[1];
        if ( lc $innodb eq "no" ) {
            return (0, "RT requires that MySQL be compiled with InnoDB table support.\n".
                "See http://dev.mysql.com/doc/mysql/en/InnoDB.html");
        } elsif ( lc $innodb eq "disabled" ) {
            return (0, "RT requires that MySQL InnoDB table support be enabled.\n".
                "Remove the 'skip-innodb' line from your my.cnf file, restart MySQL, and try again.\n");
        }

        if ( $state eq 'post' ) {
            my $create_table = $dbh->selectrow_arrayref("SHOW CREATE TABLE Tickets")->[1];
            unless ( $create_table =~ /(?:ENGINE|TYPE)\s*=\s*InnoDB/i ) {
                return (0, "RT requires that all its tables be of InnoDB type. Upgrade RT tables.");
            }
        }
        if ( $version >= 4.1 && $state eq 'post' ) {
            my $create_table = $dbh->selectrow_arrayref("SHOW CREATE TABLE Attachments")->[1];
            unless ( $create_table =~ /\bContent\b[^,]*BLOB/i ) {
                return (0, "RT since version 3.8 has new schema for MySQL versions after 4.1.0\n"
                    ."Follow instructions in the UPGRADING.mysql file.");
            }
        }
    }
    return (1)
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
        return (1, 'Skipped as we\'re working with Oracle');
    }
    elsif ( $db_type eq 'Pg' ) {
        # XXX: as we get external DBH we don't know if RaiseError or PrintError
        # are enabled, so we have to setup it here and restore them back
        $status = $dbh->do("CREATE DATABASE $db_name WITH ENCODING='UNICODE'")
            || $dbh->do("CREATE DATABASE $db_name");
    }
    elsif ( $db_type eq 'Informix' ) {
        local $ENV{'DB_LOCALE'} = 'en_us.utf8';
        $status = $dbh->do("CREATE DATABASE $db_name WITH BUFFERED LOG");
    }
    else {
        $status = $dbh->do("CREATE DATABASE $db_name");
    }
    return ($status, $DBI::errstr);
}

=head3 DropDatabase $DBH [Force => 0]

Drops RT's database. This method can be used as class method.

Takes DBI handle as first argument. Many database systems require
special handle to allow you to create a new database, so you have
to use L<SystemDSN> method during connection.

Fetches type and name of the DB from the config.

=cut

sub DropDatabase {
    my $self = shift;
    my $dbh  = shift or return (0, "No DBI handle provided");

    my $db_type = RT->Config->Get('DatabaseType');
    my $db_name = RT->Config->Get('DatabaseName');

    if ( $db_type eq 'Oracle' || $db_type eq 'Informix' ) {
        return (0, "Use etc/drop.$db_type to drop database");
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
        $path = File::Spec->catfile( $base_path, "acl")
            unless -e $path;
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
    unless ( -f $file || -r $file ) {
        return (0, "File '$file' doesn't exist or couldn't be read");
    }

    my (@schema);

    open my $fh_schema, "<$file";

    my $has_local = 0;
    open my $fh_schema_local, "<" . $self->GetVersionFile( $dbh, $RT::LocalEtcPath . "/schema." . $db_type )
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

sub cmp_version($$) {
    my ($a, $b) = (@_);
    my @a = split /[^0-9]+/, $a;
    my @b = split /[^0-9]+/, $b;
    for ( my $i = 0; $i < @a; $i++ ) {
        return 1 unless defined $b[$i];
        return $a[$i] <=> $b[$i] if $a[$i] <=> $b[$i];
    }
    return 0 if @a == @b;
    return -1;
}


=head2 InsertInitialData

=cut

sub InsertInitialData {
    my $self    = shift;
    my $db_type = RT->Config->Get('DatabaseType');

    #Put together a current user object so we can create a User object
    require RT::CurrentUser;
    my $CurrentUser = new RT::CurrentUser;

    my @warnings;

    my $test_user = RT::User->new($CurrentUser);
    $test_user->Load('RT_System');
    if ( $test_user->id ) {
        push @warns, "Found system user in the DB.";
    }
    else {
        my $user = RT::User->new( $CurrentUser );
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

    $CurrentUser = new RT::CurrentUser;
    $CurrentUser->LoadByName('RT_System');
    unless ( $CurrentUser->id ) {
        return (0, "Couldn't load system user");
    }

    my $test_ace = RT::ACE->new( $CurrentUser );
    $test_ace->LoadByCols(
        PrincipalId   => ACLEquivGroupId( $CurrentUser->Id ),
        PrincipalType => 'Group',
        RightName     => 'SuperUser',
        ObjectType    => 'RT::System',
        ObjectId      => 1,
    );
    if ( $test_ace->id ) {
        push @warns, "System user has global SuperUser right.";
        
    } else {
        my $superuser_ace = RT::ACE->new( $CurrentUser );
        $superuser_ace->_BootstrapCreate(
            PrincipalId   => ACLEquivGroupId( $CurrentUser->Id ),
            PrincipalType => 'Group',
            RightName     => 'SuperUser',
            ObjectType    => 'RT::System',
            ObjectId      => 1,
        );
    }
    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    push @warns, "You appear to have a functional RT database."
        if @warns;

    return (1, @warns);
}

=head InsertData

Load some sort of data into the database, takes path to a file.

=cut

sub InsertData {
    my $self     = shift;
    my $datafile = shift;

    # Slurp in stuff to insert from the datafile. Possible things to go in here:-
    our (@Groups, @Users, @ACL, @Queues, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);
    local (@Groups, @Users, @ACL, @Queues, @ScripActions, @ScripConditions,
           @Templates, @CustomFields, @Scrips, @Attributes, @Initial, @Final);

    local $@;
    eval { require $datafile }
      or return (0, "Couldn't load data from '$datafile' for import:\n\nERROR:". $@);

    if ( @Initial ) {
        print "Running initial actions...\n";
        # Don't trap errors here, as they *should* be fatal
        $_->() for @Initial;
    }
    if ( @Groups ) {
        print "Creating groups...";
        foreach my $item (@Groups) {
            my $new_entry = RT::Group->new( $RT::SystemUser );
            my $member_of = delete $item->{'MemberOf'};
            my ( $return, $msg ) = $new_entry->_Create(%$item);
            print "(Error: $msg)" unless $return;
            print $return. ".";
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
                        print "(Error: wrong format of MemberOf field."
                            ." Should be name of user defined group or"
                            ." hash reference with 'column => value' pairs."
                            ." Use array reference to add to multiple groups)";
                        next;
                    }
                    unless ( $parent->Id ) {
                        print "(Error: couldn't load group to add member)";
                        next;
                    }
                    my ( $return, $msg ) = $parent->AddMember( $new_entry->Id );
                    print "(Error: $msg)" unless ($return);
                    print $return. ".";
                }
            }
        }
        print "done.\n";
    }
    if ( @Users ) {
        print "Creating users...";
        foreach my $item (@Users) {
            my $new_entry = new RT::User($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            print "(Error: $msg)" unless $return;
            print $return. ".";
        }
        print "done.\n";
    }
    if ( @Queues ) {
        print "Creating queues...";
        for my $item (@Queues) {
            my $new_entry = new RT::Queue($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            print "(Error: $msg)" unless $return;
            print $return. ".";
        }
        print "done.\n";
    }
    if ( @CustomFields ) {
        print "Creating custom fields...";
        for my $item ( @CustomFields ) {
            my $new_entry = new RT::CustomField( $RT::SystemUser );
            my $values    = delete $item->{'Values'};

            my @queues;
            # if ref then it's list of queues, so we do things ourself
            if ( exists $item->{'Queue'} && ref $item->{'Queue'} ) {
                $item->{'LookupType'} = 'RT::Queue-RT::Ticket';
                @queues = @{ delete $item->{'Queue'} };
            }

            my ( $return, $msg ) = $new_entry->Create(%$item);
            unless( $return ) {
                print "(Error: $msg)\n";
                next;
            }

            foreach my $value ( @{$values} ) {
                my ( $return, $msg ) = $new_entry->AddValue(%$value);
                print "(Error: $msg)\n" unless $return;
            }

            # apply by default
            if ( !@queues && !exists $item->{'Queue'} && $item->{LookupType} ) {
                my $ocf = RT::ObjectCustomField->new($RT::SystemUser);
                $ocf->Create( CustomField => $new_entry->Id );
            }

            for my $q (@queues) {
                my $q_obj = RT::Queue->new($RT::SystemUser);
                $q_obj->Load($q);
                unless ( $q_obj->Id ) {
                    print "(Error: Could not find queue " . $q . ")\n";
                    next;
                }
                my $OCF = RT::ObjectCustomField->new($RT::SystemUser);
                ( $return, $msg ) = $OCF->Create(
                    CustomField => $new_entry->Id,
                    ObjectId    => $q_obj->Id,
                );
                print "(Error: $msg)\n" unless $return and $OCF->Id;
            }

            print $new_entry->Id. ".";
        }

        print "done.\n";
    }
    if ( @ACL ) {
        print "Creating ACL...";
        for my $item (@ACL) {

            my ($princ, $object);

            # Global rights or Queue rights?
            if ( $item->{'CF'} ) {
                $object = RT::CustomField->new( $RT::SystemUser );
                my @columns = ( Name => $item->{'CF'} );
                push @columns, Queue => $item->{'Queue'} if $item->{'Queue'} and not ref $item->{'Queue'};
                $object->LoadByName( @columns );
            } elsif ( $item->{'Queue'} ) {
                $object = RT::Queue->new($RT::SystemUser);
                $object->Load( $item->{'Queue'} );
            } else {
                $object = $RT::System;
            }

            print "Couldn't load object" and next unless $object and $object->Id;

            # Group rights or user rights?
            if ( $item->{'GroupDomain'} ) {
                $princ = RT::Group->new($RT::SystemUser);
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
            } else {
                $princ = RT::User->new($RT::SystemUser);
                $princ->Load( $item->{'UserId'} );
            }

            # Grant it
            my ( $return, $msg ) = $princ->PrincipalObj->GrantRight(
                                                     Right => $item->{'Right'},
                                                     Object => $object );

            if ( $return ) {
                print $return. ".";
            }
            else {
                print $msg . ".";

            }

        }
        print "done.\n";
    }

    if ( @ScripActions ) {
        print "Creating ScripActions...";

        for my $item (@ScripActions) {
            my $new_entry = RT::ScripAction->new($RT::SystemUser);
            my $return    = $new_entry->Create(%$item);
            print $return. ".";
        }

        print "done.\n";
    }

    if ( @ScripConditions ) {
        print "Creating ScripConditions...";

        for my $item (@ScripConditions) {
            my $new_entry = RT::ScripCondition->new($RT::SystemUser);
            my $return    = $new_entry->Create(%$item);
            print $return. ".";
        }

        print "done.\n";
    }

    if ( @Templates ) {
        print "Creating templates...";

        for my $item (@Templates) {
            my $new_entry = new RT::Template($RT::SystemUser);
            my $return    = $new_entry->Create(%$item);
            print $return. ".";
        }
        print "done.\n";
    }
    if ( @Scrips ) {
        print "Creating scrips...";

        for my $item (@Scrips) {
            my $new_entry = new RT::Scrip($RT::SystemUser);

            my @queues = ref $item->{'Queue'} eq 'ARRAY'? @{ $item->{'Queue'} }: $item->{'Queue'} || 0;
            push @queues, 0 unless @queues; # add global queue at least

            foreach my $q ( @queues ) {
                my ( $return, $msg ) = $new_entry->Create( %$item, Queue => $q );
            if ( $return ) {
                    print $return. ".";
                }
                else {
                    print "(Error: $msg)\n";
                }
            }
        }
        print "done.\n";
    }
    if ( @Attributes ) {
        print "Creating predefined searches...";
        my $sys = RT::System->new($RT::SystemUser);

        for my $item (@Attributes) {
            my $obj = delete $item->{Object}; # XXX: make this something loadable
            $obj ||= $sys;
            my ( $return, $msg ) = $obj->AddAttribute (%$item);
            if ( $return ) {
                print $return. ".";
            }
            else {
                print "(Error: $msg)\n";
            }
        }
        print "done.\n";
    }
    if ( @Final ) {
        print "Running final actions...\n";
        for ( @Final ) {
            eval { $_->(); };
            print "(Error: $@)\n" if $@;
        }
    }

    my $db_type = RT->Config->Get('DatabaseType');
    $RT::Handle->Disconnect() unless $db_type eq 'SQLite';
    print "Done setting up database content.\n";
}

=head2 ACLEquivGroupId

Given a userid, return that user's acl equivalence group

=cut

sub ACLEquivGroupId {
    my $username = shift;
    my $user     = RT::User->new($RT::SystemUser);
    $user->Load($username);
    my $equiv_group = RT::Group->new($RT::SystemUser);
    $equiv_group->LoadACLEquivalenceGroup($user);
    return ( $equiv_group->Id );
}

eval "require RT::Handle_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Vendor.pm});
eval "require RT::Handle_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Local.pm});

1;
