use utf8;
use strict;
use warnings;
use JSON;

use RT::Test tests => undef, config => << 'CONFIG';
Set($InitialdataFormatHandlers, [ 'perl', 'RT::Initialdata::JSON' ]);
CONFIG

my $general = RT::Queue->new(RT->SystemUser);
$general->Load('General');

my @tests = (
    {
        name => 'Simple user-defined group',
        create => sub {
            my $group = RT::Group->new(RT->SystemUser);
            my ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Staff');
            ok($ok, $msg);
        },
        absent => sub {
            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadUserDefinedGroup('Staff');
            ok(!$group->Id, 'No such group');
        },
        present => sub {
            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadUserDefinedGroup('Staff');
            ok($group->Id, 'Loaded group');
            is($group->Name, 'Staff', 'Group name');
            is($group->Domain, 'UserDefined', 'Domain');
        },
    },
    {
        name => 'Group membership and ACLs',
        create => sub {
            my $outer = RT::Group->new(RT->SystemUser);
            my ($ok, $msg) = $outer->CreateUserDefinedGroup(Name => 'Outer');
            ok($ok, $msg);

            my $inner = RT::Group->new(RT->SystemUser);
            ($ok, $msg) = $inner->CreateUserDefinedGroup(Name => 'Inner');
            ok($ok, $msg);

            my $unrelated = RT::Group->new(RT->SystemUser);
            ($ok, $msg) = $unrelated->CreateUserDefinedGroup(Name => 'Unrelated');
            ok($ok, $msg);

            my $user = RT::User->new(RT->SystemUser);
            ($ok, $msg) = $user->Create(Name => 'User');
            ok($ok, $msg);

            my $unprivileged = RT::User->new(RT->SystemUser);
            ($ok, $msg) = $unprivileged->Create(Name => 'Unprivileged');
            ok($ok, $msg);

            ($ok, $msg) = $outer->AddMember($inner->PrincipalId);
            ok($ok, $msg);

            ($ok, $msg) = $inner->AddMember($user->PrincipalId);
            ok($ok, $msg);

            ($ok, $msg) = $general->AddWatcher(Type => 'AdminCc', PrincipalId => $outer->PrincipalId);
            ok($ok, $msg);

            ($ok, $msg) = $general->AdminCc->PrincipalObj->GrantRight(Object => $general, Right => 'ShowTicket');
            ok($ok, $msg);

            ($ok, $msg) = $inner->PrincipalObj->GrantRight(Object => $general, Right => 'ModifyTicket');
            ok($ok, $msg);

            ($ok, $msg) = $user->PrincipalObj->GrantRight(Object => $general, Right => 'OwnTicket');
            ok($ok, $msg);

            ($ok, $msg) = $unprivileged->PrincipalObj->GrantRight(Object => RT->System, Right => 'ModifyTicket');
            ok($ok, $msg);

            ($ok, $msg) = $inner->PrincipalObj->GrantRight(Object => $inner, Right => 'SeeGroup');
            ok($ok, $msg);

        },
        present => sub {
            my $outer = RT::Group->new(RT->SystemUser);
            $outer->LoadUserDefinedGroup('Outer');
            ok($outer->Id, 'Loaded group');
            is($outer->Name, 'Outer', 'Group name');

            my $inner = RT::Group->new(RT->SystemUser);
            $inner->LoadUserDefinedGroup('Inner');
            ok($inner->Id, 'Loaded group');
            is($inner->Name, 'Inner', 'Group name');

            my $unrelated = RT::Group->new(RT->SystemUser);
            $unrelated->LoadUserDefinedGroup('Unrelated');
            ok($unrelated->Id, 'Loaded group');
            is($unrelated->Name, 'Unrelated', 'Group name');

            my $user = RT::User->new(RT->SystemUser);
            $user->Load('User');
            ok($user->Id, 'Loaded user');
            is($user->Name, 'User', 'User name');

            my $unprivileged = RT::User->new(RT->SystemUser);
            $unprivileged->Load('Unprivileged');
            ok($unprivileged->Id, 'Loaded Unprivileged');
            is($unprivileged->Name, 'Unprivileged', 'Unprivileged name');

            ok($outer->HasMember($inner->PrincipalId), 'outer hasmember inner');
            ok($inner->HasMember($user->PrincipalId), 'inner hasmember user');
            ok($outer->HasMemberRecursively($user->PrincipalId), 'outer hasmember user recursively');
            ok(!$outer->HasMember($user->PrincipalId), 'outer does not have member user directly');
            ok(!$inner->HasMember($outer->PrincipalId), 'inner does not have member outer');

            ok($general->AdminCc->HasMember($outer->PrincipalId), 'queue AdminCc');
            ok($general->AdminCc->HasMemberRecursively($inner->PrincipalId), 'queue AdminCc');
            ok($general->AdminCc->HasMemberRecursively($user->PrincipalId), 'queue AdminCc');

            ok(!$outer->HasMemberRecursively($unrelated->PrincipalId), 'unrelated group membership');
            ok(!$inner->HasMemberRecursively($unrelated->PrincipalId), 'unrelated group membership');
            ok(!$general->AdminCc->HasMemberRecursively($unrelated->PrincipalId), 'unrelated group membership');

            ok($general->AdminCc->PrincipalObj->HasRight(Object => $general, Right => 'ShowTicket'), 'AdminCc ShowTicket right');
            ok($outer->PrincipalObj->HasRight(Object => $general, Right => 'ShowTicket'), 'outer ShowTicket right');
            ok($inner->PrincipalObj->HasRight(Object => $general, Right => 'ShowTicket'), 'inner ShowTicket right');
            ok($user->PrincipalObj->HasRight(Object => $general, Right => 'ShowTicket'), 'user ShowTicket right');
            ok(!$unrelated->PrincipalObj->HasRight(Object => $general, Right => 'ShowTicket'), 'unrelated ShowTicket right');

            ok(!$general->AdminCc->PrincipalObj->HasRight(Object => $general, Right => 'ModifyTicket'), 'AdminCc ModifyTicket right');
            ok(!$outer->PrincipalObj->HasRight(Object => $general, Right => 'ModifyTicket'), 'outer ModifyTicket right');
            ok($inner->PrincipalObj->HasRight(Object => $general, Right => 'ModifyTicket'), 'inner ModifyTicket right');
            ok($user->PrincipalObj->HasRight(Object => $general, Right => 'ModifyTicket'), 'user ModifyTicket right');
            ok(!$unrelated->PrincipalObj->HasRight(Object => $general, Right => 'ModifyTicket'), 'unrelated ModifyTicket right');

            ok(!$general->AdminCc->PrincipalObj->HasRight(Object => $general, Right => 'OwnTicket'), 'AdminCc OwnTicket right');
            ok(!$outer->PrincipalObj->HasRight(Object => $general, Right => 'OwnTicket'), 'outer OwnTicket right');
            ok(!$inner->PrincipalObj->HasRight(Object => $general, Right => 'OwnTicket'), 'inner OwnTicket right');
            ok($user->PrincipalObj->HasRight(Object => $general, Right => 'OwnTicket'), 'inner OwnTicket right');
            ok(!$unrelated->PrincipalObj->HasRight(Object => $general, Right => 'OwnTicket'), 'unrelated OwnTicket right');

            ok($unprivileged->PrincipalObj->HasRight(Object => RT->System, Right => 'ModifyTicket'), 'unprivileged ModifyTicket right');

            ok(!$general->AdminCc->PrincipalObj->HasRight(Object => $inner, Right => 'SeeGroup'), 'AdminCc SeeGroup right');
            ok(!$outer->PrincipalObj->HasRight(Object => $inner, Right => 'SeeGroup'), 'outer SeeGroup right');
            ok($inner->PrincipalObj->HasRight(Object => $inner, Right => 'SeeGroup'), 'inner SeeGroup right');
            ok($user->PrincipalObj->HasRight(Object => $inner, Right => 'SeeGroup'), 'user SeeGroup right');
            ok(!$unrelated->PrincipalObj->HasRight(Object => $inner, Right => 'SeeGroup'), 'unrelated SeeGroup right');
        },
    },

    {
        name => 'Custom field on two queues',
        create => sub {
            my $bugs = RT::Queue->new(RT->SystemUser);
            my ($ok, $msg) = $bugs->Create(Name => 'Bugs');
            ok($ok, $msg);

            my $features = RT::Queue->new(RT->SystemUser);
            ($ok, $msg) = $features->Create(Name => 'Features');
            ok($ok, $msg);

            my $cf = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $cf->Create(
                Name => 'Fixed In',
                Type => 'SelectSingle',
                LookupType => RT::Ticket->CustomFieldLookupType,
            );
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddToObject($bugs);
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddToObject($features);
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddValue(Name => '0.1', Description => 'Prototype', SortOrder => '1');
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddValue(Name => '1.0', Description => 'Gold', SortOrder => '10');
            ok($ok, $msg);

            # these next two are intentionally added in an order different from their SortOrder
            ($ok, $msg) = $cf->AddValue(Name => '2.0', Description => 'Remaster', SortOrder => '20');
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddValue(Name => '1.1', Description => 'Gold Bugfix', SortOrder => '11');
            ok($ok, $msg);

        },
        present => sub {
            my $bugs = RT::Queue->new(RT->SystemUser);
            $bugs->Load('Bugs');
            ok($bugs->Id, 'Bugs queue loaded');
            is($bugs->Name, 'Bugs');

            my $features = RT::Queue->new(RT->SystemUser);
            $features->Load('Features');
            ok($features->Id, 'Features queue loaded');
            is($features->Name, 'Features');

            my $cf = RT::CustomField->new(RT->SystemUser);
            $cf->Load('Fixed In');
            ok($cf->Id, 'Fixed In CF loaded');
            is($cf->Name, 'Fixed In');
            is($cf->Type, 'Select', 'Type');
            is($cf->MaxValues, 1, 'MaxValues');
            is($cf->LookupType, RT::Ticket->CustomFieldLookupType, 'LookupType');

            ok($cf->IsAdded($bugs->Id), 'CF is on Bugs queue');
            ok($cf->IsAdded($features->Id), 'CF is on Features queue');
            ok(!$cf->IsAdded(0), 'CF is not global');
            ok(!$cf->IsAdded($general->Id), 'CF is not on General queue');

            my @values = map { {
                Name => $_->Name,
                Description => $_->Description,
                SortOrder => $_->SortOrder,
            } } @{ $cf->Values->ItemsArrayRef };

            is_deeply(\@values, [
                { Name => '0.1', Description => 'Prototype', SortOrder => '1' },
                { Name => '1.0', Description => 'Gold', SortOrder => '10' },
                { Name => '1.1', Description => 'Gold Bugfix', SortOrder => '11' },
                { Name => '2.0', Description => 'Remaster', SortOrder => '20' },
            ], 'CF values');
        },
    },

    {
        name => 'Custom field lookup types',
        create => sub {
            my %extra = (
                Group => { method => 'CreateUserDefinedGroup' },
                Asset => undef,
                Article => { Class => 'General' },
                Ticket => undef,
                Transaction => undef,
                User => undef,
            );

            for my $type (qw/Asset Article Group Queue Ticket Transaction User/) {
                my $class = "RT::$type";
                my $cf = RT::CustomField->new(RT->SystemUser);
                my ($ok, $msg) = $cf->Create(
                    Name => "$type CF",
                    Type => "FreeformSingle",
                    LookupType => $class->CustomFieldLookupType,
                );
                ok($ok, $msg);

                # apply globally
                ($ok, $msg) = $cf->AddToObject($cf->RecordClassFromLookupType->new(RT->SystemUser));
                ok($ok, $msg);

                next if exists($extra{$type}) && !defined($extra{$type});

                my $obj = $class->new(RT->SystemUser);
                my $method = delete($extra{$type}{method}) || 'Create';
                ($ok, $msg) = $obj->$method(
                    Name => $type,
                    %{ $extra{$type} || {} },
                );
                ok($ok, "created $type: $msg");
                ok($obj->Id, "loaded $type");

                ($ok, $msg) = $obj->AddCustomFieldValue(
                    Field => $cf->Id,
                    Value => "$type Value",
                );
                ok($ok, $msg);
            }
        },
        present => sub {
            my %load = (
                Transaction => undef,
                Ticket => undef,
                User => undef,
                Asset => undef,
            );

            for my $type (qw/Asset Article Group Queue Ticket Transaction User/) {
                my $class = "RT::$type";
                my $cf = RT::CustomField->new(RT->SystemUser);
                $cf->Load("$type CF");
                ok($cf->Id, "loaded $type CF");
                is($cf->Name, "$type CF", 'Name');
                is($cf->Type, 'Freeform', 'Type');
                is($cf->MaxValues, 1, 'MaxValues');
                is($cf->LookupType, $class->CustomFieldLookupType, 'LookupType');

                next if exists($load{$type}) && !defined($load{$type});

                my $obj = $class->new(RT->SystemUser);
                $obj->LoadByCols(
                    %{ $load{$type} || { Name => $type } },
                );
                ok($obj->Id, "loaded $type");

                is($obj->FirstCustomFieldValue($cf->Id), "$type Value", "CF value for $type");
            }
        },
    },

    {
        name => 'Custom field LargeContent',
        create => sub {
            my $cf = RT::CustomField->new(RT->SystemUser);
            my ($ok, $msg) = $cf->Create(
                Name => "Group CF",
                Type => "FreeformSingle",
                LookupType => RT::Group->CustomFieldLookupType,
            );
            ok($ok, $msg);

            ($ok, $msg) = $cf->AddToObject(RT::Group->new(RT->SystemUser));
            ok($ok, $msg);

            my $group = RT::Group->new(RT->SystemUser);
            ($ok, $msg) = $group->CreateUserDefinedGroup(Name => 'Group');
            ok($ok, $msg);

            ($ok, $msg) = $group->AddCustomFieldValue(
                Field => $cf->Id,
                Value => scalar("abc" x 256),
            );
            ok($ok, $msg);
        },
        present => sub {
            my $group = RT::Group->new(RT->SystemUser);
            $group->LoadUserDefinedGroup('Group');
            ok($group->Id, 'loaded Group');
            is($group->FirstCustomFieldValue('Group CF'), scalar("abc" x 256), "CF LargeContent");
        },
        # the following test peers into the initialdata only to make sure that
        # we are roundtripping LargeContent as expected; if this starts
        # failing it's not necessarily a problem, but it's worthy of
        # investigating whether the "present" tests are still testing
        # what they were meant to test
        raw => sub {
            my $json = shift;
            my ($group) = grep { $_->{Name} eq 'Group' } @{ $json->{Groups} };
            ok($group, 'found the group');
            my ($ocfv) = @{ $group->{CustomFields} };
            ok($ocfv, 'found the OCFV');

            is($ocfv->{CustomField}, 'Group CF', 'CustomField');
            is($ocfv->{Content}, undef, 'no Content');
            is($ocfv->{LargeContent}, scalar("abc" x 256), 'LargeContent');
            is($ocfv->{ContentType}, "text/plain", 'ContentType');
        }
    },

    {
        name => 'Scrips including Disabled',
        export_args => { FollowDisabled => 1 },
        create => sub {
            my $bugs = RT::Queue->new(RT->SystemUser);
            my ($ok, $msg) = $bugs->Create(Name => 'Bugs');
            ok($ok, $msg);

            my $features = RT::Queue->new(RT->SystemUser);
            ($ok, $msg) = $features->Create(Name => 'Features');
            ok($ok, $msg);

            my $disabled = RT::Scrip->new(RT->SystemUser);
            ($ok, $msg) = $disabled->Create(
                Queue => 0,
                Description => 'Disabled Scrip',
                Template => 'Blank',
                ScripCondition => 'User Defined',
                ScripAction => 'User Defined',
                CustomIsApplicableCode => 'return "condition"',
                CustomPrepareCode => 'return "prepare"',
                CustomCommitCode => 'return "commit"',
            );
            ok($ok, $msg);
            ($ok, $msg) = $disabled->SetDisabled(1);
            ok($ok, $msg);

            my $stages = RT::Scrip->new(RT->SystemUser);
            ($ok, $msg) = $stages->Create(
                Description => 'Staged Scrip',
                Template => 'Transaction',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);

            ($ok, $msg) = $stages->RemoveFromObject(0);
            ok($ok, $msg);

            ($ok, $msg) = $stages->AddToObject(
                ObjectId  => $bugs->Id,
                Stage     => 'TransactionBatch',
                SortOrder => 42,
            );
            ok($ok, $msg);

            ($ok, $msg) = $stages->AddToObject(
                ObjectId  => $features->Id,
                Stage     => 'TransactionCreate',
                SortOrder => 99,
            );
            ok($ok, $msg);
        },
        present => sub {
            my $bugs = RT::Queue->new(RT->SystemUser);
            $bugs->Load('Bugs');
            ok($bugs->Id, 'Bugs queue loaded');
            is($bugs->Name, 'Bugs');

            my $features = RT::Queue->new(RT->SystemUser);
            $features->Load('Features');
            ok($features->Id, 'Features queue loaded');
            is($features->Name, 'Features');

            my $disabled = RT::Scrip->new(RT->SystemUser);
            $disabled->LoadByCols(Description => 'Disabled Scrip');
            ok($disabled->Id, 'Disabled scrip loaded');
            is($disabled->Description, 'Disabled Scrip', 'Description');
            is($disabled->Template, 'Blank', 'Template');
            is($disabled->ConditionObj->Name, 'User Defined', 'Condition');
            is($disabled->ActionObj->Name, 'User Defined', 'Action');
            is($disabled->CustomIsApplicableCode, 'return "condition"', 'Condition code');
            is($disabled->CustomPrepareCode, 'return "prepare"', 'Prepare code');
            is($disabled->CustomCommitCode, 'return "commit"', 'Commit code');
            ok($disabled->Disabled, 'Disabled');
            ok($disabled->IsGlobal, 'IsGlobal');

            my $stages = RT::Scrip->new(RT->SystemUser);
            $stages->LoadByCols(Description => 'Staged Scrip');
            ok($stages->Id, 'Staged scrip loaded');
            is($stages->Description, 'Staged Scrip');
            ok(!$stages->Disabled, 'not Disabled');
            ok(!$stages->IsGlobal, 'not Global');

            my $bug_objectscrip = $stages->IsAdded($bugs->Id);
            ok($bug_objectscrip, 'added to Bugs');
            is($bug_objectscrip->Stage, 'TransactionBatch', 'Stage');
            is($bug_objectscrip->SortOrder, 42, 'SortOrder');

            my $features_objectscrip = $stages->IsAdded($features->Id);
            ok($features_objectscrip, 'added to Features');
            is($features_objectscrip->Stage, 'TransactionCreate', 'Stage');
            is($features_objectscrip->SortOrder, 99, 'SortOrder');

            ok(!$stages->IsAdded($general->Id), 'not added to General');
        },
    },

    {
        name => 'No disabled scrips',
        create => sub {
            my $disabled = RT::Scrip->new(RT->SystemUser);
            my ($ok, $msg) = $disabled->Create(
                Description => 'Disabled Scrip',
                Template => 'Transaction',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);
            ($ok, $msg) = $disabled->SetDisabled(1);
            ok($ok, $msg);

            my $enabled = RT::Scrip->new(RT->SystemUser);
            ($ok, $msg) = $enabled->Create(
                Description => 'Enabled Scrip',
                Template => 'Transaction',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);
        },
        present => sub {
            my $from_initialdata = shift;

            my $disabled = RT::Scrip->new(RT->SystemUser);
            $disabled->LoadByCols(Description => 'Disabled Scrip');

            if ($from_initialdata) {
                ok(!$disabled->Id, 'Disabled scrip absent in initialdata');
            }
            else {
                ok($disabled->Id, 'Disabled scrip present because of the original creation');
                ok($disabled->Disabled, 'Disabled scrip disabled');
            }

            my $enabled = RT::Scrip->new(RT->SystemUser);
            $enabled->LoadByCols(Description => 'Enabled Scrip');
            ok($enabled->Id, 'Enabled scrip present');
        },
    },

    {
        name => 'Disabled many-to-many relationships',
        create => sub {
            my $enabled_queue = RT::Queue->new(RT->SystemUser);
            my ($ok, $msg) = $enabled_queue->Create(
                Name => 'Enabled Queue',
            );
            ok($ok, $msg);

            my $disabled_queue = RT::Queue->new(RT->SystemUser);
            ($ok, $msg) = $disabled_queue->Create(
                Name => 'Disabled Queue',
            );
            ok($ok, $msg);

            my $enabled_cf = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $enabled_cf->Create(
                Name => 'Enabled CF',
                Type => 'FreeformSingle',
                LookupType => RT::Queue->CustomFieldLookupType,
            );
            ok($ok, $msg);

            my $disabled_cf = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $disabled_cf->Create(
                Name => 'Disabled CF',
                Type => 'FreeformSingle',
                LookupType => RT::Queue->CustomFieldLookupType,
            );
            ok($ok, $msg);

            my $enabled_scrip = RT::Scrip->new(RT->SystemUser);
            ($ok, $msg) = $enabled_scrip->Create(
                Queue => 0,
                Description => 'Enabled Scrip',
                Template => 'Blank',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);
            $enabled_scrip->RemoveFromObject(0);

            my $disabled_scrip = RT::Scrip->new(RT->SystemUser);
            ($ok, $msg) = $disabled_scrip->Create(
                Queue => 0,
                Description => 'Disabled Scrip',
                Template => 'Blank',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);
            $disabled_scrip->RemoveFromObject(0);

            my $enabled_class = RT::Class->new(RT->SystemUser);
            ($ok, $msg) = $enabled_class->Create(
                Name => 'Enabled Class',
            );
            ok($ok, $msg);

            my $disabled_class = RT::Class->new(RT->SystemUser);
            ($ok, $msg) = $disabled_class->Create(
                Name => 'Disabled Class',
            );
            ok($ok, $msg);

            my $enabled_role = RT::CustomRole->new(RT->SystemUser);
            ($ok, $msg) = $enabled_role->Create(
                Name => 'Enabled Role',
            );
            ok($ok, $msg);

            my $disabled_role = RT::CustomRole->new(RT->SystemUser);
            ($ok, $msg) = $disabled_role->Create(
                Name => 'Disabled Role',
            );
            ok($ok, $msg);

            my $enabled_group = RT::Group->new(RT->SystemUser);
            ($ok, $msg) = $enabled_group->CreateUserDefinedGroup(
                Name => 'Enabled Group',
            );
            ok($ok, $msg);

            my $disabled_group = RT::Group->new(RT->SystemUser);
            ($ok, $msg) = $disabled_group->CreateUserDefinedGroup(
                Name => 'Disabled Group',
            );
            ok($ok, $msg);

            my $enabled_user = RT::User->new(RT->SystemUser);
            ($ok, $msg) = $enabled_user->Create(
                Name => 'Enabled User',
            );
            ok($ok, $msg);

            my $disabled_user = RT::User->new(RT->SystemUser);
            ($ok, $msg) = $disabled_user->Create(
                Name => 'Disabled User',
            );
            ok($ok, $msg);

            for my $object ($enabled_cf, $disabled_cf,
                            $enabled_scrip, $disabled_scrip,
                            $enabled_class, $disabled_class,
                            $enabled_role, $disabled_role) {

                # slightly inconsistent API
                my ($queue_a, $queue_b) = ($disabled_queue, $enabled_queue);
                ($queue_a, $queue_b) = ($queue_a->Id, $queue_b->Id)
                    if $object->isa('RT::Scrip')
                    || $object->isa('RT::CustomRole');

                ($ok, $msg) = $object->AddToObject($queue_a);
                ok($ok, $msg);

                ($ok, $msg) = $object->AddToObject($queue_b);
                ok($ok, $msg);
            }

            for my $principal ($enabled_group, $disabled_group,
                               $enabled_user, $disabled_user) {
                ($ok, $msg) = $principal->PrincipalObj->GrantRight(Object => RT->System, Right => 'SeeQueue');
                ok($ok, $msg);

                for my $queue ($enabled_queue, $disabled_queue) {
                    ($ok, $msg) = $principal->PrincipalObj->GrantRight(Object => $queue, Right => 'ShowTicket');
                    ok($ok, $msg);

                    ($ok, $msg) = $queue->AddWatcher(Type => 'AdminCc', PrincipalId => $principal->PrincipalId);
                    ok($ok, $msg);
                }
            }

            for my $cf ($enabled_cf, $disabled_cf) {
                for my $queue ($enabled_queue, $disabled_queue) {
                    ($ok, $msg) = $queue->AddCustomFieldValue(Field => $cf->Id, Value => $cf->Name);
                    ok($ok, $msg);
                }
            }

            for my $object ($disabled_queue, $disabled_cf,
                            $disabled_scrip, $disabled_class,
                            $disabled_role, $disabled_group,
                            $disabled_user) {
                ($ok, $msg) = $object->SetDisabled(1);
                ok($ok, $msg);
            }
        },
        present => sub {
            my $from_initialdata = shift;

            my $enabled_queue = RT::Queue->new(RT->SystemUser);
            $enabled_queue->Load('Enabled Queue');
            ok($enabled_queue->Id, 'loaded Enabled queue');
            is($enabled_queue->Name, 'Enabled Queue', 'Enabled Queue Name');

            my $disabled_queue = RT::Queue->new(RT->SystemUser);
            $disabled_queue->Load('Disabled Queue');

            my $enabled_cf = RT::CustomField->new(RT->SystemUser);
            $enabled_cf->Load('Enabled CF');
            ok($enabled_cf->Id, 'loaded Enabled CF');
            is($enabled_cf->Name, 'Enabled CF', 'Enabled CF Name');
            ok($enabled_cf->IsAdded($enabled_queue->Id), 'Enabled CF added to General');

            is($enabled_queue->FirstCustomFieldValue('Enabled CF'), 'Enabled CF', 'OCFV');

            my $disabled_cf = RT::CustomField->new(RT->SystemUser);
            $disabled_cf->Load('Disabled CF');

            my $enabled_scrip = RT::Scrip->new(RT->SystemUser);
            $enabled_scrip->LoadByCols(Description => 'Enabled Scrip');
            ok($enabled_scrip->Id, 'loaded Enabled Scrip');
            is($enabled_scrip->Description, 'Enabled Scrip', 'Enabled Scrip Name');
            ok($enabled_scrip->IsAdded($enabled_queue->Id), 'Enabled Scrip added to General');
            my $disabled_scrip = RT::Scrip->new(RT->SystemUser);
            $disabled_scrip->LoadByCols(Description => 'Disabled Scrip');

            my $enabled_class = RT::Class->new(RT->SystemUser);
            $enabled_class->Load('Enabled Class');
            ok($enabled_class->Id, 'loaded Enabled Class');
            is($enabled_class->Name, 'Enabled Class', 'Enabled Class Name');
            ok($enabled_class->IsApplied($enabled_queue->Id), 'Enabled Class added to General');

            my $disabled_class = RT::Class->new(RT->SystemUser);
            $disabled_class->Load('Disabled Class');

            my $enabled_role = RT::CustomRole->new(RT->SystemUser);
            $enabled_role->Load('Enabled Role');
            ok($enabled_role->Id, 'loaded Enabled Role');
            is($enabled_role->Name, 'Enabled Role', 'Enabled Role Name');
            ok($enabled_role->IsAdded($enabled_queue->Id), 'Enabled Role added to General');

            my $disabled_role = RT::CustomRole->new(RT->SystemUser);
            $disabled_role->Load('Disabled Role');

            my $enabled_group = RT::Group->new(RT->SystemUser);
            $enabled_group->LoadUserDefinedGroup('Enabled Group');
            ok($enabled_group->Id, 'loaded Enabled Group');
            is($enabled_group->Name, 'Enabled Group', 'Enabled Group Name');
            ok($enabled_group->PrincipalObj->HasRight(Object => $enabled_queue, Right => 'ShowTicket'), 'Enabled Group has queue right');
            ok($enabled_group->PrincipalObj->HasRight(Object => RT->System, Right => 'SeeQueue'), 'Enabled Group has global right');
            ok($enabled_queue->AdminCc->HasMember($enabled_group->PrincipalObj), 'Enabled Group still queue watcher');

            my $disabled_group = RT::Group->new(RT->SystemUser);
            $disabled_group->LoadUserDefinedGroup('Disabled Group');

            my $enabled_user = RT::User->new(RT->SystemUser);
            $enabled_user->Load('Enabled User');
            ok($enabled_user->Id, 'loaded Enabled User');
            is($enabled_user->Name, 'Enabled User', 'Enabled User Name');
            ok($enabled_user->PrincipalObj->HasRight(Object => $enabled_queue, Right => 'ShowTicket'), 'Enabled User has queue right');
            ok($enabled_user->PrincipalObj->HasRight(Object => RT->System, Right => 'SeeQueue'), 'Enabled User has global right');
            ok($enabled_queue->AdminCc->HasMember($enabled_user->PrincipalObj), 'Enabled User still queue watcher');

            my $disabled_user = RT::User->new(RT->SystemUser);
            $disabled_user->Load('Disabled User');

            for my $object ($disabled_queue, $disabled_cf,
                            $disabled_scrip, $disabled_class,
                            $disabled_role, $disabled_group,
                            $disabled_user) {
                if ($from_initialdata) {
                    ok(!$object->Id, "disabled " . ref($object) . " excluded");
                }
                else {
                    ok($object->Disabled, "disabled " . ref($object));
                }
            }
        },
    },

    {
        name => 'Unapplied Objects',
        create => sub {
            my $scrip = RT::Scrip->new(RT->SystemUser);
            my ($ok, $msg) = $scrip->Create(
                Queue => 0,
                Description => 'Unapplied Scrip',
                Template => 'Blank',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);
            ($ok, $msg) = $scrip->RemoveFromObject(0);
            ok($ok, $msg);

            my $cf = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $cf->Create(
                Name        => 'Unapplied CF',
                Type        => 'FreeformSingle',
                LookupType  => RT::Ticket->CustomFieldLookupType,
            );
            ok($ok, $msg);

            my $class = RT::Class->new(RT->SystemUser);
            ($ok, $msg) = $class->Create(
                Name => 'Unapplied Class',
            );
            ok($ok, $msg);

            my $role = RT::CustomRole->new(RT->SystemUser);
            ($ok, $msg) = $role->Create(
                Name => 'Unapplied Custom Role',
            );
            ok($ok, $msg);
        },
        present => sub {
            my $scrip = RT::Scrip->new(RT->SystemUser);
            $scrip->LoadByCols(Description => 'Unapplied Scrip');
            ok($scrip->Id, 'Unapplied scrip loaded');
            is($scrip->Description, 'Unapplied Scrip');
            ok(!$scrip->Disabled, 'not Disabled');
            ok(!$scrip->IsGlobal, 'not Global');
            ok(!$scrip->IsAdded($general->Id), 'not applied to General queue');

            my $cf = RT::CustomField->new(RT->SystemUser);
            $cf->Load('Unapplied CF');
            ok($cf->Id, 'Unapplied CF loaded');
            is($cf->Name, 'Unapplied CF');
            ok(!$cf->Disabled, 'not Disabled');
            ok(!$cf->IsGlobal, 'not Global');
            ok(!$cf->IsAdded($general->Id), 'not applied to General queue');

            my $class = RT::Class->new(RT->SystemUser);
            $class->Load('Unapplied Class');
            ok($class->Id, 'Unapplied Class loaded');
            is($class->Name, 'Unapplied Class');
            ok(!$class->Disabled, 'not Disabled');
            ok(!$class->IsApplied(0), 'not Global');
            ok(!$class->IsApplied($general->Id), 'not applied to General queue');

            my $role = RT::CustomRole->new(RT->SystemUser);
            $role->Load('Unapplied Custom Role');
            ok($role->Id, 'Unapplied Custom Role loaded');
            is($role->Name, 'Unapplied Custom Role');
            ok(!$role->Disabled, 'not Disabled');
            ok(!$role->IsAdded(0), 'not Global');
            ok(!$role->IsAdded($general->Id), 'not applied to General queue');
        },
    },

    {
        name => 'Global Objects',
        create => sub {
            my $scrip = RT::Scrip->new(RT->SystemUser);
            my ($ok, $msg) = $scrip->Create(
                Queue => 0,
                Description => 'Global Scrip',
                Template => 'Blank',
                ScripCondition => 'On Create',
                ScripAction => 'Notify Owner',
            );
            ok($ok, $msg);

            my $cf = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $cf->Create(
                Name        => 'Global CF',
                Type        => 'FreeformSingle',
                LookupType  => RT::Ticket->CustomFieldLookupType,
            );
            ok($ok, $msg);
            ($ok, $msg) = $cf->AddToObject(RT::Queue->new(RT->SystemUser));
            ok($ok, $msg);

            my $class = RT::Class->new(RT->SystemUser);
            ($ok, $msg) = $class->Create(
                Name => 'Global Class',
            );
            ok($ok, $msg);
            ($ok, $msg) = $class->AddToObject(RT::Queue->new(RT->SystemUser));
            ok($ok, $msg);
        },
        present => sub {
            my $scrip = RT::Scrip->new(RT->SystemUser);
            $scrip->LoadByCols(Description => 'Global Scrip');
            ok($scrip->Id, 'Global scrip loaded');
            is($scrip->Description, 'Global Scrip');
            ok(!$scrip->Disabled, 'not Disabled');
            ok($scrip->IsGlobal, 'Global');
            ok(!$scrip->IsAdded($general->Id), 'not applied to General queue');

            my $cf = RT::CustomField->new(RT->SystemUser);
            $cf->Load('Global CF');
            ok($cf->Id, 'Global CF loaded');
            is($cf->Name, 'Global CF');
            ok(!$cf->Disabled, 'not Disabled');
            ok($cf->IsGlobal, 'Global');
            ok(!$cf->IsAdded($general->Id), 'not applied to General queue');

            my $class = RT::Class->new(RT->SystemUser);
            $class->Load('Global Class');
            ok($class->Id, 'Global Class loaded');
            is($class->Name, 'Global Class');
            ok(!$class->Disabled, 'not Disabled');
            ok($class->IsApplied(0), 'Global');
            ok(!$class->IsApplied($general->Id), 'not applied to General queue');
        },
    },
    {
        name => 'Templates',
        create => sub {
            my $global = RT::Template->new(RT->SystemUser);
            my ($ok, $msg) = $global->Create(
                Name => 'Initialdata test',
                Queue => 0,
                Description => 'foo',
                Content => "Hello こんにちは",
                Type => "Simple",
            );
            ok($ok, $msg);

            my $queue = RT::Template->new(RT->SystemUser);
            ($ok, $msg) = $queue->Create(
                Name => 'Initialdata test',
                Queue => $general->Id,
                Description => 'override for Swedes',
                Content => "Hello Hallå",
                Type => "Simple",
            );
            ok($ok, $msg);

            my $standalone = RT::Template->new(RT->SystemUser);
            ($ok, $msg) = $standalone->Create(
                Name => 'Standalone test',
                Queue => $general->Id,
                Description => 'no global version',
                Content => "this was broken!",
                Type => "Perl",
            );
            ok($ok, $msg);
        },
        present => sub {
            my $global = RT::Template->new(RT->SystemUser);
            $global->LoadGlobalTemplate('Initialdata test');
            ok($global->Id, 'loaded template');
            is($global->Name, 'Initialdata test', 'Name');
            is($global->Queue, 0, 'Queue');
            is($global->Description, 'foo', 'Description');
            is($global->Content, 'Hello こんにちは', 'Content');
            is($global->Type, 'Simple', 'Type');

            my $queue = RT::Template->new(RT->SystemUser);
            $queue->LoadQueueTemplate(Name => 'Initialdata test', Queue => $general->Id);
            ok($queue->Id, 'loaded template');
            is($queue->Name, 'Initialdata test', 'Name');
            is($queue->Queue, $general->Id, 'Queue');
            is($queue->Description, 'override for Swedes', 'Description');
            is($queue->Content, 'Hello Hallå', 'Content');
            is($queue->Type, 'Simple', 'Type');

            my $standalone = RT::Template->new(RT->SystemUser);
            $standalone->LoadQueueTemplate(Name => 'Standalone test', Queue => $general->Id);
            ok($standalone->Id, 'loaded template');
            is($standalone->Name, 'Standalone test', 'Name');
            is($standalone->Queue, $general->Id, 'Queue');
            is($standalone->Description, 'no global version', 'Description');
            is($standalone->Content, 'this was broken!', 'Content');
            is($standalone->Type, 'Perl', 'Type');
        },
    },
    {
        name => 'Articles',
        create => sub {
            my $class = RT::Class->new(RT->SystemUser);
            my ($ok, $msg) = $class->Create(
                Name => 'Test',
            );
            ok($ok, $msg);

            my $content = RT::CustomField->new(RT->SystemUser);
            $content->LoadByCols(
                Name => "Content",
                Type => "Text",
                LookupType => RT::Article->CustomFieldLookupType,
            );
            ok($content->Id, "loaded builtin Content CF");

            my $tags = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $tags->Create(
                Name => "Tags",
                Type => "FreeformMultiple",
                LookupType => RT::Article->CustomFieldLookupType,
            );
            ok($ok, $msg);
            ($ok, $msg) = $tags->AddToObject($class);
            ok($ok, $msg);

            my $clearance = RT::CustomField->new(RT->SystemUser);
            ($ok, $msg) = $clearance->Create(
                Name => "Clearance",
                Type => "SelectSingle",
                LookupType => RT::Article->CustomFieldLookupType,
            );
            ok($ok, $msg);
            ($ok, $msg) = $clearance->AddToObject($class);
            ok($ok, $msg);

            ($ok, $msg) = $clearance->AddValue(Name => 'Unclassified');
            ok($ok, $msg);
            ($ok, $msg) = $clearance->AddValue(Name => 'Classified');
            ok($ok, $msg);
            ($ok, $msg) = $clearance->AddValue(Name => 'Top Secret');
            ok($ok, $msg);

            my $coffee = RT::Article->new(RT->SystemUser);
            ($ok, $msg) = $coffee->Create(
                Class => 'Test',
                Name  => 'Coffee time',
                "CustomField-" . $content->Id => 'Always',
                "CustomField-" . $clearance->Id => 'Unclassified',
                "CustomField-" . $tags->Id => ['drink', 'coffee', 'how the humans live'],
            );
            ok($ok, $msg);

            my $twd = RT::Article->new(RT->SystemUser);
            ($ok, $msg) = $twd->Create(
                Class => 'Test',
                Name  => 'Total world domination plans',
                "CustomField-" . $content->Id => 'REDACTED',
                "CustomField-" . $clearance->Id => 'Top Secret',
                "CustomField-" . $tags->Id => ['snakes', 'clowns'],
            );
            ok($ok, $msg);
        },
        present => sub {
            my $class = RT::Class->new(RT->SystemUser);
            $class->Load('Test');
            ok($class->Id, 'loaded class');
            is($class->Name, 'Test', 'Name');

            my $coffee = RT::Article->new(RT->SystemUser);
            $coffee->LoadByCols(Name => 'Coffee time');
            ok($coffee->Id, 'loaded article');
            is($coffee->Name, 'Coffee time', 'Name');
            is($coffee->Class, $class->Id, 'Class');
            is($coffee->FirstCustomFieldValue('Content'), 'Always', 'Content CF');
            is($coffee->FirstCustomFieldValue('Clearance'), 'Unclassified', 'Clearance CF');
            is($coffee->CustomFieldValuesAsString('Tags', Separator => '.'), 'drink.coffee.how the humans live', 'Tags CF');

            my $twd = RT::Article->new(RT->SystemUser);
            $twd->LoadByCols(Name => 'Total world domination plans');
            ok($twd->Id, 'loaded article');
            is($twd->Name, 'Total world domination plans', 'Name');
            is($twd->Class, $class->Id, 'Class');
            is($twd->FirstCustomFieldValue('Content'), 'REDACTED', 'Content CF');
            is($twd->FirstCustomFieldValue('Clearance'), 'Top Secret', 'Clearance CF');
            is($twd->CustomFieldValuesAsString('Tags', Separator => '.'), 'snakes.clowns', 'Tags CF');
        },
    },
    {
        name => 'Attributes',
        create => sub {
            my $root = RT::User->new(RT->SystemUser);
            my ($ok, $msg) = $root->Load('root');
            ok($ok, $msg);

            my $dashboard = RT::Dashboard->new($root);
            ($ok, $msg) = $dashboard->Save(
                Name => 'My Dashboard',
                Privacy => 'RT::User-' . $root->Id,
            );
            ok($ok, $msg);

            my $subscription = RT::Attribute->new($root);
            ($ok, $msg) = $subscription->Create(
                Name        => 'Subscription',
                Description => 'Subscription to dashboard ' . $dashboard->Id,
                ContentType => 'storable',
                Object      => $root,
                Content     => { 'Tuesday' => '1', 'DashboardId' => $dashboard->Id },
            );
        },
        present => sub {
            # Provided in core initialdata
            my $homepage = RT::Attribute->new(RT->SystemUser);
            $homepage->LoadByNameAndObject(Name => 'HomepageSettings', Object => RT->System);
            ok($homepage->Id, 'Loaded homepage attribute');
            is($homepage->Name, 'HomepageSettings', 'Name is HomepageSettings');
            is($homepage->Description, 'HomepageSettings', 'Description is HomepageSettings');
            is($homepage->ContentType, 'storable', 'ContentType is storable');

            my $root = RT::User->new(RT->SystemUser);
            my ($ok, $msg) = $root->Load('root');
            ok($ok, $msg);

            my $dashboard = RT::Attribute->new($root);
            $dashboard->LoadByNameAndObject(Name => 'Dashboard', Object => $root);
            ok($dashboard->Id, 'Loaded dashboard attribute with id ' . $dashboard->Id);

            my $subscription = RT::Attribute->new($root);
            $subscription->LoadByNameAndObject(Name => 'Subscription', Object => $root);
            ok($subscription->Id, 'Loaded subscription attribute with id ' . $subscription->Id);
            is($subscription->ContentType, 'storable', 'ContentType is storable');
            is($subscription->Content->{DashboardId}, $dashboard->Id, 'Dashboard Id is ' . $dashboard->Id);
            is( $subscription->Description,
                'Subscription to dashboard ' . $dashboard->Id,
                'Description is "Subscription to dashboard ' . $dashboard->Id . '"'
              );
        },
    },
);

