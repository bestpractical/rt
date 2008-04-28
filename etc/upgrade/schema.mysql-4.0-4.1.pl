#!/usr/bin/perl

use strict;
use warnings;

use DBI;

unless (@ARGV) {
    print STDERR "usage: $0 db_name db_user db_password\n";
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
        CorrespondAddress  => 'ascii',
        CommentAddress  => 'ascii',
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
        EmailAddress  => 'ascii',
        FreeformContactInfo  => 'utf8',
        Organization  => 'utf8',
        RealName  => 'utf8',
        NickName  => 'utf8',
        Lang  => 'ascii',
        EmailEncoding  => 'ascii',
        WebEncoding  => 'ascii',
        ExternalContactInfoId  => 'utf8',
        ContactInfoSystem  => 'utf8',
        ExternalAuthId  => 'utf8',
        AuthSystem  => 'utf8',
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
        PGPKey  => 'binary',
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

my ($db_name, $db_user, $db_pass) = (shift, shift, shift);
my $dbh = DBI->connect("dbi:mysql:$db_name", $db_user, $db_pass, { RaiseError => 1 });


push @sql_commands, qq{ALTER DATABASE $db_name DEFAULT CHARACTER SET utf8};
convert_table($_) foreach @tables;

print join "\n", @sql_commands, "";
exit 0;

sub convert_table {
    my $table = shift;
    push @sql_commands, qq{ALTER TABLE $table DEFAULT CHARACTER SET utf8};

    my $sth = $dbh->column_info( undef, $db_name, $table, undef );
    $sth->execute;
    while ( my $info = $sth->fetchrow_hashref ) {
        convert_column(%$info);
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
        print STDERR join(".", @info{'TABLE_SCHEM', 'TABLE_NAME', 'COLUMN_NAME'})
            ." has type $type however mapping is missing.\n";
        return;
    }

    my $collation = column_info($table, $column)->{'collation'};
    my $current_charset = $collation? (split /_/, $collation)[0]: 'binary';
    return if $required_charset eq $current_charset;

    if ( $required_charset eq 'binary' ) {
        push @sql_commands, char_to_binary(%info);
    }
    elsif ( $current_charset eq 'binary' ) {
        push @sql_commands, binary_to_char( $required_charset, %info);
    } else {
        push @sql_commands, char_to_char( $required_charset, %info);
    }
}

sub char_to_binary {
    my %info = @_;

    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $new_type = calc_suitable_binary_type(%info);

    return "ALTER TABLE $table MODIFY $column ". $new_type ." ". build_column_definition(%info);
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

    return "ALTER TABLE $table MODIFY $column ". uc($new_type)
        ." CHARACTER SET ". $charset
        ." ". build_column_definition(%info);
}

sub char_to_char {
    my ($charset, %info) = @_;

    my $table = $info{'TABLE_NAME'};
    my $column = $info{'COLUMN_NAME'};
    my $new_type = $info{'mysql_type_name'};

    return char_to_binary(%info),
        "ALTER TABLE $table MODIFY $column ". uc($new_type)
            ." CHARACTER SET ". $charset
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
        $default = $dbh->quote($default);
    } else {
        $default = 'NULL';
    }
    $res .= ' DEFAULT '. $default;
    $res .= ' AUTO_INCREMENT' if $info{'mysql_is_auto_increment'};
    return $res;
}

sub column_byte_length {
    my ($table, $column) = @_;
    return $dbh->selectrow_arrayref("SELECT MAX(LENGTH(". $dbh->quote($column) .")) FROM $table")->[0];
}

sub column_info {
    my ($table, $column) = @_;
    # XXX: DBD::mysql doesn't provide this info, may be will do in 4.0007 if I'll write a patch
    local $dbh->{FetchHashKeyName} = 'NAME_lc';
    return $dbh->selectrow_hashref("SHOW FULL COLUMNS FROM $table LIKE " . $dbh->quote($column));
}

