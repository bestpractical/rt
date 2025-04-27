
use strict;
use warnings;
use RT::Test;

my $class = RT::Class->new($RT::SystemUser);
$class->Load( 'General' );
ok $class && $class->id, 'loaded class';

note 'basic scrips functionality test: create+execute';
{
    my $s1 = RT::Scrip->new(RT->SystemUser);
    my ($val, $msg) = $s1->Create(
        LookupType => 'RT::Class-RT::Article',
        ObjectId => $class->Id,
        ScripAction => 'User Defined',
        ScripCondition => 'User Defined',
        CustomIsApplicableCode => '$self->TicketObj->Name =~ /fire/? 1 : 0',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->AddCustomFieldValue( Field => "Content", Value => "firey" );',
        Template => 'Blank'
    );
    ok($val, $msg);

    my $article = RT::Article->new(RT->SystemUser);
    my ($av, $am) = $article->Create(
        Class => $class->Id,
        Name => "hair on fire",
    );
    ok($av, $am);

    is ($article->FirstCustomFieldValue('Content') , 'firey', "Article description is set right");

    my $article2 = RT::Article->new(RT->SystemUser);
    my ($a2v, $a2m) = $article2->Create(
        Class => $class->Id,
        Name => "hair in water",
    );
    ok($a2v, $a2m);
    isnt ($article2->FirstCustomFieldValue('Content') , 'firey', "Article content is set right");
}

note 'modify properties of a scrip';
{
    my $scrip = RT::Scrip->new($RT::SystemUser);
    my ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripCondition => 'User Defined',
        ScripAction    => 'User Defined',
    );
    ok( !$val, "missing template: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripCondition => 'User Defined',
        ScripAction    => 'User Defined',
        Template       => 'not exists',
    );
    ok( !$val, "invalid template: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripAction => 'User Defined',
        Template    => 'Blank',
    );
    ok( !$val, "missing condition: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripCondition => 'not exists',
        ScripAction    => 'User Defined',
        Template       => 'Blank',
    );
    ok( !$val, "invalid condition: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripCondition => 'User Defined',
        Template       => 'Blank',
    );
    ok( !$val, "missing action: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripCondition => 'User Defined',
        ScripAction    => 'not exists',
        Template       => 'Blank',
    );
    ok( !$val, "invalid action: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'Blank',
    );
    ok( $val, "created scrip: $msg" );

    $scrip->Load($val);
    ok( $scrip->id, 'loaded scrip ' . $scrip->id );

    ( $val, $msg ) = $scrip->SetScripCondition();
    ok( !$val, "missing condition: $msg" );
    ( $val, $msg ) = $scrip->SetScripCondition('not exists');
    ok( !$val, "invalid condition: $msg" );
    ( $val, $msg ) = $scrip->SetScripCondition('User Defined');
    ok( !$val, "updated condition to 'User Defined': $msg" );

    ( $val, $msg ) = $scrip->SetScripAction();
    ok( !$val, "missing action: $msg" );
    ( $val, $msg ) = $scrip->SetScripAction('not exists');
    ok( !$val, "invalid action: $msg" );
    ( $val, $msg ) = $scrip->SetScripAction('User Defined');
    ok( !$val, "updated action to 'User Defined': $msg" );

    ( $val, $msg ) = $scrip->SetTemplate();
    ok( !$val, "missing template $msg" );
    ( $val, $msg ) = $scrip->SetTemplate('not exists');
    ok( !$val, "invalid template $msg" );
    ( $val, $msg ) = $scrip->SetTemplate('Blank');
    ok( !$val, "updated template to 'Blank': $msg" );

    ok( $scrip->Delete, 'delete the scrip' );
}

my $class_B = RT::Class->new($RT::SystemUser);
$class_B->Create( Name => 'B' );
ok $class_B && $class_B->id, 'created class';