my $id = 0;
for my $test (@tests) {
    $id++;
    my $directory = File::Spec->catdir(RT::Test->temp_directory, "export-$id");

    # we get a lot of warnings about already-existing objects; suppress them
    # for now until we clean it up
    my $warn = $SIG{__WARN__};
    local $SIG{__WARN__} = sub {
        return if $_[0] =~ join '|', (
            qr/^Name in use$/,
            qr/^A Template with that name already exists$/,
            qr/^.* already has the right .* on .*$/,
            qr/^Invalid value for Name$/,
            qr/^Queue already exists$/,
            qr/^Invalid Name \(names must be unique and may not be all digits\)$/,
        );

        # Avoid reporting this anonymous call frame as the source of the warning
        goto &$warn;
    };

    my $name        = delete $test->{name};
    my $create      = delete $test->{create};
    my $absent      = delete $test->{absent};
    my $present     = delete $test->{present};
    my $raw         = delete $test->{raw};
    my $export_args = delete $test->{export_args};
    fail("Unexpected keys for test #$id ($name): " . join(', ', sort keys %$test)) if keys %$test;

    subtest "$name (ordinary creation)" => sub {
        autorollback(sub {
            $absent->(0) if $absent;
            $create->();
            $present->(0) if $present;
            export_initialdata($directory, %{ $export_args || {} });
        });
    };

    if ($raw) {
        subtest "$name (testing initialdata)" => sub {
            my $file = File::Spec->catfile($directory, "initialdata.json");
            my $content = slurp($file);
            my $json = JSON->new->decode($content);
            $raw->($json, $content);
        };
    }

    subtest "$name (from export-$id/initialdata.json)" => sub {
        autorollback(sub {
            $absent->(1) if $absent;
            import_initialdata($directory);
            $present->(1) if $present;
        });
    };
}

