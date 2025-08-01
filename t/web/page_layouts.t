use strict;
use warnings;

use RT::Test tests => undef;
use RT::Interface::Web;

# Create two queues
my $queue1 = RT::Test->load_or_create_queue(Name => 'TestQueue1');
my $queue2 = RT::Test->load_or_create_queue(Name => 'TestQueue2');

# Create a custom field applied only to Queue1
my $cf = RT::CustomField->new(RT->SystemUser);
my ($cf_id, $msg) = $cf->Create(
    Name       => 'State',
    Type       => 'Select',
    LookupType => RT::Ticket->CustomFieldLookupType,
);
ok($cf_id, "Created custom field: $msg");

$cf->AddValue(Name => 'New York');
$cf->AddValue(Name => 'Massachusetts');
$cf->AddValue(Name => 'Pennsylvania');

# Apply CF only to Queue1
my ($status, $apply_msg) = $cf->AddToObject($queue1);
ok($status, "Applied CF to Queue1: $apply_msg");

my $mapping = RT->Config->Get('PageLayoutMapping') || {};
push @{ $mapping->{'RT::Ticket'}{'Display'} },
    {
        Type   => 'CustomField.{State}',
        Layout => {
            'New York'   => 'NY Layout',
        }
    };

my ($ret, $update_msg) = HTML::Mason::Commands::UpdateConfig(
    Name => 'PageLayoutMapping',
    Value => $mapping,
    CurrentUser => RT->SystemUser
);
ok($ret, "Updated PageLayoutMapping config");

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

{
    my $ticket1 = RT::Test->create_ticket(
        Queue   => $queue1->Name,
        Subject => 'Test ticket in Queue1',
    );
    $m->goto_ticket($ticket1->Id);
}

{
    my $ticket2 = RT::Test->create_ticket(
        Queue   => $queue2->Name,
        Subject => 'Test ticket in Queue2',
    );
    $m->goto_ticket($ticket2->Id);
}

done_testing;
