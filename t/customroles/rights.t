use strict;
use warnings;

use RT::Test tests => undef;

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $inbox = RT::Test->load_or_create_queue( Name => 'Inbox' );
my $specs = RT::Test->load_or_create_queue( Name => 'Specs' );
my $development = RT::Test->load_or_create_queue( Name => 'Development' );

my $engineer = RT::CustomRole->new(RT->SystemUser);
my $sales = RT::CustomRole->new(RT->SystemUser);
my $unapplied = RT::CustomRole->new(RT->SystemUser);

my $linus = RT::Test->load_or_create_user( EmailAddress => 'linus@example.com' );
my $john = RT::Test->load_or_create_user( EmailAddress => 'john@example.com' );

my $blake = RT::Test->load_or_create_user( EmailAddress => 'blake@example.com' );
my $williamson = RT::Test->load_or_create_user( EmailAddress => 'williamson@example.com' );
my $moss = RT::Test->load_or_create_user( EmailAddress => 'moss@example.com' );
my $ricky = RT::Test->load_or_create_user( EmailAddress => 'ricky.roma@example.com' );

my $team = RT::Test->load_or_create_group(
    'Team',
    Members => [$blake, $williamson, $moss, $ricky],
);

diag 'setup' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $engineer->Create(
        Name      => 'Engineer-' . $$,
        MaxValues => 1,
    );
    ok($ok, "created Engineer role: $msg");

    ($ok, $msg) = $sales->Create(
        Name      => 'Sales-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created Sales role: $msg");

    ($ok, $msg) = $unapplied->Create(
        Name      => 'Unapplied-' . $$,
        MaxValues => 0,
    );
    ok($ok, "created Unapplied role: $msg");

    ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "added Sales to Inbox: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($development->id);
    ok($ok, "added Engineer to Development: $msg");
}

# the rights are set up as such:
# globally: sales can ShowTicket, engineers can ModifyTicket
# spec queue: sales can CommentOnTicket, engineers can ReplyToTicket

# blake is set up as sales person on inbox queue but not specs

diag 'assign rights and queue watcher' if $ENV{'TEST_VERBOSE'};
{
    ok( RT::Test->add_rights( { Principal => $engineer->GroupType, Right => [ qw(ModifyTicket) ] } ));
    ok( RT::Test->add_rights( { Principal => $sales->GroupType, Right => [ qw(ShowTicket) ] } ));
    ok( RT::Test->add_rights( { Principal => $engineer->GroupType, Right => [ qw(ReplyToTicket) ], Object => $specs } ));
    ok( RT::Test->add_rights( { Principal => $sales->GroupType, Right => [ qw(CommentOnTicket) ], Object => $specs } ));

    ok($inbox->AddWatcher(User => $blake, Type => $sales->GroupType));
}

my ($inbox_individual, $inbox_group, $specs_individual);

sub sales_has_rights_for_inbox_individual {
    my $has_right = shift;
    my $rationale = shift || '';

    my $t = $inbox_individual;

    if ($has_right) {
        is($t->RoleAddresses($sales->GroupType), (join ', ', sort $moss->EmailAddress, $ricky->EmailAddress), 'got salespeople');
    }
    else {
        is($t->RoleAddresses($sales->GroupType), '', "got no salespeople $rationale");
    }

    if ($has_right) {
        ok($blake->HasRight(Right => 'ShowTicket', Object => $t), 'blake (queue sales) has right to see the ticket');
        ok($moss->HasRight(Right => 'ShowTicket', Object => $t), 'moss (ticket sales) has right to see the ticket');
        ok($ricky->HasRight(Right => 'ShowTicket', Object => $t), 'ricky (ticket sales) has right to see the ticket');
    }
    else {
        ok(!$blake->HasRight(Right => 'ShowTicket', Object => $t), "blake (queue sales) has no right to see the ticket $rationale");
        ok(!$moss->HasRight(Right => 'ShowTicket', Object => $t), "moss (ticket sales) has no right to see the ticket $rationale");
        ok(!$ricky->HasRight(Right => 'ShowTicket', Object => $t), "ricky (ticket sales) has no right to see the ticket $rationale");
    }

    ok(!$blake->HasRight(Right => 'ModifyTicket', Object => $t), 'blake has no right to modify the ticket');
    ok(!$blake->HasRight(Right => 'ReplyToTicket', Object => $t), 'blake has no right to reply to the ticket');
    ok(!$blake->HasRight(Right => 'CommentOnTicket', Object => $t), 'blake has no right to comment on the ticket');
    ok(!$moss->HasRight(Right => 'ModifyTicket', Object => $t), 'moss has no right to modify the ticket');
    ok(!$moss->HasRight(Right => 'ReplyToTicket', Object => $t), 'moss has no right to reply to the ticket');
    ok(!$moss->HasRight(Right => 'CommentOnTicket', Object => $t), 'moss has no right to comment on the ticket');
    ok(!$ricky->HasRight(Right => 'ModifyTicket', Object => $t), 'ricky has no right to modify the ticket');
    ok(!$ricky->HasRight(Right => 'ReplyToTicket', Object => $t), 'ricky has no right to reply to the ticket');
    ok(!$ricky->HasRight(Right => 'CommentOnTicket', Object => $t), 'ricky has no right to comment on the ticket');
    ok(!$williamson->HasRight(Right => 'ShowTicket', Object => $t), 'williamson has no right to see the ticket');
    ok(!$williamson->HasRight(Right => 'ModifyTicket', Object => $t), 'williamson has no right to modify the ticket');
    ok(!$williamson->HasRight(Right => 'ReplyToTicket', Object => $t), 'williamson has no right to reply to the ticket');
    ok(!$williamson->HasRight(Right => 'CommentOnTicket', Object => $t), 'williamson has no right to comment on the ticket');
}

