use strict;
use warnings;

use RT::Test tests => undef;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, "logged in";



sub get_rights {
    my $agent = shift;
    my $principal_id = shift;
    my $object = shift;
    my $form_name = shift;

    $agent->form_name($form_name);
    my @inputs = $agent->current_form->find_input("SetRights-$principal_id-$object");
    my @rights = sort grep $_, map $_->possible_values, grep $_ && $_->value, @inputs;
    return @rights;
};

sub test_role {
    my $role_name = shift;
    my $right_name = shift;

    $m->follow_link_ok({ id => 'admin-global-group-rights'});

    diag "load $role_name role group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadRoleGroup( Object => RT->System, Name => $role_name );
    ok($group->id, "loaded '$role_name' role group");

    rights_for_group_ok ( $group, $role_name, $right_name, 'ModifyGroupRights' );
}

sub test_system_internal_group {
    my $group_name = shift;
    my $right_name = shift;

    $m->follow_link_ok({ id => 'admin-global-group-rights'});

    diag "load $group_name group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup($group_name);
    ok($group->id, "loaded '$group_name' system internal group");

    rights_for_group_ok ( $group, $group_name, $right_name, 'ModifyGroupRights' );
}

sub test_user_defined_group {
    my $user_group = shift;
    my $group_name = shift;
    my $right_name = shift;

    my $user_group_id = $user_group->id;
    my $user_group_name = $user_group->Name;

    $m->get_ok("/Admin/Groups/GroupRights.html?id=$user_group_id");

    diag "load $user_group_name group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup($group_name);
    ok($group->id, "loaded '$group_name' system internal group");

    rights_for_group_ok ( $group, $group_name, $right_name, 'ModifyGroupRights', "RT::Group-$user_group_id", $user_group);
}

sub test_user {
    my $user_name = shift;
    my $right_name = shift;

    $m->follow_link_ok({ id => 'admin-global-user-rights'});

    diag "load $user_name";
    my $user = RT::User->new( RT->SystemUser );
    $user->Load($user_name);
    ok($user->id, "loaded user '$user_name'");

    diag "load $user_name group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadACLEquivalenceGroup($user->PrincipalId);
    ok($group->id, "loaded '$user_name' UserEquiv group");

    rights_for_group_ok ( $group, $user_name, $right_name, 'ModifyUserRights' );
}

sub test_system_internal_queue_group {
    my $queue_name = shift;
    my $group_name = shift;
    my $right_name = shift;

    my $queue = RT::Queue->new( RT->SystemUser );
    $queue->Load($queue_name);

    $m->get_ok('/Admin/Queues/GroupRights.html?id=' . $queue->id);

    diag "load $group_name group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadSystemInternalGroup($group_name);
    ok($group->id, "loaded '$group_name' system internal group");

    rights_for_group_ok ( $group, $group_name, $right_name, 'ModifyGroupRights', 'RT::Queue-'.$queue->id, $queue);
}

sub test_system_internal_queue_role {
    my $queue_name = shift;
    my $role_name = shift;
    my $right_name = shift;

    my $queue = RT::Queue->new( RT->SystemUser );
    $queue->Load($queue_name);

    $m->get_ok('/Admin/Queues/GroupRights.html?id=' . $queue->id);

    diag "load $role_name role group";
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadRoleGroup( Object => $queue, Name => $role_name );
    ok($group->id, "loaded '$role_name' role group");

    rights_for_group_ok ( $group, $role_name, $right_name, 'ModifyGroupRights', 'RT::Queue-'.$queue->id, $queue);
}

