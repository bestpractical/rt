
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
    qr/Wrong query, no such column 'yesterday' in 'LastUpdated < yesterday'/;

    ok( !$ret, 'Invalid query' );
    like(
        $msg,
        qr/Wrong query, no such column 'yesterday' in 'LastUpdated < yesterday'/,
        'Invalid query message'
    );
}

{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ok $ticket->Load(1), "Loaded test ticket 1";
    my $date = RT::Date->new(RT->SystemUser);
    $date->SetToNow();
    $date->AddDays(1);

    ok $ticket->SetDue( $date->ISO ), "Set Due to tomorrow";
    my $tickets = RT::Tickets->new( RT->SystemUser );
    my ( $ret, $msg ) = $tickets->FromSQL("LastUpdated < Due");

    ok( $ret, 'Ran query with Due as searched value' );
    my $count = $tickets->Count();
    ok $count == 1, "Found one ticket";

    my $cf_foo = RT::Test->load_or_create_custom_field( Name => 'foo', Type => 'FreeformSingle', Queue => 0 );
    my $cf_bar = RT::Test->load_or_create_custom_field( Name => 'bar', Type => 'FreeformSingle', Queue => 0 );
    ok( $ticket->AddCustomFieldValue( Field => $cf_foo, Value => 'this rocks!' ) );

    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = CF.bar');
    ok( $ret, 'Ran query with CF.foo = CF.bar' );
    $count = $tickets->Count();
    is( $count, 0, 'Found 0 tickets' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_bar, Value => 'this does not rock' ) );

    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = CF.bar');
    ok( $ret, 'Ran query with CF.foo = CF.bar' );
    $count = $tickets->Count();
    is( $count, 0, 'Found 0 tickets' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_bar, Value => 'this rocks!' ) );

    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = CF.bar');
    ok( $ret, 'Ran query with CF.foo = CF.bar' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = Owner');
    ok( $ret, 'Ran query with CF.foo = Owner' );
    $count = $tickets->Count();
    is( $count, 0, 'Found 0 tickets' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_foo, Value => RT->Nobody->id ) );
    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = Owner');
    ok( $ret, 'Ran query with CF.foo = Owner' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    my $cf_beta = RT::Test->load_or_create_custom_field( Name => 'Beta Date', Type => 'DateTime', Queue => 0 );
    ( $ret, $msg ) = $tickets->FromSQL('Due = CF.{Beta Date}');
    ok( $ret, 'Ran query with Due = CF.{Beta Date}' );
    $count = $tickets->Count();
    is( $count, 0, 'Found 0 tickets' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_foo, Value => '1900' ) );
    for my $operator ( '=', 'LIKE' ) {
        ( $ret, $msg ) = $tickets->FromSQL("CF.foo $operator 1900");
        ok( $ret, "Ran query with CF.foo $operator 1900" );
        $count = $tickets->Count();
        is( $count, 1, 'Found 1 ticket' );
    }

    ok( $ticket->AddCustomFieldValue( Field => $cf_beta, Value => $date->ISO( Timezone => 'user' ) ) );
    ( $ret, $msg ) = $tickets->FromSQL('Due = CF.{Beta Date}');
    ok( $ret, 'Ran query with Due = CF.{Beta Date}' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_beta, Value => $date->ISO( Timezone => 'user' ) ) );
    ( $ret, $msg ) = $tickets->FromSQL('Due = CF.{Beta Date}.Content');
    ok( $ret, 'Ran query with Due = CF.{Beta Date}.Content' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_beta, Value => $date->ISO( Timezone => 'user' ) ) );
    ( $ret, $msg ) = $tickets->FromSQL('CF.{Beta Date} = Due');
    ok( $ret, 'Ran query with CF.{Beta Date} = Due' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    my $cf_ip1  = RT::Test->load_or_create_custom_field( Name => 'IPRange 1', Type => 'IPAddressRangeSingle', Queue => 0 );
    my $cf_ip2  = RT::Test->load_or_create_custom_field( Name => 'IPRange 2', Type => 'IPAddressRangeSingle', Queue => 0 );

    ( $ret, $msg ) = $tickets->FromSQL('CF.{IPRange 1} = CF.{IPRange 2}');
    ok( $ret, 'Ran query with CF.{IPRange 1} = CF.{IPRange 2}' );
    $count = $tickets->Count();
    is( $count, 0, 'Found 0 tickets' );

    ok( $ticket->AddCustomFieldValue( Field => $cf_ip1, Value => '192.168.1.1-192.168.1.5' ));
    ok( $ticket->AddCustomFieldValue( Field => $cf_ip2, Value => '192.168.1.1-192.168.1.6' ));

    ( $ret, $msg ) = $tickets->FromSQL('CF.{IPRange 1}.Content = CF.{IPRange 2}.Content');
    ok( $ret, 'Ran query with CF.{IPRange 1}.Content = CF.{IPRange 2}.Content' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    ( $ret, $msg ) = $tickets->FromSQL('CF.{IPRange 1} = CF.{IPRange 2}');
    ok( $ret, 'Ran query with CF.{IPRange 1} = CF.{IPRange 2}' );
    $count = $tickets->Count();
    TODO: {
        local $TODO
            = "It'll be great if we can automatially compare both Content and LargeContent for queries like CF.{IPRange 1} = CF.{IPRange 2}";
        is( $count, 0, 'Found 0 tickets' );
    }

    ok( $ticket->AddCustomFieldValue( Field => $cf_ip2, Value => '192.168.1.1-192.168.1.5' ) );
    ( $ret, $msg )
        = $tickets->FromSQL(
        'CF.{IPRange 1}.Content = CF.{IPRange 2}.Content AND CF.{IPRange 1}.LargeContent = CF.{IPRange 2}.LargeContent'
        );
    ok( $ret,
        'Ran query with CF.{IPRange 1}.Content = CF.{IPRange 2}.Content AND CF.{IPRange 1}.LargeContent = CF.{IPRange 2}.LargeContent'
      );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );
}

done_testing;