sub engineer_has_no_rights_for_inbox_individual {
    my $user = shift;
    my $t = $inbox_individual;

    ok(!$user->HasRight(Right => 'ShowTicket', Object => $t), $user->EmailAddress . ' has no right to see the ticket');
    ok(!$user->HasRight(Right => 'ModifyTicket', Object => $t), $user->EmailAddress . ' has no right to modify the ticket');
    ok(!$user->HasRight(Right => 'ReplyToTicket', Object => $t), $user->EmailAddress . ' has no right to reply to the ticket');
    ok(!$user->HasRight(Right => 'CommentOnTicket', Object => $t), $user->EmailAddress . ' has no right to comment on the ticket');
}

sub sales_has_rights_for_inbox_group {
    my $has_right = shift;
    my $rationale = shift || '';

    my $t = $inbox_group;

    if ($has_right) {
        is($t->RoleAddresses($sales->GroupType), (join ', ', sort $moss->EmailAddress, $ricky->EmailAddress, $blake->EmailAddress, $williamson->EmailAddress), 'got all salespeople');
    }
    else {
        is($t->RoleAddresses($sales->GroupType), '', "got no salespeople $rationale");
    }

    for my $user ($blake, $moss, $ricky, $williamson) {
        if ($has_right) {
            ok($user->HasRight(Right => 'ShowTicket', Object => $t), $user->Name . " (member of ticket sales group team) has right to see the ticket");
        }
        else {
            ok(!$user->HasRight(Right => 'ShowTicket', Object => $t), $user->Name . " (member of ticket sales group team) has no right to see the ticket $rationale");
        }

        ok(!$user->HasRight(Right => 'ModifyTicket', Object => $t), $user->Name . " (member of ticket sales group team) has no right to modify the ticket");
        ok(!$user->HasRight(Right => 'ReplyToTicket', Object => $t), $user->Name . " (member of ticket sales group team) has no right to reply to the ticket");
        ok(!$user->HasRight(Right => 'CommentOnTicket', Object => $t), $user->Name . " (member of ticket sales group team) has no right to comment on the ticket");
    }

    ok(!$linus->HasRight(Right => 'ShowTicket', Object => $t), "linus has no ShowTicket on inbox");
    ok(!$linus->HasRight(Right => 'ModifyTicket', Object => $t), "linus has no ModifyTicket on inbox");
    ok(!$linus->HasRight(Right => 'ReplyToTicket', Object => $t), "linus has no ReplyToTicket on inbox");
    ok(!$linus->HasRight(Right => 'CommentOnTicket', Object => $t), "linus has no CommentOnTicket on inbox");
}

