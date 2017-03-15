use strict;
use warnings;

use RT::Test tests => undef;
use RT::Ticket;

my $general = RT::Test->load_or_create_queue(Name => 'General');
ok $general && $general->id, 'loaded or created queue';

my $test_queue1 = RT::Test->load_or_create_queue(Name => 'Test Queue 1');
ok $test_queue1 && $test_queue1->id, 'created Test Queue 1';

my $test_queue2 = RT::Test->load_or_create_queue(Name => 'Test Queue 2');
ok $test_queue2 && $test_queue2->id, 'created Test Queue 2';

my @tickets = create_tickets(
    # 3 tickets in General
    { Queue => $general, Subject => 'new general', Status => 'new' },
    { Queue => $general, Subject => 'open general 1', Status => 'open' },
    { Queue => $general, Subject => 'open general 2', Status => 'open' },
    # 2 tickets in Test Queue 1
    { Queue => $test_queue1, Subject => 'new test queue 1', Status => 'new' },
    { Queue => $test_queue1, Subject => 'open tests queue 1', Status => 'open' },
    # 1 tickets in Test Queue 2
    { Queue => $test_queue2, Subject => 'new test queue 2', Status => 'new' },
);

my $test_cf1 = RT::CustomField->new(RT->SystemUser);
my ($cf1_id,$msg1) = $test_cf1->Create(ObjectId => 0,  Name => 'Test Field 1', Type => 'Freeform',  MaxValues => 1, LookupType => 'RT::Queue', Description => 'First queue test field');
ok $cf1_id, "Created custom field 1 $msg1";

my $test_cf2 = RT::CustomField->new(RT->SystemUser);
my ($cf2_id,$msg2) = $test_cf2->Create(ObjectId => 0, Name => 'Test Field 2', Type => 'Freeform', MaxValues => 1,  LookupType => 'RT::Queue', Description => 'Second queue test field');
ok $cf2_id, "Created custom field 2 $msg2";

my ($value1_id,$msg3) = $test_cf1->AddValueForObject(Object => $general, Content => 'Test A');
ok $value1_id, "Create Custom Field Value 1";
my ($value2_id,$msg4) = $test_cf1->AddValueForObject(Object => $test_queue1, Content => 'Test A');
ok $value2_id, "Create Custom Field Value 2";
my ($value3_id,$msg5) = $test_cf2->AddValueForObject(Object => $test_queue2, Content => 'Test B');
ok $value3_id, "Create Custom Field Value 3";

use_ok 'RT::Report::Tickets';

diag "Test A search";
{
    my $report = RT::Report::Tickets->new(RT->SystemUser);
    my %columns = $report->SetupGroupings(
        Query => "'QueueCF.{Test Field 1}' = 'Test A'",
        GroupBy => ['Status'],
        Function => ['COUNT'],
    );
    $report->SortEntries;
    my %table = $report->FormatTable(%columns);
    is $table{tbody}[0]{cells}[0]{value},'new', "Test A new tickets";
    is $table{tbody}[0]{cells}[1]{value},2, "Test A 2 new tickets";
    is $table{tbody}[1]{cells}[0]{value},'open', "Test A open tickets";
    is $table{tbody}[1]{cells}[1]{value},3, "Test A 3 open tickets";

}

diag "Test B search";
{
    my $report = RT::Report::Tickets->new(RT->SystemUser);
    my %columns = $report->SetupGroupings(
        Query => "'QueueCF.{Test Field 2}' = 'Test B'",
        GroupBy => ['Status'],
        Function => ['COUNT'],
    );
    $report->SortEntries;
    my %table = $report->FormatTable(%columns);
    is $table{tbody}[0]{cells}[0]{value},'new', "Test B new tickets";
    is $table{tbody}[0]{cells}[1]{value},1, "Test B 1 new tickets";
}

done_testing;

sub create_tickets {
    my (@tix) = @_;
    my @res = ();
    for (@tix) {
        my $t = RT::Ticket->new($RT::SystemUser);
        my ($id, undef, $msg) = $t->Create(Queue => $_->{Queue}->id, Subject => $_->{Subject}, Status => $_->{Status});
        ok($id, "ticket created" ) or diag("error: $msg");
        is $t->Status, $_->{'Status'}, 'correct status';
        push @res, $t;
    }
    return @res;
}

