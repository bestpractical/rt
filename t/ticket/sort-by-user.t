
use RT::Test nodata => 1, tests => undef;

use strict;
use warnings;

use RT::Tickets;
use RT::Queue;
use RT::CustomField;

#########################################################
# Test sorting by Owner, Creator and LastUpdatedBy
# we sort by user name
#########################################################

diag "Create a queue to test with.";
my $queue_name = "OwnerSortQueue$$";
my $queue;
{
    $queue = RT::Queue->new( RT->SystemUser );
    my ($ret, $msg) = $queue->Create(
        Name => $queue_name,
        Description => 'queue for custom field sort testing'
    );
    ok($ret, "$queue test queue creation. $msg");
}

my @uids;
my @users;
# create them in reverse order to avoid false positives
foreach my $u (qw(Z A)) {
    my $name = $u ."-user-to-test-ordering-$$";
    my $user = RT::User->new( RT->SystemUser );
    my ($uid) = $user->Create(
        Name => $name,
        EmailAddress => $name . '@localhost',
        Privileged => 1,
    );
    ok $uid, "created user #$uid";

    my ($status, $msg) = $user->PrincipalObj->GrantRight( Right => 'OwnTicket', Object => $queue );
    ok $status, "granted right";
    ($status, $msg) = $user->PrincipalObj->GrantRight( Right => 'CreateTicket', Object => $queue );
    ok $status, "granted right";

    push @users, $user;
    push @uids, $user->id;
}

my (@data, @tickets, @test) = (0, ());


sub run_tests {
    my $query_prefix = join ' OR ', map 'id = '. $_->id, @tickets;
    foreach my $test ( @test ) {
        my $query = join " AND ", map "( $_ )", grep defined && length,
            $query_prefix, $test->{'Query'};

        foreach my $order (qw(ASC DESC)) {
            my $error = 0;
            my $tix = RT::Tickets->new( RT->SystemUser );
            $tix->FromSQL( $query );
            $tix->OrderBy( FIELD => $test->{'Order'}, ORDER => $order );

            ok($tix->Count, "found ticket(s)")
                or $error = 1;

            my ($order_ok, $last) = (1, $order eq 'ASC'? '-': 'zzzzzz');
            while ( my $t = $tix->Next ) {
                my $tmp;
                if ( $order eq 'ASC' ) {
                    $tmp = ((split( /,/, $last))[0] cmp (split( /,/, $t->Subject))[0]);
                } else {
                    $tmp = -((split( /,/, $last))[-1] cmp (split( /,/, $t->Subject))[-1]);
                }
                if ( $tmp > 0 ) {
                    $order_ok = 0; last;
                }
                $last = $t->Subject;
            }

            ok( $order_ok, "$order order of tickets is good" )
                or $error = 1;

            if ( $error ) {
                diag "Wrong SQL query:". $tix->BuildSelectQuery;
                $tix->GotoFirstItem;
                while ( my $t = $tix->Next ) {
                    diag sprintf "%02d - %s", $t->id, $t->Subject;
                }
            }
        }
    }
}

@data = (
    { Subject => 'Nobody' },
    { Subject => 'Z', Owner => $uids[0] },
    { Subject => 'A', Owner => $uids[1] },
);

@tickets = RT::Test->create_tickets( { Queue => $queue->id }, @data );

@test = (
    { Order => "Owner" },
);
run_tests();

@data = (
    { Subject => 'RT' },
    { Subject => 'Z', Creator => $uids[0] },
    { Subject => 'A', Creator => $uids[1] },
);
@tickets = RT::Test->create_tickets( { Queue => $queue->id }, @data );
@test = (
    { Order => "Creator" },
);
run_tests();

@data = (
    { Subject => 'Nobody' },
    { Subject => 'Z', LastUpdatedBy => $uids[0] },
    { Subject => 'A', LastUpdatedBy => $uids[1] },
);
@tickets = RT::Test->create_tickets( { Queue => $queue->id }, @data );
@test = (
    { Order => "LastUpdatedBy" },
);
run_tests();

my $cf = RT::Test->load_or_create_custom_field(
    Name  => 'Department',
    Type  => 'FreeformSingle',
    LookupType => RT::User->CustomFieldLookupType,
);
my ( $ret, $msg ) = $cf->AddToObject( RT::User->new( RT->SystemUser ) );
ok( $ret, "Added CF globally: $msg" );

( $ret, $msg ) = $users[0]->AddCustomFieldValue( Field => $cf, Value => 'Bar' );
ok( $ret, "Added CF value 'Foo' to users[0]: $msg" );

( $ret, $msg ) = $users[1]->AddCustomFieldValue( Field => $cf, Value => 'Foo' );
ok( $ret, "Added CF value 'Bar' to users[1]: $msg" );

# In Pg/Oracle, null values sort as if larger than any non-null value by default
my $null_subject = RT->Config->Get('DatabaseType') =~ /Pg|Oracle/ ? 'zzz' : '-';

@data = (
    { Subject => $null_subject },
    { Subject => 'Z', Owner => $uids[1] },
    { Subject => 'A', Owner => $uids[0] },
);
@tickets = RT::Test->create_tickets( { Queue => $queue->id }, @data );
@test = (
    { Order => "Owner.CustomField.{Department}" },
);
run_tests();

my $cr = RT::CustomRole->new( RT->SystemUser );
( $ret, $msg ) = $cr->Create(
    Name      => 'Engineer',
    MaxValues => 0,
);
ok( $ret, "Created custom role: $msg" );

( $ret, $msg ) = $cr->AddToObject( ObjectId => $queue->id );
ok( $ret, "Added CR to queue: $msg" );

@data = (
    { Subject => $null_subject },
    { Subject => 'Z', $cr->GroupType => $uids[1] },
    { Subject => 'A', $cr->GroupType => $uids[0] },
);
@tickets = RT::Test->create_tickets( { Queue => $queue->id }, @data );
@test = ( { Order => "CustomRole.{Engineer}.CustomField.{Department}" }, );
run_tests();

@tickets = ();

done_testing;