sub sales_has_rights_for_specs_individual {
    my $has_right = shift;
    my $rationale = shift || '';

    my $t = $specs_individual;

    if (!$has_right || $has_right == 2) {
        is($t->RoleAddresses($sales->GroupType), '', "got no salespeople $rationale");
    }
    else {
        is($t->RoleAddresses($sales->GroupType), (join ', ', sort $moss->EmailAddress, $ricky->EmailAddress), 'got salespeople');
    }

    if (!$has_right) {
        ok(!$moss->HasRight(Right => 'ShowTicket', Object => $t), "moss (ticket sales) has no right to see the ticket $rationale");
        ok(!$moss->HasRight(Right => 'CommentOnTicket', Object => $t), "moss (ticket sales) has no right to comment on the ticket $rationale");
        ok(!$ricky->HasRight(Right => 'ShowTicket', Object => $t), "ricky (ticket sales) has no right to see the ticket $rationale");
        ok(!$ricky->HasRight(Right => 'CommentOnTicket', Object => $t), "ricky (ticket sales) has no right to comment on the ticket $rationale");
    }
    elsif ($has_right == 2) {
        ok($moss->HasRight(Right => 'ShowTicket', Object => $t), 'moss (ticket sales) has right to see the ticket thru global sales right');
        ok(!$moss->HasRight(Right => 'CommentOnTicket', Object => $t), "moss (ticket sales) has no right to comment on the ticket $rationale");
        ok($ricky->HasRight(Right => 'ShowTicket', Object => $t), 'ricky (ticket sales) has right to see the ticket thru global sales right');
        ok(!$ricky->HasRight(Right => 'CommentOnTicket', Object => $t), "ricky (ticket sales) has no right to comment on the ticket $rationale");
    }
    else {
        ok($moss->HasRight(Right => 'ShowTicket', Object => $t), 'moss (ticket sales) has right to see the ticket');
        ok($moss->HasRight(Right => 'CommentOnTicket', Object => $t), 'moss (ticket sales) has right to comment on the ticket');
        ok($ricky->HasRight(Right => 'ShowTicket', Object => $t), 'ricky (ticket sales) has right to see the ticket');
        ok($ricky->HasRight(Right => 'CommentOnTicket', Object => $t), 'ricky (ticket sales) has right to comment on the ticket');
    }

    ok(!$blake->HasRight(Right => 'ShowTicket', Object => $t), 'blake has no right to see the ticket');
    ok(!$blake->HasRight(Right => 'ModifyTicket', Object => $t), 'blake has no right to modify the ticket');
    ok(!$blake->HasRight(Right => 'ReplyToTicket', Object => $t), 'blake has no right to reply to the ticket');
    ok(!$blake->HasRight(Right => 'CommentOnTicket', Object => $t), 'blake has no right to comment on the ticket');
    ok(!$moss->HasRight(Right => 'ModifyTicket', Object => $t), 'moss has no right to modify the ticket');
    ok(!$moss->HasRight(Right => 'ReplyToTicket', Object => $t), 'moss has no right to reply to the ticket');
    ok(!$ricky->HasRight(Right => 'ModifyTicket', Object => $t), 'ricky has no right to modify the ticket');
    ok(!$ricky->HasRight(Right => 'ReplyToTicket', Object => $t), 'ricky has no right to reply to the ticket');
    ok(!$williamson->HasRight(Right => 'ShowTicket', Object => $t), 'williamson has no right to see the ticket');
    ok(!$williamson->HasRight(Right => 'ModifyTicket', Object => $t), 'williamson has no right to modify the ticket');
    ok(!$williamson->HasRight(Right => 'ReplyToTicket', Object => $t), 'williamson has no right to reply to the ticket');
    ok(!$williamson->HasRight(Right => 'CommentOnTicket', Object => $t), 'williamson has no right to comment on the ticket');
}

sub engineer_has_rights_for_specs_individual {
    my $user = shift;
    my $has_right = shift;
    my $t = $specs_individual;

    ok(!$user->HasRight(Right => 'ShowTicket', Object => $t), $user->EmailAddress . ' has no right to see the ticket');
    ok(!$user->HasRight(Right => 'CommentOnTicket', Object => $t), $user->EmailAddress . ' has no right to comment on the ticket');

    if ($has_right) {
        ok($user->HasRight(Right => 'ModifyTicket', Object => $t), $user->EmailAddress . ' (ticket engineer) has right to modify the ticket');
        ok($user->HasRight(Right => 'ReplyToTicket', Object => $t), $user->EmailAddress . ' (ticket engineer) has right to reply to the ticket');
    }
}

diag 'check individual rights on Inbox' if $ENV{'TEST_VERBOSE'};
{
    my $t = $inbox_individual = RT::Test->create_ticket(
        Queue => $inbox,
        Subject => 'wrongs',
        $sales->GroupType => [$moss->EmailAddress, $ricky->EmailAddress],
    );
    ok($t->id, 'created ticket');

    sales_has_rights_for_inbox_individual(1);
    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
}

diag 'check group rights on Inbox' if $ENV{'TEST_VERBOSE'};
{
    my $t = $inbox_group = RT::Test->create_ticket(
        Queue => $inbox,
        Subject => 'wrongs',
        $sales->GroupType => $team->PrincipalId,
    );
    ok($t->id, 'created ticket');

    sales_has_rights_for_inbox_group(1);
}

