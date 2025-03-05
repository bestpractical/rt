
use strict;
use warnings;
use RT::Test::Assets;

my $catalog = RT::Test::Assets->load_or_create_catalog( Name => 'General assets' );
ok $catalog && $catalog->id, 'loaded or created catalog';

note 'basic scrips functionality test: create+execute';
{
    my $s1 = RT::Scrip->new(RT->SystemUser);
    my ($val, $msg) = $s1->Create(
        LookupType => 'RT::Catalog-RT::Asset',
        Queue => $catalog->Id,
        ScripAction => 'User Defined',
        ScripCondition => 'User Defined',
        CustomIsApplicableCode => '$self->TicketObj->Name =~ /fire/? 1 : 0',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->SetDescription("firey");',
        Template => 'Blank'
    );
    ok($val, $msg);

    my $asset = RT::Asset->new(RT->SystemUser);
    my ($av, $am) = $asset->Create(
        Catalog => $catalog->Id,
        Name => "hair on fire",
    );
    ok($av, $am);

    is ($asset->Description , 'firey', "Asset description is set right");

    my $asset2 = RT::Asset->new(RT->SystemUser);
    my ($a2v, $a2m) = $asset2->Create(
        Catalog => $catalog->Id,
        Name => "hair in water",
    );
    ok($a2v, $a2m);
    isnt ($asset2->Description , 'firey', "Asset description is set right");
}

note 'modify properties of a scrip';
{
    my $scrip = RT::Scrip->new($RT::SystemUser);
    my ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripCondition => 'User Defined',
        ScripAction    => 'User Defined',
    );
    ok( !$val, "missing template: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripCondition => 'User Defined',
        ScripAction    => 'User Defined',
        Template       => 'not exists',
    );
    ok( !$val, "invalid template: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripAction => 'User Defined',
        Template    => 'Blank',
    );
    ok( !$val, "missing condition: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripCondition => 'not exists',
        ScripAction    => 'User Defined',
        Template       => 'Blank',
    );
    ok( !$val, "invalid condition: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripCondition => 'User Defined',
        Template       => 'Blank',
    );
    ok( !$val, "missing action: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripCondition => 'User Defined',
        ScripAction    => 'not exists',
        Template       => 'Blank',
    );
    ok( !$val, "invalid action: $msg" );

    ( $val, $msg ) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
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

my $catalog_B = RT::Test::Assets->load_or_create_catalog( Name => 'B' );
ok $catalog_B && $catalog_B->id, 'loaded or created catalog';

note 'check creation errors vs. templates';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        Queue          => $catalog->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'not exist',
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        Queue          => $catalog->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 54321,
    );
    ok(!$status, "couldn't create scrip, not existing template");

  SKIP: {
    skip 'template overrides not available yet';
    my $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( Queue => $catalog->id, Name => 'bar' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");

    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        Queue          => $catalog_B->id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => $template->id,
    );
    ok(!$status, "couldn't create scrip, wrong template");
  }
}

note 'check applications vs. templates';
SKIP: {
    skip 'template overrides not available yet';
    my $template = RT::Template->new( RT->SystemUser );
    my ($status, $msg) = $template->Create( Queue => $catalog->id, Name => 'foo' );
    ok $status, 'created a template';

    my $scrip = RT::Scrip->new(RT->SystemUser);
    ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        Queue          => $catalog->Id,
        ScripAction    => 'User Defined',
        ScripCondition => 'User Defined',
        Template       => 'foo',
        CustomIsApplicableCode  => "1;",
        CustomPrepareCode       => "1;",
        CustomCommitCode        => "1;",
    );
    ok($status, 'created a scrip') or diag "error: $msg";
    RT::Test->object_scrips_are($scrip, [$catalog], [0, $catalog_B]);

    ($status, $msg) = $scrip->AddToObject( $catalog_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$catalog], [0, $catalog_B]);
    my $obj_scrip = RT::ObjectScrip->new( RT->SystemUser );
    ok($obj_scrip->LoadByCols( Scrip => $scrip->id, ObjectId => $catalog->id ));
    is($obj_scrip->Stage, 'TransactionCreate');
    is($obj_scrip->FriendlyStage, 'Normal');

    $template = RT::Template->new( RT->SystemUser );
    ($status, $msg) = $template->Create( Queue => $catalog_B->id, Name => 'foo' );
    ok $status, 'created a template';

    ($status, $msg) = $scrip->AddToObject( $catalog_B->id );
    ok($status, 'added scrip to another catalog');
    RT::Test->object_scrips_are($scrip, [$catalog, $catalog_B], [0]);

    ($status, $msg) = $scrip->RemoveFromObject( $catalog_B->id );
    ok($status, 'removed scrip from catalog');

    ($status, $msg) = $template->Delete;
    ok $status, 'deleted template foo in catalog B';

    ($status, $msg) = $scrip->AddToObject( $catalog_B->id );
    ok(!$status, $msg);
    RT::Test->object_scrips_are($scrip, [$catalog], [0, $catalog_B]);

    ($status, $msg) = $template->Create( Queue => 0, Name => 'foo' );
    ok $status, 'created a global template';

    ($status, $msg) = $scrip->AddToObject( $catalog_B->id );
    ok($status, 'added scrip');
    RT::Test->object_scrips_are($scrip, [$catalog, $catalog_B], [0]);
}

