use strict;
use warnings;

use RT::Test tests => undef;

# This test uses some gymnastics to retrieve the column map out of the
# ColumnMap components under /Elements/RT__*/. the column map hashref is locked
# away in a lexical variable and the only way to get access to it is by
# overriding the GetColumnMapEntry function, which all existant ColumnMap
# components call. We use RT::Dashboard::Mailer for convenience; it's the
# easiest way to invoke Mason components outside of a web request. The
# dashboard mailer expects components to return strings, so we stash the column
# map hash in %COLUMN_MAP. we have to coalesce multiple calls to
# GetColumnMapEntry to handle the generic column map and the class-specific one
# since /Elements/ColumnMap tries both

use RT::Dashboard::Mailer;
no warnings 'redefine';
my %COLUMN_MAP;
*HTML::Mason::Commands::GetColumnMapEntry = sub {
    my %args = @_;
    %COLUMN_MAP = (%COLUMN_MAP, %{ $args{Map} });
    return undef;
};

my %BLACKLIST = (
    common   => [
        'Creator',
        'Created',
        'LastUpdatedBy',
        'LastUpdated',
        'SortOrder',
    ],

    'RT::Article' => [
        'Parent',  # to be removed
    ],

    'RT::Class' => [
    ],

    'RT::CustomField' => [
    ],

    'RT::Group' => [
        'Domain',    # internal
        'Instance',  # internal
    ],

    'RT::Scrip' => [
        'ScripAction',             # called "Action"
        'ScripCondition',          # called "Condition"
        'CustomCommitCode',        # large content
        'CustomPrepareCode',       # large content
        'CustomIsApplicableCode',  # large content
    ],

    'RT::Template' => [
        'Content',  # large content
    ],

    'RT::Ticket' => [
        'IsMerged',  # internal
    ],

    'RT::Transaction' => [
        'Data',           # handled by "Description"
        'NewReference',   # handled by "Description"
        'OldReference',   # handled by "Description"
        'ReferenceType',  # handled by "Description"
    ],

    'RT::User' => [
        'Password',          # secret
        'AuthToken',         # secret
        'SMIMECertificate',  # large content
        'Comments',          # large content
        'Signature',         # large content
    ],
);

my %COMMON = map { $_ => 1 } @{ $BLACKLIST{common} };

foreach my $endpoint (glob('share/html/Elements/RT__*/ColumnMap')) {
    # convert the filename to a class name
    (my $mapname = $endpoint) =~ s|.+/(RT__.+?)/.+|$1|;
    (my $class = $mapname) =~ s|__|::|;

    # skip RT::Dashboard and RT::SavedSearch
    next unless $class->isa('RT::Record');

    # ensure class is fully initialized
    $class->new(RT->SystemUser);

    # get the columns for this class from searchbuilder
    my @columns = keys %{ $class->_ClassAccessible };

    # get the keys for this class's columnmap
    %COLUMN_MAP = ();
    RT::Dashboard::Mailer::RunComponent('/Elements/ColumnMap', Class => $mapname, Name => 'nonexistent');
    my @keys = keys %COLUMN_MAP;
    my %has_map = map { $_ => 1 } @keys;
    my %blacklist = map { $_ => 1 } @{ $BLACKLIST{common} }, @{ $BLACKLIST{$class} || [] };

    for my $column (sort @columns) {
        if ($has_map{$column} && $blacklist{$column}) {
            unless ($COMMON{$column}) {
                ok(0, "blacklisted column '$column' for $class in ColumnMap; either remove from blacklist or ColumnMap");
            }
        }
        elsif ($has_map{$column} && !$blacklist{$column}) {
            ok(1, "nonblacklisted column '$column' for $class in ColumnMap");
        }
        elsif (!$has_map{$column} && $blacklist{$column}) {
            ok(1, "blacklisted column '$column' for $class in ColumnMap");
        }
        elsif (!$has_map{$column} && !$blacklist{$column}) {
            ok(0, "column '$column' for $class not present in ColumnMap; either add it to $mapname or blacklist it");
        }

        delete $blacklist{$column};
    }

    for my $leftover_column (sort keys %blacklist) {
        next if $COMMON{$leftover_column};
        ok(0, "saw $leftover_column in blacklist but it's nonexistent in $class; remove from blacklist?");
    }

    delete $BLACKLIST{$class};
}

delete $BLACKLIST{common};

for my $leftover_class (sort keys %BLACKLIST) {
    ok(0, "blacklisted class '$leftover_class' had no column map; remove from blacklist?");
}

done_testing;

