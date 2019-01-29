use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $agent) = RT::Test->started_ok;

my $url = $agent->rt_base_url;
diag "Running server at $url";

$agent->login('root' => 'password');
is( $agent->status, 200, "Fetched the page ok");
$agent->content_contains("Logout", "Found a logout link");

my ($ok, $msg);
my $ticket = RT::Ticket->new(RT->SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(
    Queue => 'General',
    Subject => "An Interesting Title",
);
ok($tv, "Ticket created");

my $cf = RT::CustomField->new(RT->SystemUser);
ok($cf, "RT::CustomField object initialized");
($ok, $msg) =  $cf->Create(
    Name        => 'My Custom Field',
    Queue       => '0',
    Description => 'A testing custom field',
    Type        => 'SelectSingle'
);
ok($ok, 'Global custom field created');
my $cf_id = $cf->Id;

#($ok, $msg) = $ticket->Load($tv);
#ok($ok, 'created a scrip') or diag "error: $msg";

$ticket->AddCustomFieldValue(Field => $cf->Id,  Value => '1');

diag "Create test scrip";
my $scrip = RT::Scrip->new(RT->SystemUser);
($ok, $msg) = $scrip->Create(
    Queue          => 'General',
    ScripAction    => 'User Defined',
    ScripCondition => 'User Defined',
    Template       => 'blank',
    CustomIsApplicableCode  => "return 1;",
    CustomPrepareCode       => "return 1;",
    CustomCommitCode        => "warn 'Commit should not run for PreviewScrips'; return 1;",
);
ok($ok, 'Scrip created');

$agent->get_ok( $url . "Ticket/Update.html?Action=Respond;id=$tv" );

diag "Confirm commit does not run for Preview Scrips";
$agent->post_ok( $url . "Helpers/PreviewScrips", {
    id                                               => $tv,
    "Object-RT::Ticket-$tv-CustomField-$cf_id-Value" => 'Test Value',
    UpdateType                                       => 'response',
    TxnRecipients                                    => 'root@localhost',
}, Content_Type => 'form-data' );
is( $agent->status, 200, "PreviewScrips returned 200");

done_testing();
