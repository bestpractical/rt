
use strict;
use warnings;
use RT;
use RT::Test tests => undef;
use Test::Warn;

{

ok (require RT::Tickets);
ok( my $testtickets = RT::Tickets->new( RT->SystemUser ) );
ok( $testtickets->LimitStatus( VALUE => 'deleted' ) );
# Should be zero until 'allow_deleted_search'
is( $testtickets->Count , 0 );


}

{

# Test to make sure that you can search for tickets by requestor address and
# by requestor name.

my ($id,$msg);
my $u1 = RT::User->new(RT->SystemUser);
($id, $msg) = $u1->Create( Name => 'RequestorTestOne', EmailAddress => 'rqtest1@example.com');
ok ($id,$msg);
my $u2 = RT::User->new(RT->SystemUser);
($id, $msg) = $u2->Create( Name => 'RequestorTestTwo', EmailAddress => 'rqtest2@example.com');
ok ($id,$msg);

my $t1 = RT::Ticket->new(RT->SystemUser);
my ($trans);
($id,$trans,$msg) =$t1->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u1->EmailAddress]);
ok ($id, $msg);

my $t2 = RT::Ticket->new(RT->SystemUser);
($id,$trans,$msg) =$t2->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress]);
ok ($id, $msg);


my $t3 = RT::Ticket->new(RT->SystemUser);
($id,$trans,$msg) =$t3->Create (Queue => 'general', Subject => 'Requestor test one', Requestor => [$u2->EmailAddress, $u1->EmailAddress]);
ok ($id, $msg);


my $tix1 = RT::Tickets->new(RT->SystemUser);
$tix1->FromSQL('Requestor.EmailAddress LIKE "rqtest1" OR Requestor.EmailAddress LIKE "rqtest2"');

is ($tix1->Count, 3);

my $tix2 = RT::Tickets->new(RT->SystemUser);
$tix2->FromSQL('Requestor.Name LIKE "TestOne" OR Requestor.Name LIKE "TestTwo"');

is ($tix2->Count, 3);


my $tix3 = RT::Tickets->new(RT->SystemUser);
$tix3->FromSQL('Requestor.EmailAddress LIKE "rqtest1"');

is ($tix3->Count, 2);

my $tix4 = RT::Tickets->new(RT->SystemUser);
$tix4->FromSQL('Requestor.Name LIKE "TestOne" ');

is ($tix4->Count, 2);

# Searching for tickets that have two requestors isn't supported
# There's no way to differentiate "one requestor name that matches foo and bar"
# and "two requestors, one matching foo and one matching bar"

# my $tix5 = RT::Tickets->new(RT->SystemUser);
# $tix5->FromSQL('Requestor.Name LIKE "TestOne" AND Requestor.Name LIKE "TestTwo"');
# 
# is ($tix5->Count, 1);
# 
# my $tix6 = RT::Tickets->new(RT->SystemUser);
# $tix6->FromSQL('Requestor.EmailAddress LIKE "rqtest1" AND Requestor.EmailAddress LIKE "rqtest2"');
# 
# is ($tix6->Count, 1);



}

{

my $t1 = RT::Ticket->new(RT->SystemUser);
$t1->Create(Queue => 'general', Subject => "LimitWatchers test", Requestors => \['requestor1@example.com']);


}

{

# We assume that we've got some tickets hanging around from before.
ok( my $unlimittickets = RT::Tickets->new( RT->SystemUser ) );
ok( $unlimittickets->UnLimit );
ok( $unlimittickets->Count > 0, "UnLimited tickets object should return tickets" );


}


{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => 0 );
    my $count = $tickets->Count();
    ok $count > 1, "found more than one ticket";
    undef $count;

    $tickets->Limit( FIELD => 'id', OPERATOR => '=', VALUE => 1, ENTRYAGGREGATOR => 'none' );
    $count = $tickets->Count();
    ok $count == 1, "found one ticket";
}

{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    my ($ret, $msg) = $tickets->FromSQL("Resolved IS NULL");
    ok $ret, "Ran query with IS NULL: $msg";
    my $count = $tickets->Count();
    ok $count > 1, "Found more than one ticket";
    undef $count;
}

{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ok $ticket->Load(1), "Loaded test ticket 1";
    ok $ticket->SetStatus('resolved'), "Set to resolved";

    my $tickets = RT::Tickets->new( RT->SystemUser );
    my ($ret, $msg) = $tickets->FromSQL("Resolved IS NOT NULL");
    ok $ret, "Ran query with IS NOT NULL: $msg";
    my $count = $tickets->Count();
    ok $count == 1, "Found one ticket";
    undef $count;
}

