
use strict;
use warnings;
use RT::Test tests => 25;

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
