#!/usr/bin/env perl
# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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
use strict;
use warnings;

use DBI;
use DBD::mysql 4.002;

unless (@ARGV) {
    print STDERR "usage: $0 db_name[:server_name] db_user db_password\n";
    exit 1;
}

# pretty correct support of charsets has been introduced in mysql 4.1
# as RT doesn't use it may result in issues:
# 1) data corruptions when default charset of mysql server has data restrictions like utf8
# 2) wrong ordering (collations)

# we have to define correct types for all columns. RT uses UTF-8, ascii and binary.
# * ascii is subset of many mysql's charsets except may be one or two rare where some ascii
#   characters replaced with local
# * for many charsets mysql allows us to store any octets sequences even when those are
#   invalid for this particula set, for example we can store UTF-8 data in latin1
#   column and fetch it as UTF-8, however sorting will be wrong

# here is tricky algorithm to change column to desired charset:
# * text to binary convertion is pretty straight forward except that text types
#   have length definitions in terms of characters and in some cases we must
#   use longer binary types to satisfy space requirements
# * binary to text is much easier as we know that there is ascii or UTF-8 then
#   we just make convertion, also 32 chars are long enough to store 32 bytes, so
#   length changes is not required
# * text to text convertion is trickier. no matter what is the current character set
#   of the column we know that there is either ascii or UTF-8, so we can not use
#   direct convertion, instead we do text to binary plus binary to text convertion
#   instead
# * as well we add charset definition for all tables and for the DB as well,
#   so all new columns by default will be in UTF-8 charset

my @tables = qw(
    ACL
    Attachments
    Attributes
    CustomFields
    CustomFieldValues
    GroupMembers
    Groups
    Links
    ObjectCustomFields
    ObjectCustomFieldValues
    Principals
    Queues
    ScripActions
    ScripConditions
    Scrips
    sessions
    Templates
    Tickets
    Transactions
    Users
    FM_Articles
    FM_Classes
    FM_ObjectTopics
    FM_Topics
);

my %charset = (
    ACL                      => {
        RightName     => 'ascii',
        ObjectType    => 'ascii',
        PrincipalType => 'ascii',
    },
    Attachments              => {
        MessageId  => 'ascii',
        Subject  => 'utf8',
        Filename  => 'utf8',
        ContentType  => 'ascii',
        ContentEncoding  => 'ascii',
        Content  => 'binary',
        Headers  => 'utf8',
    },
    Attributes               => {
        Name  => 'utf8',
        Description  => 'utf8',
        Content  => 'binary',
        ContentType  => 'ascii',
        ObjectType  => 'ascii',
    },
    CustomFields             => {
        Name  => 'utf8',
        Type  => 'ascii',
        Pattern  => 'utf8',
        Description  => 'utf8',
        LookupType => 'ascii',
    },
    CustomFieldValues        => {
        Name  => 'utf8',
        Description  => 'utf8',
    },
    FM_Articles => {
        Name => 'utf8',
        Summary => 'utf8',
        URI => 'ascii',
    },
    FM_Classes => {
        Name => 'utf8',
        Description => 'utf8',
    },
    FM_ObjectTopics => {
        ObjectType => 'ascii',
    },
    FM_Topics => {
        Name => 'utf8',
        Description => 'utf8',
        ObjectType => 'ascii',
    },
    Groups                   => {
        Name  => 'utf8',
        Description  => 'utf8',
        Domain  => 'ascii',
        Type  => 'ascii',
    },
    Links                    => {
        Base  => 'ascii',
        Target  => 'ascii',
        Type  => 'ascii',
    },
    ObjectCustomFieldValues  => {
        ObjectType  => 'ascii',
        Content  => 'utf8',
        LargeContent  => 'binary',
        ContentType  => 'ascii',
        ContentEncoding  => 'ascii',
    },
    Principals               => {
        PrincipalType  => 'ascii',
    },
    Queues                   => {
        Name  => 'utf8',
        Description  => 'utf8',
        CorrespondAddress  => 'utf8',
        CommentAddress  => 'utf8',
    },
    ScripActions             => {
        Name  => 'utf8',
        Description  => 'utf8',
        ExecModule  => 'ascii',
        Argument  => 'binary',
    },
    ScripConditions          => {
        Name  => 'utf8',
        Description  => 'utf8',
        ExecModule  => 'ascii',
        Argument  => 'binary',
        ApplicableTransTypes  => 'ascii',
    },
    Scrips                   => {
        Description  => 'utf8',
        ConditionRules  => 'utf8',
        ActionRules  => 'utf8',
        CustomIsApplicableCode  => 'utf8',
        CustomPrepareCode  => 'utf8',
        CustomCommitCode  => 'utf8',
        Stage  => 'ascii',
    },
    sessions                 => {
        id         => 'binary', # ascii?
        a_session  => 'binary',
    },
    Templates                => {
        Name  => 'utf8',
        Description  => 'utf8',
        Type  => 'ascii',
        Language  => 'ascii',
        Content  => 'utf8',
    },
    Tickets                  => {
        Type  => 'ascii',
        Subject  => 'utf8',
        Status  => 'ascii',
    },
    Transactions             => {
        ObjectType  => 'ascii',
        Type  => 'ascii',
        Field  => 'ascii',
        OldValue  => 'utf8',
        NewValue  => 'utf8',
        ReferenceType  => 'ascii',
        Data  => 'utf8',
    },
    Users                    => {
        Name  => 'utf8',
        Password  => 'binary',
        Comments  => 'utf8',
        Signature  => 'utf8',
        EmailAddress  => 'utf8',
        FreeformContactInfo  => 'utf8',
        Organization  => 'utf8',
        RealName  => 'utf8',
        NickName  => 'utf8',
        Lang  => 'ascii',
        Gecos  => 'utf8',
        HomePhone  => 'utf8',
        WorkPhone  => 'utf8',
        MobilePhone  => 'utf8',
        PagerPhone  => 'utf8',
        Address1  => 'utf8',
        Address2  => 'utf8',
        City  => 'utf8',
        State  => 'utf8',
        Zip  => 'utf8',
        Country  => 'utf8',
        Timezone  => 'ascii',
    },
);

