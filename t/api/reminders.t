
use strict;
use warnings;
use RT;
use RT::Test tests => 20;


{

# Create test queues
use_ok ('RT::Queue');

ok(my $testqueue = RT::Queue->new(RT->SystemUser), 'Instantiate RT::Queue');
ok($testqueue->Create( Name => 'reminders tests'), 'Create new queue: reminders tests');
isnt($testqueue->Id , 0, 'Success creating queue');

ok($testqueue->Create( Name => 'reminders tests 2'), 'Create new queue: reminders tests 2');
isnt($testqueue->Id , 0, 'Success creating queue');

# Create test ticket
use_ok('RT::Ticket');

my $u = RT::User->new(RT->SystemUser);
$u->Load("root");
ok ($u->Id, "Found the root user");
ok(my $t = RT::Ticket->new(RT->SystemUser), 'Instantiate RT::Ticket');
ok(my ($id, $msg) = $t->Create( Queue => $testqueue->Id,
               Subject => 'Testing',
               Owner => $u->Id
              ), 'Create sample ticket');
isnt($id , 0, 'Success creating ticket');

# Add reminder
my $due_obj = RT::Date->new( RT->SystemUser );
$due_obj->SetToNow;
ok(my ( $add_id, $add_msg, $txnid ) = $t->Reminders->Add(
    Subject => 'TestReminder',
    Owner   => 'root',
    Due     => $due_obj->ISO
    ), 'Add reminder');

# Check that the new Reminder is here
my $reminders = $t->Reminders->Collection;
ok($reminders, 'Loading reminders for this ticket');
my $found = 0;
while ( my $reminder = $reminders->Next ) {
    next unless $found == 0;
    $found = 1 if ( $reminder->Subject =~ m/TestReminder/ );
}

is($found, 1, 'Reminder successfully added');

# Change queue
ok (my ($move_val, $move_msg) = $t->SetQueue('reminders tests 2'), 'Moving ticket from queue "reminders tests" to "reminders tests 2"');

is ($t->QueueObj->Name, 'reminders tests 2', 'Ticket successfully moved');

# Check that the new reminder is still there and moved to the new queue
$reminders = $t->Reminders->Collection;
ok($reminders, 'Loading reminders for this ticket');
$found = 0;
my $ok_queue = 0;
while ( my $reminder = $reminders->Next ) {
    next unless $found == 0;
    if ( $reminder->Subject =~ m/TestReminder/ ) {
        $found = 1;
        $ok_queue = 1 if ( $reminder->QueueObj->Name eq 'reminders tests 2' );
    }
}
is($found, 1, 'Reminder successfully added');

is($ok_queue, 1, 'Reminder automatically moved to new queue');

# Resolve reminder
my $r_resolved = 0;
while ( my $reminder = $reminders->Next ) {
    if ( $reminder->Subject =~ m/TestReminder/ ) {
        if ( $reminder->Status ne 'resolved' ) {
            $t->Reminders->Resolve($reminder);
            $r_resolved = 1 if ( $reminder->Status eq 'resolved' );
        }
    }
}

is($r_resolved, 1, 'Reminder resolved');

}

