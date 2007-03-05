# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

  use RT::Handle;

=head1 DESCRIPTION

=begin testing

ok(require RT::Handle);

=end testing

=head1 METHODS

=cut

package RT::Handle;

use strict;
use vars qw/@ISA/;

eval "use DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .";
\@ISA= qw(DBIx::SearchBuilder::Handle::". RT->Config->Get('DatabaseType') .");";

if ($@) {
    die "Unable to load DBIx::SearchBuilder database handle for '". RT->Config->Get('DatabaseType') ."'.".
        "\n".
        "Perhaps you've picked an invalid database type or spelled it incorrectly.".
        "\n". $@;
}

=head2 Connect

Connects to RT's database handle.
Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
    my $self = shift;

    if (RT->Config->Get('DatabaseType') eq 'Oracle') {
        $ENV{'NLS_LANG'} = "AMERICAN_AMERICA.AL32UTF8";
        $ENV{'NLS_NCHAR'} = "AL32UTF8";
        
    }

    $self->SUPER::Connect(
			 User => RT->Config->Get('DatabaseUser'),
			 Password => RT->Config->Get('DatabasePassword'),
			);

    $self->dbh->{LongReadLen} = RT->Config->Get('MaxAttachmentSize');
   
}

=head2 BuildDSN

Build the DSN for the RT database. doesn't take any parameters, draws all that
from the config file.

=cut

use File::Spec;

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

# dealing with intial data

=head2 

=cut

sub create_db {
    my $self = shift;
    my $dbh  = shift || $self->dbh;
    my $db_type = RT->Config->Get('DatabaseType');
    my $db_name = RT->Config->Get('DatabaseName');
    print "Creating $db_type database $db_name.\n";
    if ( $db_type eq 'SQLite' ) {
        return;
    }
    elsif ( $db_type eq 'Pg' ) {
        $dbh->do("CREATE DATABASE $db_name WITH ENCODING='UNICODE'");
        if ( $DBI::errstr ) {
            $dbh->do("CREATE DATABASE $db_name") || die $DBI::errstr;
        }
    }
    elsif ( $db_type eq 'Informix' ) {
        $ENV{'DB_LOCALE'} = 'en_us.utf8';
        $dbh->do("CREATE DATABASE $db_name WITH BUFFERED LOG");
    }
    else {
        $dbh->do("CREATE DATABASE $db_name") or die $DBI::errstr;
    }
}

=head2 insert_acl

=cut

sub insert_acl {
    my $self = shift;
    my $dbh  = shift || $self->dbh;
    my $base_path = (shift || $RT::EtcPath);
    my $db_type = RT->Config->Get('DatabaseType');

    return if $db_type eq 'SQLite';

    # XXX: this is polluting acl()
    do $base_path ."/acl.". $db_type
        || die "Couldn't find ACLs for ". $db_type .": " . $@;

    my @acl = acl($dbh);
    foreach my $statement (@acl) {
#        print STDERR $statement if $args{'debug'};
        my $sth = $dbh->prepare($statement) or die $dbh->errstr;
        unless ( $sth->execute ) {
            die "Problem with statement:\n $statement\n" . $sth->errstr;
        }
    }
    print "Done setting up database ACLs.\n";
}

=head2 insert_schema

=cut

sub insert_schema {
    my $self = shift;
    my $dbh  = shift || $self->dbh;
    my $base_path = (shift || $RT::EtcPath);
    my $db_type = RT->Config->Get('DatabaseType');

    my $file = get_version_file( $base_path . "/schema." . $db_type );
    unless ( $file ) {
        die "Couldn't find schema file in '$base_path' dir";
    }
    unless ( -f $file || -r $file ) {
        die "File '$file' doesn't exist or couldn't be read";
    }

    my (@schema);
    print "Creating database schema.\n";

    open my $fh_schema, "<$file";

    my $has_local = 0;
    open my $fh_schema_local, "<" . get_version_file( $RT::LocalEtcPath . "/schema." . $db_type )
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
    my $is_local = 0; # local/etc/schema needs to be nonfatal.
    $dbh->begin_work or die $dbh->errstr;
    foreach my $statement (@schema) {
        if ( $statement =~ /^\s*;$/ ) { $is_local = 1; next; }

#        print "Executing SQL:\n$statement\n" if defined $args{'debug'};
        my $sth = $dbh->prepare($statement) or die $dbh->errstr;
        unless ( $sth->execute or $is_local ) {
            die "Problem with statement:\n$statement\n" . $sth->errstr;
        }
    }
    $dbh->commit or die $dbh->errstr;

    print "Done setting up database schema.\n";
}

=head1 get_version_file

Takes base name of the file as argument, scans for <base name>-<version> named
files and returns file name with closest version to the version of the RT DB.

=cut

sub get_version_file {
    my $base_name = shift;

    require File::Glob;
    my @files = File::Glob::bsd_glob("$base_name*");
    return '' unless @files;

    my %version = map { $_ =~ /\.\w+-([-\w\.]+)$/; ($1||0) => $_ } @files;
    my $db_version = $RT::Handle->DatabaseVersion;
    print "Server version $db_version\n";
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



eval "require RT::Handle_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Vendor.pm});
eval "require RT::Handle_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Handle_Local.pm});

1;