my %max_type_length = (
    char       => int 1<<8,
    varchar    => int 1<<8,
    tinytext   => int 1<<8,
    mediumtext => int 1<<16,
    text       => int 1<<24,
    longtext   => int 1<<32,
);

my @sql_commands;

my ($db_datasource, $db_user, $db_pass) = (shift, shift, shift);
my $dbh = DBI->connect("dbi:mysql:$db_datasource", $db_user, $db_pass, { RaiseError => 1 });
my $db_name = $db_datasource;
$db_name =~ s/:.*$//;

my $version = ($dbh->selectrow_array("show variables like 'version'"))[1];
($version) = $version =~ /^(\d+\.\d+)/;

push @sql_commands, qq{ALTER DATABASE `$db_name` DEFAULT CHARACTER SET utf8};
convert_table($_) foreach @tables;

print join "\n", map(/;$/? $_ : "$_;", @sql_commands), "";
my $use_p = $db_pass ? " -p" : '';
print STDERR <<ENDREMINDER;
-- ** NOTICE: No database changes have been made. **
-- Please review the generated SQL, ensure you have a full backup of your database 
-- and apply it to your database using a command like:
-- mysql -u ${db_user}${use_p} $db_name < queries.sql";
ENDREMINDER
exit 0;

my %alter_aggregator;
sub convert_table {
    my $table = shift;
    @alter_aggregator{'char_to_binary','binary_to_char'} = (['DEFAULT CHARACTER SET utf8'],[]);

    my $sth = $dbh->column_info( undef, $db_name, $table, undef );
    $sth->execute;
    my $columns = $sth->fetchall_arrayref({});
    return unless @$columns;
    foreach my $info (@$columns) {
        convert_column(%$info);
    }
    for my $conversiontype (qw(char_to_binary binary_to_char)) {
        next unless @{$alter_aggregator{$conversiontype}};
        push @sql_commands, qq{ALTER TABLE $table\n   }.
            join(",\n   ",@{$alter_aggregator{$conversiontype}});
    }
}

sub convert_column {
    my %info = @_;
    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $type = $info{'TYPE_NAME'};
    return unless $type =~ /(CHAR|TEXT|BLOB|BINARY)$/i;

    my $required_charset = $charset{$table}{$column};
    unless ( $required_charset ) {
        print STDERR join(".", @info{'TABLE_SCHEMA', 'TABLE_NAME', 'COLUMN_NAME'})
            ." has type $type however mapping is missing.\n";
        return;
    }

    my $collation = column_info($table, $column)->{'collation'};
    # mysql 4.1 returns literal NULL instead of undef
    my $current_charset = $collation && $collation ne 'NULL'? (split /_/, $collation)[0]: 'binary';
    return if $required_charset eq $current_charset;

    if ( $required_charset eq 'binary' ) {
        char_to_binary(%info);
    }
    elsif ( $current_charset eq 'binary' ) {
        binary_to_char( $required_charset, %info);
    } else {
        char_to_char( $required_charset, %info);
    }
}

