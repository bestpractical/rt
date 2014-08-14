use strict;
use warnings;
use utf8;

use File::Find;

use RT;
use RT::Dashboard::Mailer;
use Data::Dumper;

RT->InitLogging;
my $mason = RT::Dashboard::Mailer::_mason();

use RT::Test tests => undef;

my $blacklist = {
    common   => [qw(
        Creator
        Created
        LastUpdatedBy
        LastUpdated
    )],
    Articles => [qw(
        id
        SortOrder
        Parent
    )],
    Classes => [qw(
        SortOrder
        Disabled
        HotList
    )],
    CustomFields => [qw(
        Repeated
        SortOrder
    )],
    Groups => [qw(
        Domain
        Type
        Instance
    )],
    Queues => [qw(
    )],
    Scrips => [qw(
        ScripCondition
        ScripAction
        ConditionRules
        ActionRules
        CustomIsApplicableCode
        CustomPrepareCode
        CustomCommitCode
        Queue
        Template
    )],
    Templates => [qw(
        Queue
        Type
        Language
        TranslationOf
        Content
    )],
    Tickets => [qw(
        id
        IssueStatement
        Resolution
        Owner
        Disabled
    )],
    Users => [qw(
        Password
        AuthToken
        Comments
        Signature
        FreeformContactInfo
        EmailEncoding
        WebEncoding
        ExternalContactInfoId
        ContactInfoSystem
        ExternalAuthId
        AuthSystem
        Timezone
        PGPKey
    )],
};

my ($base, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $docroot = join '/', qw(share html);

# find endpoints to loop over
my @endpoints;
find({
    wanted => sub {
        if ( m|RT__| && m|ColumnMap$|  ) {
            ( my $endpoint = $_ ) =~ s|^$docroot||;
            push @endpoints, $endpoint;
        }
    },
    no_chdir => 1,
} => join '/', $docroot => 'Elements');

foreach my $endpoint ( @endpoints ) {
    # convert the file name in to a class name
    (my $class = $endpoint) =~ s|.+/(RT__.+?)/.+|$1|;
    $class =~ s|__|::|;
    next unless $class->can('Table');

    # get the name of the db table this class represents
    my $table = $class->Table;

    # get the columns for this table from the db
    my $raw = $RT::Handle->dbh->selectall_arrayref("Describe $table;");
    my @columns = map $_->[0], @$raw;

    # columns for this table that don't get a ColumnMap entry
    my %TableBlacklist = map { $_ => 1 }
        @{ $blacklist->{$table} }, @{ $blacklist->{common} }
    ;

    foreach my $column ( @columns ) {
        if ( ! $TableBlacklist{ $column } ) {
            my $map = $mason->exec($endpoint, Name => $column, Attr => 'attribute');
            ok( $map, sprintf "%s.%s has ColumnMap entry", $table, $column);
        }
    }
}

undef $m;
done_testing;

__DATA__

#  print Data::Dumper::Dumper( \@columns ), "\n";
  print $table, "\n";
  foreach my $column ( @columns ) {
    my $map = $mason->exec($endpoint, Name => $column, Attr => 'attribute');
    if ($map) {
      printf "\tColumn: %s\tAttribute: %s\n", $column, $map;
    } else {
      printf "\tColumn: %s\tMISSING ATTRIBUTE\n", $column;
    }
  }
