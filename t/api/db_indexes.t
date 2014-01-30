use strict;
use warnings;
use Test::Warn;

use RT::Test tests => undef;

my $handle = $RT::Handle;
my $db_type = RT->Config->Get('DatabaseType');

# Pg,Oracle needs DBA
RT::Test::__reconnect_rt('as dba');
ok( $handle->dbh->do("ALTER SESSION SET CURRENT_SCHEMA=". RT->Config->Get('DatabaseUser') ) )
    if $db_type eq 'Oracle';

note "test handle->Indexes method";
{
    my %indexes = $handle->Indexes;
    ok grep $_ eq 'tickets1', @{ $indexes{'tickets'} };
    ok grep $_ eq 'tickets2', @{ $indexes{'tickets'} };
    ok grep $_ eq 'users1', @{ $indexes{'users'} };
    ok grep $_ eq 'users4', @{ $indexes{'users'} };
}

note "test handle->DropIndex method";
{
    my ($status, $msg) = $handle->DropIndex( Table => 'Tickets', Name => 'Tickets1' );
    ok $status, $msg;

    my %indexes = $handle->Indexes;
    ok !grep $_ eq 'tickets1', @{ $indexes{'tickets'} };

    ($status, $msg) = $handle->DropIndex( Table => 'Tickets', Name => 'Tickets1' );
    ok !$status, $msg;
}

note "test handle->DropIndexIfExists method";
{
    my ($status, $msg) = $handle->DropIndexIfExists( Table => 'Tickets', Name => 'Tickets2' );
    ok $status, $msg;

    my %indexes = $handle->Indexes;
    ok !grep $_ eq 'tickets2', @{ $indexes{'tickets'} };

    ($status, $msg) = $handle->DropIndexIfExists( Table => 'Tickets', Name => 'Tickets2' );
    ok $status, $msg;
}

note "test handle->IndexInfo method";
{
    if ($db_type ne 'Oracle' && $db_type ne 'mysql') {
        my %res = $handle->IndexInfo( Table => 'Attachments', Name => 'Attachments1' );
        is_deeply(
            \%res,
            {
                Table => 'attachments', Name => 'attachments1',
                Unique => 0, Functional => 0,
                Columns => ['parent']
            }
        );
    } else {
        my %res = $handle->IndexInfo( Table => 'Attachments', Name => 'Attachments2' );
        is_deeply(
            \%res,
            {
                Table => 'attachments', Name => 'attachments2',
                Unique => 0, Functional => 0,
                Columns => ['transactionid']
            }
        );
    }

    my %res = $handle->IndexInfo( Table => 'GroupMembers', Name => 'GroupMembers1' );
    is_deeply(
        \%res,
        {
            Table => 'groupmembers', Name => 'groupmembers1',
            Unique => 1, Functional => 0,
            Columns => ['groupid', 'memberid']
        }
    );

    if ( $db_type eq 'Pg' || $db_type eq 'Oracle' ) {
        %res = $handle->IndexInfo( Table => 'Queues', Name => 'Queues1' );
        is_deeply(
            \%res,
            {
                Table => 'queues', Name => 'queues1',
                Unique => 1, Functional => 1,
                Columns => ['name'],
                CaseInsensitive => { name => 1 },
            }
        );
    }
}

note "test ->CreateIndex and ->IndexesThatBeginWith methods";
{
    {
        my ($name, $msg) = $handle->CreateIndex(
            Table => 'Users', Name => 'test_users1',
            Columns => ['Organization'],
        );
        ok $name, $msg;
    }
    {
        my ($name, $msg) = $handle->CreateIndex(
            Table => 'Users', Name => 'test_users2',
            Columns => ['Organization', 'Name'],
        );
        ok $name, $msg;
    }

    my @list = $handle->IndexesThatBeginWith( Table => 'Users', Columns => ['Organization'] );
    is_deeply([sort map $_->{Name}, @list], [qw(test_users1 test_users2)]);

    my ($status, $msg) = $handle->DropIndex( Table => 'Users', Name => 'test_users1' );
    ok $status, $msg;
    ($status, $msg) = $handle->DropIndex( Table => 'Users', Name => 'test_users2' );
    ok $status, $msg;
}

note "Test some cases sensitivity aspects";
{
    {
        my %res = $handle->IndexInfo( Table => 'groupmembers', Name => 'groupmembers1' );
        is_deeply(
            \%res,
            {
                Table => 'groupmembers', Name => 'groupmembers1',
                Unique => 1, Functional => 0,
                Columns => ['groupid', 'memberid']
            }
        );
    }

    {
        my ($status, $msg) = $handle->DropIndex( Table => 'groupmembers', Name => 'groupmembers1' );
        ok $status, $msg;

        my %indexes = $handle->Indexes;
        ok !grep $_ eq 'groupmembers1', @{ $indexes{'groupmembers'} };
    }

    {
        my ($name, $msg) = $handle->CreateIndex(
            Table => 'groupmembers', Name => 'groupmembers1',
            Unique => 1,
            Columns => ['groupid', 'memberid']
        );
        ok $name, $msg;

        my %indexes = $handle->Indexes;
        ok grep $_ eq 'groupmembers1', @{ $indexes{'groupmembers'} };
    }

    {
        my ($status, $msg) = $handle->DropIndexIfExists( Table => 'groupmembers', Name => 'groupmembers1' );
        ok $status, $msg;

        my %indexes = $handle->Indexes;
        ok !grep $_ eq 'groupmembers1', @{ $indexes{'groupmembers'} };
    }
}

done_testing();
