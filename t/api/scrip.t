
use strict;
use warnings;
use RT::Test;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue && $queue->id, 'loaded or created queue';

note 'basic scrips functionality test: create+execute';
{
    my $s1 = RT::Scrip->new(RT->SystemUser);
    my ($val, $msg) = $s1->Create(
        Queue => $queue->Id,
        ScripAction => 'User Defined',
        ScripCondition => 'User Defined',
        CustomIsApplicableCode => '$self->TicketObj->Subject =~ /fire/? 1 : 0',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->SetPriority("87");',
        Template => 'Blank'
    );
    ok($val,$msg);

    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($tv,$ttv,$tm) = $ticket->Create(
        Queue => $queue->Id,
        Subject => "hair on fire",
    );
    ok($tv, $tm);

    is ($ticket->Priority , '87', "Ticket priority is set right");

    my $ticket2 = RT::Ticket->new(RT->SystemUser);
    my ($t2v,$t2tv,$t2m) = $ticket2->Create(
        Queue => $queue->Id,
        Subject => "hair in water",
    );
    ok($t2v, $t2m);
    isnt ($ticket2->Priority , '87', "Ticket priority is set right");
}

note 'modify properties of a scrip';
{
    my $scrip = RT::Scrip->new($RT::SystemUser);
    my ( $val, $msg ) = $scrip->Create(
        ScripCondition => 'On Comment',
        ScripAction    => 'Notify Owner',
    );
    ok( !$val, "missing template: $msg" );
    ( $val, $msg ) = $scrip->Create(
        ScripCondition => 'On Comment',
        ScripAction    => 'Notify Owner',
        Template       => 'not exists',
    );
    ok( !$val, "invalid template: $msg" );

    ( $val, $msg ) = $scrip->Create(
        ScripAction => 'Notify Owner',
        Template    => 'Blank',
    );
    ok( !$val, "missing condition: $msg" );
    ( $val, $msg ) = $scrip->Create(
        ScripCondition => 'not exists',
        ScripAction    => 'Notify Owner',
        Template       => 'Blank',
    );
    ok( !$val, "invalid condition: $msg" );

    ( $val, $msg ) = $scrip->Create(
        ScripCondition => 'On Comment',
        Template       => 'Blank',
    );
    ok( !$val, "missing action: $msg" );
    ( $val, $msg ) = $scrip->Create(
        ScripCondition => 'On Comment',
        ScripAction    => 'not exists',
        Template       => 'Blank',
    );
    ok( !$val, "invalid action: $msg" );

    ( $val, $msg ) = $scrip->Create(
        ScripAction    => 'Notify Owner',
        ScripCondition => 'On Comment',
        Template       => 'Blank',
    );
    ok( $val, "created scrip: $msg" );
    $scrip->Load($val);
    ok( $scrip->id, 'loaded scrip ' . $scrip->id );

    ( $val, $msg ) = $scrip->SetScripCondition();
    ok( !$val, "missing condition: $msg" );
    ( $val, $msg ) = $scrip->SetScripCondition('not exists');
    ok( !$val, "invalid condition: $msg" );
    ( $val, $msg ) = $scrip->SetScripCondition('On Correspond');
    ok( $val, "updated condition to 'On Correspond': $msg" );

    ( $val, $msg ) = $scrip->SetScripAction();
    ok( !$val, "missing action: $msg" );
    ( $val, $msg ) = $scrip->SetScripAction('not exists');
    ok( !$val, "invalid action: $msg" );
    ( $val, $msg ) = $scrip->SetScripAction('Notify AdminCcs');
    ok( $val, "updated action to 'Notify AdminCcs': $msg" );

    ( $val, $msg ) = $scrip->SetTemplate();
    ok( !$val, "missing template $msg" );
    ( $val, $msg ) = $scrip->SetTemplate('not exists');
    ok( !$val, "invalid template $msg" );
    ( $val, $msg ) = $scrip->SetTemplate('Forward');
    ok( $val, "updated template to 'Forward': $msg" );

    ok( $scrip->Delete, 'delete the scrip' );
}