sub char_to_binary {
    my %info = @_;

    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $new_type = calc_suitable_binary_type(%info);
    push @{$alter_aggregator{char_to_binary}},
        "MODIFY $column $new_type ".build_column_definition(%info);

}

sub binary_to_char {
    my ($charset, %info) = @_;

    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $new_type = lc $info{'TYPE_NAME'};
    if ( $new_type =~ /binary/ ) {
        $new_type =~ s/binary/char/;
        $new_type .= '('. $info{'COLUMN_SIZE'} .')';
    } else {
        $new_type =~ s/blob/text/;
    }

    push @{$alter_aggregator{binary_to_char}},
        "MODIFY $column ". uc($new_type) ." CHARACTER SET ". $charset
        ." ". build_column_definition(%info);
}

sub char_to_char {
    my ($charset, %info) = @_;

    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $new_type = $info{'mysql_type_name'};

    char_to_binary(%info);
    push @{$alter_aggregator{binary_to_char}},
        "MODIFY $column ". uc($new_type)." CHARACTER SET ". $charset
        ." ". build_column_definition(%info);
}

sub calc_suitable_binary_type {
    my %info = @_;
    my $type = lc $info{'TYPE_NAME'};
    return 'LONGBLOB' if $type eq 'longtext';

    my $current_max_byte_length = column_byte_length(@info{qw(TABLE_NAME COLUMN_NAME)}) || 0;
    if ( $max_type_length{ $type } > $current_max_byte_length ) {
        if ( $type eq 'varchar' || $type eq 'char' ) {
            my $new_type = $type;
            $new_type =~ s/char/binary/;
            $new_type .= $info{'COLUMN_SIZE'} >= $current_max_byte_length
                ? '('. $info{'COLUMN_SIZE'} .')'
                : '('. $current_max_byte_length .')';
            return uc $new_type;
        } else {
            my $new_type = $type;
            $new_type =~ s/text/blob/;
            return uc $new_type;
        }
    } else {
        my $new_type;
        foreach ( sort { $max_type_length{$a} <=> $max_type_length{$b} } keys %max_type_length ) {
            next if $max_type_length{ $_ } <= $current_max_byte_length;
            
            $new_type = $_; last;
        }
        $new_type =~ s/text/blob/;
        return uc $new_type;
    }
}

sub build_column_definition {
    my %info = @_;

    my $res = '';
    $res .= 'NOT ' unless $info{'NULLABLE'};
    $res .= 'NULL';
    my $default = column_info(@info{qw(TABLE_NAME COLUMN_NAME)})->{default};
    if ( defined $default ) {
        $res .= ' DEFAULT '. $dbh->quote($default);
    } elsif ( $info{'NULLABLE'} ) {
        $res .= ' DEFAULT NULL';
    }
    $res .= ' AUTO_INCREMENT' if $info{'mysql_is_auto_increment'};
    return $res;
}

sub column_byte_length {
    my ($table, $column) = @_;
    if ( $version >= 5.0 ) {
        # information_schema searches can be case sensitive
        # and users may use lower_case_table_names, use LOWER
        # for everything just in case
        # http://dev.mysql.com/doc/refman/5.1/en/charset-collation-information-schema.html
        my ($char, $octet) = @{ $dbh->selectrow_arrayref(
            "SELECT CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH FROM information_schema.COLUMNS WHERE"
            ."     LOWER(TABLE_SCHEMA) = ". lc( $dbh->quote($db_name) )
            ." AND LOWER(TABLE_NAME)   = ". lc( $dbh->quote($table) )
            ." AND LOWER(COLUMN_NAME)  = ". lc( $dbh->quote($column) )
        ) };
        return $octet if $octet == $char;
    }
    return $dbh->selectrow_arrayref("SELECT MAX(LENGTH(". $dbh->quote_identifier($column) .")) FROM $table")->[0];
}

sub column_info {
    my ($table, $column) = @_;
    # XXX: DBD::mysql doesn't provide this info, may be will do in 4.0007 if I'll write a patch
    local $dbh->{FetchHashKeyName} = 'NAME_lc';
    return $dbh->selectrow_hashref("SHOW FULL COLUMNS FROM $table LIKE " . $dbh->quote($column));
}