note 'basic check for disabling scrips';
{
    my $scrip = RT::Scrip->new(RT->SystemUser);
    my ($status, $msg) = $scrip->Create(
        LookupType     => 'RT::Catalog-RT::Asset',
        Queue => $catalog->id,
        ScripCondition => 'User Defined',
        ScripAction => 'User Defined',
        CustomIsApplicableCode => '$self->TransactionObj->Type eq "Create"? 1 : 0',
        CustomPrepareCode => 'return 1',
        CustomCommitCode => '$self->TicketObj->SetDescription("87"); return 1',
        Template => 'Blank'
    );
    ok($status, "created scrip");
    is($scrip->Disabled, 0, "not disabled");

    {
        my $asset = RT::Asset->new(RT->SystemUser);
        my ($aid, $msg) = $asset->Create(
            Catalog => $catalog->id,
            Name => "test",
        );
        ok($aid, "created asset") or diag "error: $msg";
        is ($asset->Description , '87', "Asset description is set right");
    }

    ($status,$msg) = $scrip->SetDisabled(1);
    is($scrip->Disabled, 1, "disabled");

    {
        my $asset = RT::Asset->new(RT->SystemUser);
        my ($aid, $msg) = $asset->Create(
            Catalog => $catalog->id,
            Name => "test",
        );
        ok($aid, "created asset") or diag "error: $msg";
        isnt ($asset->Description , '87', "Asset description is set right");
    }

    is($scrip->FriendlyStage('TransactionCreate'), 'Normal',
        'Correct stage wording for TransactionCreate');
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch',
        'Correct stage wording for TransactionBatch');
    RT->Config->Set('UseTransactionBatch', 0);
    is($scrip->FriendlyStage('TransactionBatch'), 'Batch (disabled by config)',
        'Correct stage wording for TransactionBatch with UseTransactionBatch disabled');
}

note 'check scrip actions name constraints';
{
    # Test that we can't create unnamed actions
    my $action1 = RT::ScripAction->new( RT->SystemUser );
    my ( $id1, $msg1 ) = $action1->Create( Name => '', );
    is( $msg1, 'empty name' );

    # Create action Foo
    my $action2 = RT::ScripAction->new( RT->SystemUser );
    $action2->Create( Name => 'Foo Action', );

    my $action3 = RT::ScripAction->new( RT->SystemUser );
    my ( $id3, $msg3 ) = $action3->Create( Name => 'Foo Action', );

    # Make sure we can't create a action with the same name
    is( $msg3, 'Name in use' );
}

note 'check scrip conditions name constrains';
{
    # Test that we can't create unnamed conditions
    my $condition1 = RT::ScripCondition->new( RT->SystemUser );
    my ( $id1, $msg1 ) = $condition1->Create( Name => '', );
    is( $msg1, 'empty name' );

    # Create condition Foo
    my $condition2 = RT::ScripCondition->new( RT->SystemUser );
    $condition2->Create( Name => 'Foo Condition', );

    my $condition3 = RT::ScripCondition->new( RT->SystemUser );
    my ( $id3, $msg3 ) = $condition3->Create( Name => 'Foo Condition', );

    # Make sure we can't create a condition with the same name
    is( $msg3, 'Name in use' );
}