{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->LimitDate( FIELD => "Resolved", OPERATOR => "IS",     VALUE => "NULL" );
    $tickets->LimitDate( FIELD => "Resolved", OPERATOR => "IS NOT", VALUE => "NULL" );
    my $count = $tickets->Count();
    ok $count > 1, "Found more than one ticket";
    undef $count;
}

{
    my $tickets = RT::Tickets->new( RT->SystemUser );
    my ( $ret, $msg );
    warning_like {
        ( $ret, $msg ) = $tickets->FromSQL( "LastUpdated < yesterday" );
    }
    qr/Couldn't parse query: Wrong query, expecting a VALUE in 'LastUpdated < >yesterday<--here'/;

    ok( !$ret, 'Invalid query' );
    like(
        $msg,
        qr/Wrong query, expecting a VALUE in 'LastUpdated < >yesterday<--here'/,
        'Invalid query message'
    );
}

diag "Ticket role group members";
{
    my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket role group' );
    my $admincc = $ticket->RoleGroup('AdminCc');

    my $delegates = RT::Test->load_or_create_group('delegates');
    my $core      = RT::Test->load_or_create_group('core team');
    my $alice     = RT::Test->load_or_create_user( Name => 'alice' );
    my $bob       = RT::Test->load_or_create_user( Name => 'bob' );
    ok( $delegates->AddMember( $core->PrincipalId ), 'Add core team to delegates' );
    ok( $delegates->AddMember( $bob->PrincipalId ),  'Add bob to delegates' );
    ok( $core->AddMember( $alice->PrincipalId ),     'Add alice to core team' );

    for my $name ( 'alice', 'bob' ) {
        my $tickets = RT::Tickets->new( RT->SystemUser );
        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name = '$name'");
        ok( !$tickets->Count, 'No tickets found' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name != '$name'");
        is( $tickets->Count,     1,           'Found 1 ticket' );
        is( $tickets->First->id, $ticket->id, 'Found the ticket' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name LIKE '$name'");
        ok( !$tickets->Count, 'No tickets found' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name NOT LIKE '$name'");
        is( $tickets->Count,     1,           'Found 1 ticket' );
        is( $tickets->First->id, $ticket->id, 'Found the ticket' );
    }

    ok( $admincc->AddMember( $delegates->PrincipalId ), 'Add delegates to AdminCc' );

    for my $name ( 'alice', 'bob' ) {
        my $tickets = RT::Tickets->new( RT->SystemUser );
        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name = '$name'");
        is( $tickets->Count,     1,           'Found 1 ticket' );
        is( $tickets->First->id, $ticket->id, 'Found the ticket' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name != '$name'");
        ok( !$tickets->Count, 'No tickets found' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name LIKE '$name'");
        is( $tickets->Count,     1,           'Found 1 ticket' );
        is( $tickets->First->id, $ticket->id, 'Found the ticket' );

        $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name NOT LIKE '$name'");
        ok( !$tickets->Count, 'No tickets found' );
    }

    my $abc = RT::Test->load_or_create_user( Name => 'abc' ); # so there are multiple users to search
    my $abc_ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test ticket role group' );
    ok( $abc_ticket->RoleGroup('AdminCc')->AddMember( $abc->PrincipalId ), 'Add abc to AdminCc' );

    my $tickets = RT::Tickets->new( RT->SystemUser );
    $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name LIKE 'a'");
    is( $tickets->Count,     2,           'Found 2 ticket' );

    $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCc.Name NOT LIKE 'a'");
    TODO: {
        local $TODO = <<EOF;
Searching NOT LIKE with multiple users is not the opposite of "LIKE", e.g.

    "alice", "bob" are AdminCcs of ticket 1, abc is AdminCc of ticket 2:
    "AdminCc.Name LIKE 'a'" returns tickets 1 and 2.
    "AdminCc.Name NOT LIKE 'a'" returns ticket 1 because it has AdminCc "bob" which doesn't match "a".

EOF
        ok( !$tickets->Count, 'No tickets found' );
    }
    if ( $tickets->Count ) {
        is( $tickets->Count,     1,           'Found 1 ticket' );
        is( $tickets->First->id, $ticket->id, 'Found the ticket' );
    }

    $tickets->FromSQL("Subject = 'test ticket role group' AND AdminCcGroup = 'delegates'");
    is( $tickets->Count,     1,           'Found 1 ticket' );
    is( $tickets->First->id, $ticket->id, 'Found the ticket' );
}

done_testing;
