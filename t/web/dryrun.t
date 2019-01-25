use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;


{
    $agent->login('root' => 'password');
    # the field isn't named, so we have to click link 0
    is( $agent->status, 200, "Fetched the page ok");
    $agent->content_contains("Logout", "Found a logout link");
}
my ($ok, $msg);
my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(
    Queue => 'General',
    Subject => "An Interesting Title",
);
ok($tv, $tm);

my $cf = RT::CustomField->new(RT->SystemUser);
ok($cf, "Have a CustomField object");
($ok, $msg) =  $cf->Create(
    Name        => 'MyCF',
    Queue       => '0',
    Description => 'A Testing custom field',
    Type        => 'SelectSingle'
);
ok($ok, 'Global custom field correctly created');
my $cf_id = $cf->Id;

($ok, $msg) = $ticket->Load($tv);
ok($ok, 'created a scrip') or diag "error: $msg";

$ticket->AddCustomFieldValue(Field => $cf->Id,  Value => '1');
my $scrip = RT::Scrip->new(RT->SystemUser);
($ok, $msg) = $scrip->Create(
    Queue          => 'General',
    ScripAction    => 'User Defined',
    ScripCondition => 'User Defined',
    Template       => 'blank',
    CustomIsApplicableCode  => "return 1;",
    CustomPrepareCode       => "1;",
    CustomCommitCode        => "warn 'Fail test for warning'",
);
ok($ok, 'created a scrip') or diag "error: $msg";

$agent->get( $url."Ticket/Update.html?Action=Respond;id=$tv" );
$agent->post_ok( $url."Helpers/PreviewScrips", {
    id                                               => $tv,
    "Object-RT::Ticket-$tv-CustomField-$cf_id-Value" => 'Test Value',
    UpdateType                                       => 'response',
    TxnRecipients                                    => 'root@localhost',
}, Content_Type => 'form-data' );
is( $agent->status, 200, "Fetched the page ok");

done_testing();
