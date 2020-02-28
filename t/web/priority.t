use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'Log in' );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );

diag "Default PriorityAsString";

$m->goto_create_ticket( $queue->Id );
my $form = $m->form_name('TicketCreate');

for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'option', "$field input is a select" );
    is_deeply( [ $priority_input->possible_values ], [ '', 0, 50, 100 ], "$field options" );
    is( $form->value($field), '', "$field default value" );
}

$m->submit_form_ok( { fields => { Subject => 'Test PriorityAsString', InitialPriority => 50 } }, 'Create ticket' );
$m->text_like( qr{Priority:\s*Medium/Low}, 'Priority/FinalPriority on display' );

$m->follow_link_ok( { text => 'Basics' } );
$form = $m->form_name('TicketModify');

for my $field (qw/Priority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'option', "$field input is a select" );
    is_deeply( [ $priority_input->possible_values ], [ 0, 50, 100 ], "$field options" );
    is( $form->value($field), $field eq 'Priority' ? 50 : 0, "$field default value" );
}

$m->submit_form_ok( { fields => { Priority => 100, FinalPriority => 100 } }, 'Update Priority' );
$m->text_contains( qq{Priority changed from 'Medium' to 'High'},   'Priority is updated' );
$m->text_contains( qq{FinalPriority changed from 'Low' to 'High'}, 'FinalPriority is updated' );

diag "Disable PriorityAsString";

my $config = RT::Configuration->new( RT->SystemUser );
my ( $ret, $msg ) = $config->Create( Name => 'EnablePriorityAsString', Content => 0 );
ok( $ret, 'Updated config' );

$m->goto_create_ticket( $queue->Id );
$form = $m->form_name('TicketCreate');
for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'text', "$field input is a text" );
    is( $form->value($field),  '',     "$field default value" );
}

$config->Load('EnablePriorityAsString');
( $ret, $msg ) = $config->SetContent(1);
ok( $ret, 'Updated config' );

diag "Set PriorityAsString config of General to a hashref";

# config cache refreshes at most once in one second, so wait a bit.
sleep 1;

$config = RT::Configuration->new( RT->SystemUser );
( $ret, $msg ) = $config->Create(
    Name    => 'PriorityAsString',
    Content => {
        Default => { Low     => 0, Medium => 50, High   => 100 },
        General => { VeryLow => 0, Low    => 20, Medium => 50, High => 100, VeryHigh => 200 },
    },
);
ok( $ret, 'Updated config' );

$m->goto_create_ticket( $queue->Id );
$form = $m->form_name('TicketCreate');
for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'option', "$field input is a select" );
    is_deeply( [ $priority_input->possible_values ], [ '', 0, 20, 50, 100, 200 ], "$field options" );
    is( $form->value($field), '', "$field default value" );
}

diag "Disable PriorityAsString for General";

sleep 1;
( $ret, $msg ) = $config->SetContent(
    {   Default => { Low => 0, Medium => 50, High => 100 },
        General => 0,
    }
);
ok( $ret, 'Updated config' );
$m->goto_create_ticket( $queue->Id );
$form = $m->form_name('TicketCreate');
for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'text', "$field input is a text" );
    is( $form->value($field),  '',     "$field default value" );
}

diag "Set PriorityAsString config of General to an arrayref";

sleep 1;
( $ret, $msg ) = $config->SetContent(
    {   Default => { Low    => 0,  Medium  => 50, High => 100 },
        General => [ Medium => 50, VeryLow => 0,  Low  => 20, High => 100, VeryHigh => 200 ],
    }
);
ok( $ret, 'Updated config' );

$m->goto_create_ticket( $queue->Id );
$form = $m->form_name('TicketCreate');
for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'option', "$field input is a select" );
    is_deeply( [ $priority_input->possible_values ], [ '', 50, 0, 20, 100, 200 ], "$field options" );
    is( $form->value($field), '', "$field default value" );
}

diag "Queue default values";