my $queue_B = RT::Test->load_or_create_queue( Name => 'B' );
ok $queue_B && $queue_B->id, 'loaded or created queue';

note 'check creation errors vs. templates';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        Queue          => $queue->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        Queue          => $queue->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

    my $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( Queue => $queue->id, Name => 'bar' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->Create(
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");

    ($status, $msg) = $scrip->Create(
        Queue          => $queue_B->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");
}

note 'check applications vs. templates';
{
    my $template = RT::Template->new( RT->SystemUser );
    my ($status, $msg) = $template->Create( Queue => $queue->id, Name => 'foo' );
    ok $status, 'created a template';

    my $scrip = RT::Scrip->new(RT->SystemUser);
    ($status, $msg) = $scrip->Create(
        Queue          => $queue->Id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'foo',
        CustomIsApplicableCode  => "1;",
        CustomPrepareCode       => "1;",
        CustomCommitCode        => "1;",
    );
    ok($status, 'created a scrip') or diag "error: $msg";
    RT::Test->object_scrips_are($scrip, [$queue], [0, $queue_B]);

    ($status, $msg) = $scrip->AddToObject( $queue_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$queue], [0, $queue_B]);
    my $obj_scrip = RT::ObjectScrip->new( RT->SystemUser );
    ok($obj_scrip->LoadByCols( Scrip => $scrip->id, ObjectId => $queue->id ));
    is($obj_scrip->Stage, 'TransactionCreate');
    is($obj_scrip->FriendlyStage, 'Normal');

    $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( Queue => $queue_B->id, Name => 'foo' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->AddToObject( $queue_B->id );
    ok($status, 'added scrip to another queue');
    RT::Test->object_scrips_are($scrip, [$queue, $queue_B], [0]);

    ($status, $msg) = $scrip->RemoveFromObject( $queue_B->id );
    ok($status, 'removed scrip from queue');

    ($status, $msg) = $template->Delete;
    ok $status, 'deleted template foo in queue B';

    ($status, $msg) = $scrip->AddToObject( $queue_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$queue], [0, $queue_B]);

    ($status, $msg) = $template->Create( Queue => 0, Name => 'foo' );
    ok $status, 'created a global template';

    ($status, $msg) = $scrip->AddToObject( $queue_B->id );
    ok($status, 'added scrip');
    RT::Test->object_scrips_are($scrip, [$queue, $queue_B], [0]);
}

note 'basic check for disabling scrips';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        Queue => $queue->id,
        ScripCondition => 'On Create',
        ScripAction => 'User Defined',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->SetPriority("87"); return 1',
        Template => 'Blank'
    );
    ok($status, "created scrip");
    is($scrip->Disabled, 0, "not disabled");

    {
        my $ticket = RT::Ticket->new(RT->SystemUser);
        my ($tid, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => "test",
        );
        ok($tid, "created ticket") or diag "error: $msg";
        is ($ticket->Priority , '87', "Ticket priority is set right");
    }

    ($status,$msg) = $scrip->SetDisabled(1);
    is($scrip->Disabled, 1, "disabled");

    {
        my $ticket = RT::Ticket->new(RT->SystemUser);
        my ($tid, undef, $msg) = $ticket->Create(
            Queue => $queue->id,
            Subject => "test",
        );
        ok($tid, "created ticket") or diag "error: $msg";
        isnt ($ticket->Priority , '87', "Ticket priority is set right");
    }

    is($scrip->FriendlyStage('TransactionCreate'), 'Normal',
        'Correct stage wording for TransactionCreate');
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch',
        'Correct stage wording for TransactionBatch');
    RT->Config->Set('UseTransactionBatch', 0);
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch (disabled by config)',
        'Correct stage wording for TransactionBatch with UseTransactionBatch disabled');
}
