
use strict;
use warnings;

use RT::Test tests => undef;

RT->Config->Set( UserTicketDataResultFormat =>
        "'__id__', '__Subject__', '__Status__', '__QueueName__', '__Owner__', '__Priority__', '__Requestors__'"
);

my ( $baseurl, $agent ) = RT::Test->started_ok;
my $url = $agent->rt_base_url;

# Login
$agent->login( 'root' => 'password' );

{
    my $root = RT::Test->load_or_create_user( Name => 'root' );
    ok $root && $root->id;

# We want transactions attached to our user, so not using test method for ticket create
    my $ticket = RT::Ticket->new($root);
    $ticket->Create(
        Subject   => 'Test',
        Requestor => 'root',
        Queue     => 'General'
    );
    my $id = $ticket->id;
    ok $id;

    $ticket->Comment( Content => 'Test - Comment' );
    $ticket->Correspond( Content => 'Test - Reply' );

    my @dates;
    my $trans = $ticket->Transactions;

    while ( my $tran = $trans->Next ) {
        if ( $tran->Type =~ /Create|Comment|Correspond/ ) {
            push @dates, $tran->CreatedObj->AsString;
        }
    }
    my ( $date_created, $date_commented, $date_correspondence ) = @dates;

    # Make sure we have the expected amount of transactions
    is scalar @dates, 3;

    # TSV file for user record information
    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $root->id );
    $agent->follow_link_ok( { text => 'Download User Data' } );

    my $user_info_tsv = <<EOF;
id\tName\tEmailAddress\tRealName\tNickName\tOrganization\tHomePhone\tWorkPhone\tMobilePhone\tPagerPhone\tAddress1\tAddress2\tCity\tState\tZip\tCountry\tGecos\tLang\tFreeFormContactInfo
14\troot\troot\@localhost\tEnoch Root\t\t\t\t\t\t\t\t\t\t\t\t\troot\t\t
EOF

    is $agent->content, $user_info_tsv,
        "User record information downloaded correctly";

    # TSV file for Transactions
    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $root->id );
    $agent->follow_link_ok( { text => 'Download User Transaction Data' } );

    my $transaction_info_tsv = <<EOF;
ObjectId\tid\tCreated\tDescription\tOldValue\tNewValue\tContent
1\t30\t$date_created\tTicket created\t\t\tThis transaction appears to have no content
1\t32\t$date_commented\tComments added\t\t\tTest - Comment
1\t33\t$date_correspondence\tCorrespondence added\t\t\tTest - Reply
EOF

    is $agent->content, $transaction_info_tsv,
        "User transaction information downloaded correctly";

    # TSV file for user's Tickets
    $agent->get_ok( $url . "Admin/Users/Modify.html?id=" . $root->id );
    $agent->follow_link_ok( { text => 'Download User Tickets' } );

    my $ticket_info_tsv = <<EOF;
id\tSubject\tStatus\tQueueName\tOwner\tPriority\tRequestors
1\tTest\topen\tGeneral\tNobody in particular\t0\troot (Enoch Root)
EOF

    is $agent->content, $ticket_info_tsv, "User tickets downloaded correctly";
}

done_testing();
