use strict;
use warnings;
use RT::Test plugins => [qw(RT::Extension::ScripExecModule)];

my $system_user = RT->SystemUser;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

{
    my $action = RT::ScripAction->new($system_user);
    my ( $val, $msg) = $action->Create(
        Name => 'TestExecModuleAction',
        Description => '',
        ExecModule => 'Foo::Bar',
    );
    ok($val, $msg);

    my $condition = RT::ScripCondition->new($system_user);
    ( $val, $msg ) = $condition->Create(
        Name => 'TestExecModuleCondition',
        Description => '',
        ApplicableTransTypes => 'Create',
        ExecModule => 'Foo::Bar',
    );
    ok($val, $msg);
 
    my $scrip = RT::Scrip->new($system_user);
    ($val, $msg) = $scrip->Create(
        Queue => $queue->Id,
        ScripAction => 'TestExecModuleAction',
        ScripCondition => 'TestExecModuleCondition',
        Template => 'Blank'
    );
    ok($val,$msg);

    my $ticket = RT::Ticket->new($system_user);
    my ( $tid, $trans_id, $tmsg ) = $ticket->Create(
        Subject => 'Sample workflow test',
        Owner => 'root',
        Queue => $queue->Id
    );
    ok($tid, $tmsg);
}