sub rights_for_group_ok {
    my $group = shift;
    my $group_name = shift;
    my $right_name = shift;
    my $form_name = shift;

    my $html_element_suffix = shift || 'RT::System-1';
    my $right_context_obj = shift || $RT::System;

    my $html_element_id = $group->id;
    # if we have a non-system instance object, use that as the id
    if ($group->InstanceObj && $group->Instance > 1) {
        $html_element_id = $group->Instance;
    }

    my $is_user = $form_name eq 'ModifyUserRights';
    my $is_root_user = $is_user && $group_name eq 'root';

    diag "revoke all global rights from $group_name group";
    my @original_rights = get_rights( $m, $html_element_id, $html_element_suffix, $form_name );

    # this is important because all of the checkbox ids change if we're trying to modify a new user
    my $user_missing_from_list = $is_user && !$is_root_user;

    # We can't remove the SuperUser right from root or else we won't be able to access the admin section
    if ($is_root_user) {
        @original_rights = grep { $_ ne 'SuperUser' } @original_rights;
    }

    if ( @original_rights ) {
        $m->form_name($form_name);

        if ($is_root_user) {
            $m->untick("SetRights-$html_element_id-$html_element_suffix", $_) foreach (@original_rights);
            $m->submit;
            is_deeply([get_rights( $m, $html_element_id, $html_element_suffix, $form_name )], ['SuperUser'], 'deleted all rights but SuperUser' );
        } elsif (not $user_missing_from_list) {
            $m->untick("SetRights-$html_element_id-$html_element_suffix", $_) foreach @original_rights;
            $m->submit;
            is_deeply([get_rights( $m, $html_element_id, $html_element_suffix, $form_name )], [], 'deleted all rights' );
        }
    } else {
        ok(1, 'the group has no global rights');
    }

    diag "grant $right_name right to $group_name group";
    {
        $m->form_name($form_name);

        if ($user_missing_from_list) {
            # we must enter the username into the 'ADD USER' textbox
            $m->field('AddPrincipalForRights-user', $group_name);
            $m->tick("SetRights-addprincipal-$html_element_suffix", $right_name);
            $m->submit;
        } else {
            $m->tick("SetRights-$html_element_id-$html_element_suffix", $right_name);
            $m->submit;
        }

        if ($right_name eq 'AssignCustomFields') {
            print "\n$html_element_id $html_element_suffix\n";
        }

        $m->text_contains("Granted right '$right_name' to $group_name", 'got message');

        RT::Principal::InvalidateACLCache();
        my $rights = $group->PrincipalObj->HasRights( Object => $right_context_obj );
        ok($rights->{$right_name}, 'group has right');
        is_deeply(
            [get_rights( $m, $html_element_id, $html_element_suffix, $form_name )],
            $is_root_user ? [$right_name, 'SuperUser'] : [$right_name],
            "granted $right_name right" );
    }

    diag "revoke the $right_name right from $group_name group";
    {
        $m->form_name($form_name);
        $m->untick("SetRights-$html_element_id-$html_element_suffix", $right_name);
        $m->submit;

        $m->text_contains("Revoked right '$right_name' from $group_name", 'got message');
        RT::Principal::InvalidateACLCache();

        my $rights = $group->PrincipalObj->HasRights( Object => $right_context_obj );
        ok(!$rights->{$right_name}, 'group does not have right');
        is_deeply(
            [get_rights( $m, $html_element_id, $html_element_suffix, $form_name )],
            $is_root_user ? ['SuperUser'] : [],
            "revoked $right_name right" );
    }

    diag "return rights the $group_name group had in the beginning";
    if ( @original_rights ) {
        $m->form_name($form_name);
        $m->tick("SetRights-$html_element_id-$html_element_suffix", $_) for @original_rights;
        $m->submit;

        $m->text_contains("Granted right '$_' to $group_name", 'got message') foreach (@original_rights);
        is_deeply(
            [ get_rights( $m, $html_element_id, $html_element_suffix, $form_name ) ],
            [ @original_rights ],
            'returned back all rights'
        );
    } else {
        ok(1, 'the group had no global rights, so nothing to return');
    }
}

# User rights tests
test_user ( 'root', 'CreateSavedSearch' );

my ($test_user_name, $test_user) = ('rights-test-000', RT::User->new( RT->SystemUser ));
diag "create $test_user_name test user";
$test_user->Create( Name => $test_user_name, Privileged => 1);
test_user ( $test_user_name, 'CreateTicket' );

# Group rights tests
test_system_internal_group ( 'Everyone', 'SuperUser' );
test_system_internal_group ( 'Privileged', 'DeleteTicket' );
test_system_internal_group ( 'Unprivileged', 'Watch' );

# Role rights tests
test_role ( 'AdminCc', 'ModifyACL' );
test_role ( 'Cc', 'DeleteTicket' );
test_role ( 'Owner', 'SeeQueue' );
test_role ( 'Requestor', 'CreateTicket' );

# User-defined group tests
my ($user_group_name, $user_group) = ('rights user group test', RT::Group->new( RT->SystemUser ));
diag "create $user_group_name custom user group";
$user_group->CreateUserDefinedGroup( Name => $user_group_name, Description => '' );

test_user_defined_group ( $user_group, 'Everyone', 'ModifyOwnMembership' );
test_user_defined_group ( $user_group, 'Privileged', 'SeeGroup' );
test_user_defined_group ( $user_group, 'Unprivileged', 'AdminGroup' );

# Queue tests
test_system_internal_queue_group ( 'General', 'Everyone', 'ShowTemplate' );
test_system_internal_queue_group ( 'General', 'Privileged', 'ModifyTicket' );
test_system_internal_queue_group ( 'General', 'Unprivileged', 'Watch' );

test_system_internal_queue_role ( 'General', 'AdminCc', 'AssignCustomFields' );
test_system_internal_queue_role ( 'General', 'Cc', 'ModifyScrips' );
test_system_internal_queue_role ( 'General', 'Owner', 'ForwardMessage' );
test_system_internal_queue_role ( 'General', 'Requestor', 'SeeQueue' );

done_testing;
