
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

diag "Columns as values in searches";
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

    ( $ret, $msg ) = $tickets->FromSQL('CF.foo = "CF.{bar}"');
    ok( $ret, 'Ran query with CF.foo = "CF.bar"' );
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

    ( $ret, $msg ) = $tickets->FromSQL('CF.{Beta Date} = Due');
    ok( $ret, 'Ran query with CF.{Beta Date} = Due' );
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

    ( $ret, $msg ) = $tickets->FromSQL('CF.{Beta Date} = Due');
    ok( $ret, 'Ran query with CF.{Beta Date} = Due' );
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

    ( $ret, $msg ) = $tickets->FromSQL('CF.{IPRange 1}.Content = "CF.{IPRange 2}.Content"');
    ok( $ret, 'Ran query with CF.{IPRange 1}.Content = "CF.{IPRange 2}.Content"' );
    $count = $tickets->Count();
    is( $count, 1, 'Found 1 ticket' );

    ( $ret, $msg ) = $tickets->FromSQL('CF.{IPRange 1} = CF.{IPRange 2}');
    ok( $ret, 'Ran query with CF.{IPRange 1} = CF.{IPRange 2}' );
    $count = $tickets->Count();
    TODO: {
        local $TODO
            = "It'll be great if we can automatically compare both Content and LargeContent for queries like CF.{IPRange 1} = CF.{IPRange 2}";
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

diag "Ticket role group member custom fields";
{
    my $cr = RT::CustomRole->new( RT->SystemUser );
    my ( $ret, $msg ) = $cr->Create(
        Name      => 'Engineer',
        MaxValues => 0,
    );
    ok( $ret, "Created custom role: $msg" );

    ( $ret, $msg ) = $cr->AddToObject( ObjectId => 'General' );
    ok( $ret, "Added CR to queue: $msg" );

    my $cf = RT::CustomField->new( RT->SystemUser );
    ( $ret, $msg ) = $cf->Create(
        Name       => 'manager',
        Type       => 'FreeformSingle',
        LookupType => RT::User->CustomFieldLookupType,
    );
    ok( $ret,                                                "Created user cf: $msg" );
    ok( $cf->AddToObject( RT::User->new( RT->SystemUser ) ), 'Applied user CF globally' );

    my $ticket  = RT::Test->create_ticket( Queue => 'General', Subject => 'test role member cfs' );
    my $admincc = $ticket->RoleGroup('AdminCc');

    my $alice = RT::Test->load_or_create_user( Name => 'alice' );
    ok( $alice->AddCustomFieldValue( Field => 'manager', Value => 'bob' ) );

    my $bob = RT::Test->load_or_create_user( Name => 'bob' );
    ok( $bob->AddCustomFieldValue( Field => 'manager', Value => 'root' ) );

    my $richard = RT::Test->load_or_create_user( Name => 'richard' );
    ok( $richard->AddCustomFieldValue( Field => 'manager', Value => 'alice' ) );

    my $tickets = RT::Tickets->new( RT->SystemUser );

    $tickets->FromSQL("Subject = 'test role member cfs' AND Owner.CustomField.{manager} = 'bob'");
    ok( !$tickets->Count, 'No tickets found' );

    $alice->PrincipalObj->GrantRight( Right => 'OwnTicket' );
    ( $ret, $msg ) = $ticket->SetOwner('alice');
    ok( $ret, $msg );

    $tickets->FromSQL("Subject = 'test role member cfs' AND Owner.CustomField.{manager} = 'bob'");
    is( $tickets->Count,     1,           'Found 1 ticket' );
    is( $tickets->First->id, $ticket->id, 'Found the ticket' );

    $tickets->FromSQL("Subject = 'test role member cfs' AND Requestor.CustomField.manager = 'alice'");
    ok( !$tickets->Count, 'No tickets found' );

    ( $ret, $msg ) = $ticket->RoleGroup('Requestor')->AddMember( $richard->Id );
    ok( $ret, $msg );

    $tickets->FromSQL("Subject = 'test role member cfs' AND Requestor.CustomField.manager = 'alice'");
    is( $tickets->Count,     1,           'Found 1 ticket' );
    is( $tickets->First->id, $ticket->id, 'Found the ticket' );

    $tickets->FromSQL("Subject = 'test role member cfs' AND CustomRole.{Engineer}.CustomField.{manager} = 'root'");
    ok( !$tickets->Count, 'No tickets found' );

    ( $ret, $msg ) = $ticket->RoleGroup( $cr->GroupType )->AddMember( $bob->Id );
    ok( $ret, $msg );

    $tickets->FromSQL("Subject = 'test role member cfs' AND CustomRole.{Engineer}.CustomField.{manager} = 'root'");
    is( $tickets->Count,     1,           'Found 1 ticket' );
    is( $tickets->First->id, $ticket->id, 'Found the ticket' );

    ok( $bob->AddCustomFieldValue( Field => 'manager', Value => 'nobody' ) );

    $tickets->FromSQL("Subject = 'test role member cfs' AND CustomRole.{Engineer}.CustomField.{manager} = 'root'");
    ok( !$tickets->Count, 'No tickets found' );

    $alice->PrincipalObj->GrantRight( Right => 'ShowTicket' );
    my $alice_current_user = RT::CurrentUser->new( RT->SystemUser );
    $alice_current_user->Load( $alice->Id );

    $tickets = RT::Tickets->new($alice_current_user);

    $tickets->FromSQL("Subject = 'test role member cfs' AND Owner.CustomField.{manager} = 'bob'");
    ok( !$tickets->Count, 'No tickets found' );

    $alice->PrincipalObj->GrantRight( Right => 'SeeCustomField', Object => $cf );
    $tickets->FromSQL("Subject = 'test role member cfs' AND Owner.CustomField.{manager} = 'bob'");
    is( $tickets->Count,     1,           'Found 1 ticket' );
    is( $tickets->First->id, $ticket->id, 'Found the ticket' );
}

done_testing;