diag 'check individual rights on Specs' if $ENV{'TEST_VERBOSE'};
{
    my $t = $specs_individual = RT::Test->create_ticket(
        Queue => $specs,
        Subject => 'wrongs',
        $engineer->GroupType => $linus->PrincipalId,
        $sales->GroupType => [$moss->EmailAddress, $ricky->EmailAddress],
    );
    ok($t->id, 'created ticket');

    sales_has_rights_for_specs_individual(1);
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'disable Sales custom role to see how it shakes out permissions' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->SetDisabled(1);
    ok($ok, $msg);

    sales_has_rights_for_inbox_individual(0, 'because sales role is disabled');
    sales_has_rights_for_inbox_group(0, 'because sales role is disabled');
    sales_has_rights_for_specs_individual(0, 'because sales role is disabled');

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 're-enable Sales custom role to make sure all old group rights and memberships come back' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->SetDisabled(0);
    ok($ok, $msg);

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'remove Sales custom role from Inbox queue' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->RemoveFromObject($inbox->id);
    ok($ok, "removed Sales from Inbox: $msg");

    sales_has_rights_for_inbox_individual(0, 'because sales role was removed from Inbox');
    sales_has_rights_for_inbox_group(0, 'because sales role was removed from Inbox');
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 're-add Sales custom role to Inbox queue' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "re-added Sales to Specs: $msg");

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'remove Sales custom role from Inbox queue...' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->RemoveFromObject($inbox->id);
    ok($ok, "removed Sales from Inbox: $msg");

    sales_has_rights_for_inbox_individual(0, 'because sales role was removed from Inbox');
    sales_has_rights_for_inbox_group(0, 'because sales role was removed from Inbox');
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'disable Sales custom role to see how it shakes out permissions' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->SetDisabled(1);
    ok($ok, $msg);

    sales_has_rights_for_inbox_individual(0, 'because sales role is disabled and was removed from Inbox');
    sales_has_rights_for_inbox_group(0, 'because sales role is disabled and was removed from Inbox');
    sales_has_rights_for_specs_individual(0, 'because sales role is disabled');

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 're-enable Sales custom role to make sure specs regains rights and members but inbox does not because it was removed' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->SetDisabled(0);
    ok($ok, $msg);

    sales_has_rights_for_inbox_individual(0, 'because sales role is still removed from Inbox');
    sales_has_rights_for_inbox_group(0, 'because sales role is still removed from Inbox');
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 're-add Sales custom role to Inbox queue' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $sales->AddToObject($inbox->id);
    ok($ok, "re-added Sales to Specs: $msg");

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'change engineer from linus to john' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $specs_individual->AddWatcher(Type => $engineer->GroupType, Principal => $john->PrincipalObj);
    ok($ok, "set John as engineer: $msg");
    is($specs_individual->RoleAddresses($engineer->GroupType), $john->EmailAddress, 'engineer set to John');

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 0);
    engineer_has_rights_for_specs_individual($john => 1);
}

diag 'change engineer from john to nobody' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $specs_individual->AddWatcher(Type => $engineer->GroupType, Principal => RT->Nobody->PrincipalObj);
    ok($ok, "set Nobody as engineer: $msg");
    is($specs_individual->RoleAddresses($engineer->GroupType), '', 'engineer set to Nobody');

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 0);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'change engineer from nobody to linus' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $specs_individual->AddWatcher(Type => $engineer->GroupType, Principal => $linus->PrincipalObj);
    ok($ok, "set Linus as engineer: $msg");
    is($specs_individual->RoleAddresses($engineer->GroupType), $linus->EmailAddress, 'engineer set to Linus');

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'change queue from Specs to General' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $specs_individual->SetQueue($general->Id);
    ok($ok, "set queue to General: $msg");

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(2, 'queue changed to General');

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 0);
    engineer_has_rights_for_specs_individual($john => 0);
}

diag 'change queue from General to Specs' if $ENV{'TEST_VERBOSE'};
{
    my ($ok, $msg) = $specs_individual->SetQueue($specs->Id);
    ok($ok, "set queue to Specs: $msg");

    sales_has_rights_for_inbox_individual(1);
    sales_has_rights_for_inbox_group(1);
    sales_has_rights_for_specs_individual(1);

    engineer_has_no_rights_for_inbox_individual($_) for $linus, $john;
    engineer_has_rights_for_specs_individual($linus => 1);
    engineer_has_rights_for_specs_individual($john => 0);
}

done_testing;