RT::Test::done_testing();

sub autorollback {
    my $code = shift;

    $RT::Handle->BeginTransaction;
    {
        # avoid "Rollback and commit are mixed while escaping nested transaction" warnings
        # due to (begin; (begin; commit); rollback)
        no warnings 'redefine';
        local *DBIx::SearchBuilder::Handle::BeginTransaction = sub {};
        local *DBIx::SearchBuilder::Handle::Commit = sub {};
        local *DBIx::SearchBuilder::Handle::Rollback = sub {};

        $code->();
    }
    $RT::Handle->Rollback;
}

sub export_initialdata {
    my $directory = shift;
    my %args      = @_;
    local @RT::Record::ISA = qw( DBIx::SearchBuilder::Record RT::Base );

    use RT::Migrate::Serializer::JSON;
    my $migrator = RT::Migrate::Serializer::JSON->new(
        Directory          => $directory,
        Verbose            => 0,
        AllUsers           => 0,
        FollowACL          => 1,
        FollowScrips       => 1,
        FollowTransactions => 0,
        FollowTickets      => 0,
        FollowAssets       => 0,
        FollowDisabled     => 0,
        %args,
    );

    $migrator->Export;
}

sub import_initialdata {
    my $directory = shift;
    my $initialdata = File::Spec->catfile($directory, "initialdata.json");

    ok(-e $initialdata, "File $initialdata exists");

    my ($rv, $msg) = RT->DatabaseHandle->InsertData( $initialdata, undef, disconnect_after => 0 );
    ok($rv, "Inserted test data from $initialdata")
        or diag "Error: $msg";
}

sub slurp {
    my $file = shift;
    local $/;
    open (my $f, '<:encoding(UTF-8)', $file)
        or die "Cannot open initialdata file '$file' for read: $@";
    return scalar <$f>;
}