$m->get_ok('/Admin/Queues/DefaultValues.html?id=1');
$form = $m->form_name('ModifyDefaultValues');
for my $field (qw/InitialPriority FinalPriority/) {
    my $priority_input = $form->find_input($field);
    is( $priority_input->type, 'option', 'Priority input is a select' );
    is_deeply( [ $priority_input->possible_values ], [ '', 50, 0, 20, 100, 200 ], 'Priority options' );
}
$m->submit_form_ok( { fields => { InitialPriority => 50, FinalPriority => 100 }, button => 'Update' },
    'Update default values' );
$m->text_contains( 'Default value of InitialPriority changed from (no value) to Medium', 'InitialPriority is updated' );
$m->text_contains( 'Default value of FinalPriority changed from (no value) to High',     'FinalPriority is updated' );

$m->goto_create_ticket( $queue->Id );
$form = $m->form_name('TicketCreate');
is( $form->value('InitialPriority'), 50,  'InitialPriority default value' );
is( $form->value('FinalPriority'),   100, 'FinalPriority default value' );

diag "Search builder";

$m->follow_link_ok( { text => 'Tickets' }, 'Ticket search builder' );
$form = $m->form_name('BuildQuery');
my $priority_input = $form->find_input('ValueOfPriority');
is( $priority_input->type, 'option', 'ValueOfPriority input is a select' );
is_deeply(
    [ $priority_input->possible_values ],
    [ '', 0, 50, 100, 50, 0, 20, 100, 200 ],
    'ValueOfPriority option values are numbers'
);

$m->submit_form_ok( { fields => { ValueOfQueue => 'General' }, button => 'AddClause' }, 'Limit queue' );
$form           = $m->form_name('BuildQuery');
$priority_input = $form->find_input('ValueOfPriority');
is( $priority_input->type, 'option', 'ValueOfPriority input is a select' );
is_deeply(
    [ $priority_input->possible_values ],
    [ '', 'Medium', 'VeryLow', 'Low', 'High', 'VeryHigh' ],
    'ValueOfTicketPriority option values are strings'
);

$m->submit_form_ok( { fields => { PriorityOp => '=', ValueOfPriority => 'High' }, button => 'DoSearch' },
    'Limit priority' );
$m->title_is('Found 1 ticket');
$m->text_contains('Test PriorityAsString');

$m->follow_link_ok( { text => 'Advanced' } );
$m->submit_form_ok(
    { form_name => 'BuildQueryAdvanced', fields => { Query => qq{Queue = 'General' AND Priority = 'Low'} } },
    'Search tickets with LowPriority' );
$m->submit_form_ok( { form_name => 'BuildQuery', button => 'DoSearch' } );
$m->title_is('Found 0 tickets');

$m->follow_link_ok( { text => 'Transactions' }, 'Transaction search builder' );
$form           = $m->form_name('BuildQuery');
$priority_input = $form->find_input('ValueOfTicketPriority');
is_deeply(
    [ $priority_input->possible_values ],
    [ '', 0, 50, 100, 50, 0, 20, 100, 200 ],
    'ValueOfPriority option values are numbers'
);

$m->submit_form_ok( { fields => { ValueOfTicketQueue => 'General' }, button => 'AddClause' }, 'Limit queue' );
$form           = $m->form_name('BuildQuery');
$priority_input = $form->find_input('ValueOfTicketPriority');
is( $priority_input->type, 'option', 'ValueOfTicketPriority input is a select' );
is_deeply(
    [ $priority_input->possible_values ],
    [ '', 'Medium', 'VeryLow', 'Low', 'High', 'VeryHigh' ],
    'ValueOfTicketPriority option values are strings'
);

$m->submit_form_ok( { fields => { TicketPriorityOp => '=', ValueOfTicketPriority => 'High' }, button => 'DoSearch' },
    'Limit priority' );
$m->title_is('Found 4 transactions');
$m->text_contains('Test PriorityAsString');

done_testing;