note 'check creation errors vs. templates';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ObjectId       => $class->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ObjectId       => $class->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

    my $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( LookupType => 'RT::Class-RT::Article', ObjectId => $class->id, Name => 'bar' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ObjectId       => $class_B->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");
}

note 'check applications vs. templates';
{
    my $template = RT::Template->new( RT->SystemUser );
    my ($status, $msg) = $template->Create( LookupType => 'RT::Class-RT::Article', ObjectId => $class->id, Name => 'foo' );
    ok $status, 'created a template';

    my $scrip = RT::Scrip->new(RT->SystemUser);
    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Class-RT::Article',
        ObjectId       => $class->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'foo',
        CustomIsApplicableCode  => "1;",
        CustomPrepareCode       => "1;",
        CustomCommitCode        => "1;",
    );
    ok($status, 'created a scrip') or diag "error: $msg";
    RT::Test->object_scrips_are($scrip, [$class], [0, $class_B]);

    ($status, $msg) = $scrip->AddToObject( $class_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$class], [0, $class_B]);
    my $obj_scrip = RT::ObjectScrip->new( RT->SystemUser );
    ok($obj_scrip->LoadByCols( Scrip => $scrip->id, ObjectId => $class->id ));
    is($obj_scrip->Stage, 'TransactionCreate');
    is($obj_scrip->FriendlyStage, 'Normal');

    $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( LookupType => 'RT::Class-RT::Article', ObjectId => $class_B->id, Name => 'foo' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->AddToObject( $class_B->id );
    ok($status, 'added scrip to another class');
    RT::Test->object_scrips_are($scrip, [$class, $class_B], [0]);

    ($status, $msg) = $scrip->RemoveFromObject( $class_B->id );
    ok($status, 'removed scrip from class');

    ($status, $msg) = $template->Delete;
    ok $status, 'deleted template foo in class B';

    ($status, $msg) = $scrip->AddToObject( $class_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$class], [0, $class_B]);

    ($status, $msg) = $template->Create( LookupType => 'RT::Class-RT::Article', ObjectId => 0, Name => 'foo' );
    ok $status, 'created a global template';

    ($status, $msg) = $scrip->AddToObject( $class_B->id );
    ok($status, 'added scrip');
    RT::Test->object_scrips_are($scrip, [$class, $class_B], [0]);
}

note 'basic check for disabling scrips';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        LookupType => 'RT::Class-RT::Article',
        ObjectId => $class->id,
        ScripCondition => 'User Defined',
        ScripAction => 'User Defined',
        CustomIsApplicableCode => '$self->TransactionObj->Type eq "Create"? 1 : 0',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->AddCustomFieldValue( Field => "Content", Value => "87" ); return 1',
        Template => 'Blank'
    );
    ok($status, "created scrip");
    is($scrip->Disabled, 0, "not disabled");

    {
        my $article = RT::Article->new(RT->SystemUser);
        my ($aid, $msg) = $article->Create(
            Class => $class->id,
            Name => "test",
        );
        ok($aid, "created article") or diag "error: $msg";
        is ($article->FirstCustomFieldValue('Content') , '87', "Article content is set right");
    }

    ($status,$msg) = $scrip->SetDisabled(1);
    is($scrip->Disabled, 1, "disabled");

    {
        my $article = RT::Article->new(RT->SystemUser);
        my ($aid, $msg) = $article->Create(
            Class => $class->id,
            Name => "test2",
        );
        ok($aid, "created article") or diag "error: $msg";
        isnt ($article->FirstCustomFieldValue('Content') , '87', "Article content is set right");
    }

    is($scrip->FriendlyStage('TransactionCreate'), 'Normal',
        'Correct stage wording for TransactionCreate');
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch',
        'Correct stage wording for TransactionBatch');
    RT->Config->Set('UseTransactionBatch', 0);
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch (disabled by config)',
        'Correct stage wording for TransactionBatch with UseTransactionBatch disabled');
}
