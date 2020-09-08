use strict;
use warnings;

use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

{
    diag "test creating a group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_contains('Group created', 'found results');
    $m->content_contains('Modify the group test group', 'found title');
}

{
    diag "Add group members" if $ENV{TEST_VERBOSE};
    my $group = RT::Group->new( RT->SystemUser );
    my ($ret, $msg) = $group->LoadUserDefinedGroup('test group');

    $m->get_ok( $url . '/Admin/Groups/Members.html?id=' . $group->Id );
    $m->content_contains('Editing membership for group test group', 'Loaded group members page');
    $m->submit_form_ok({
        form_number => 3,
        fields => { AddMembersUsers => 'root' },
    });
    $m->content_contains('Member added: root', 'Added root to group');

    $m->get_ok( $url . '/Admin/Groups/Members.html?id=' . $group->Id );
    $m->content_contains('Editing membership for group test group', 'Loaded group members page');
    $m->submit_form_ok({
        form_number => 3,
        fields => { AddMembersUsers => 'user1@example.com' },
    });
    $m->content_contains('Member added: user1@example.com', 'Added user1@example.com to group');
}

{
    diag "test creating another group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group2' },
    });
    $m->content_contains('Group created', 'found results');
    $m->content_contains('Modify the group test group2', 'found title');
}

{
    diag "test creating an overlapping group" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/Modify.html?Create=1' );
    $m->content_contains('Create a new group', 'found title');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_contains('Group could not be created', 'found results');
    $m->content_like(qr/Group name .+? is already in use/, 'found message');
}

{
    diag "test updating a group name to overlap" if $ENV{TEST_VERBOSE};
    $m->get_ok( $url . '/Admin/Groups/' );
    $m->follow_link_ok({text => 'test group2'}, 'found title');
    $m->content_contains('Modify the group test group2');
    $m->submit_form_ok({
        form_number => 3,
        fields => { Name => 'test group' },
    });
    $m->content_lacks('Name changed', "name not changed");
    $m->content_contains('Illegal value for Name', 'found error message');
    $m->content_contains('test group', 'did not find new name');
}

{
    diag "Test group searches";
    my @cf_names = qw( CF1 CF2 CF3 );
    my @cfs = ();
    foreach my $cf_name ( @cf_names ) {
        my $cf = RT::CustomField->new( RT->SystemUser );
        my ( $id, $msg ) = $cf->Create(
            Name => $cf_name,
            TypeComposite => 'Freeform-1',
            LookupType => RT::Group->CustomFieldLookupType,
        );
        ok( $id, $msg );
        # Create a global ObjectCustomField record
        my $object = $cf->RecordClassFromLookupType->new( RT->SystemUser );
        ( $id, $msg ) = $cf->AddToObject( $object );
        ok( $id, $msg );
        push ( @cfs, $cf );
    }
    my $cf_1 = $cfs[0];
    my $cf_2 = $cfs[1];
    my $cf_3 = $cfs[2];

    my @group_names = qw( Group1 Group2 Group3 Group4 );
    my @groups = ();
    foreach my $group_name ( @group_names ) {
        my $group = RT::Group->new( RT->SystemUser );
        my ( $id, $msg ) = $group->CreateUserDefinedGroup( Name => $group_name );
        ok ( $id, $msg.': '.$group_name );
        push ( @groups, $group );
    }
    $groups[0]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );

    $groups[1]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );
    $groups[1]->AddCustomFieldValue( Field => $cf_2->id, Value => 'two' );

    $groups[2]->AddCustomFieldValue( Field => $cf_1->id, Value => 'one' );
    $groups[2]->AddCustomFieldValue( Field => $cf_2->id, Value => 'two' );
    $groups[2]->AddCustomFieldValue( Field => $cf_3->id, Value => 'three' );

    $m->get_ok( $url . '/Admin/Groups/index.html' );
    ok( $m->form_name( 'GroupsAdmin' ), 'found the filter admin groups form');
    $m->select( GroupField => 'Name', GroupOp => 'LIKE' );
    $m->field( GroupString => 'Group' );
    $m->select( GroupField2 => 'CustomField: '.$cf_1->Name, GroupOp2 => 'LIKE' );
    $m->field( GroupString2 => 'one' );
    $m->select( GroupField3 => 'CustomField: '.$cf_2->Name, GroupOp3 => 'LIKE' );
    $m->field( GroupString3 => 'two' );
    $m->click( 'Go' );

    diag "Verify results contain Groups 2 & 3, but not 1 & 4";
    $m->content_contains( $groups[1]->Name );
    $m->content_contains( $groups[2]->Name );
    $m->content_lacks( $groups[0]->Name );
    $m->content_lacks( $groups[3]->Name );

    diag 'Test NULL value searches';
    ok( $m->form_name( 'GroupsAdmin' ), 'found the filter admin groups form');
    $m->select( GroupField => 'Name', GroupOp => 'LIKE' );
    $m->field( GroupString => 'Group' );
    $m->select( GroupField2 => 'CustomField: '.$cf_2->Name, GroupOp2 => 'is' );
    $m->field( GroupString2 => 'NULL' );
    $m->field( GroupString3 => '' );
    $m->click( 'Go' );
    $m->text_lacks( $_->Name ) for @groups[1..2];
    $m->text_contains( $_->Name ) for @groups[0,3];

    ok( $groups[0]->SetDescription('group1') );
    $m->form_name( 'GroupsAdmin' );
    $m->select( GroupField2 => 'Description', GroupOp2 => 'is' );
    $m->field( GroupString2 => 'NULL' );
    $m->click( 'Go' );
    $m->text_lacks( $_->Name ) for $groups[0];
    $m->text_contains( $_->Name ) for @groups[1..3];
}

{
    diag "Delete group members" if $ENV{TEST_VERBOSE};
    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup('test group');

    my $root = RT::User->new( RT->SystemUser );
    $root->Load('root');
    $m->get_ok( $url . '/Admin/Groups/Members.html?id=' . $group->Id );
    $m->content_contains( 'Editing membership for group test group', 'Loaded group members page' );

    $m->form_number(3);
    $m->tick( 'DeleteMember-' . $root->Id, 1 );
    $m->submit_form_ok( {}, 'Delete "root" from group' );
    $m->content_contains( 'Member deleted', 'Deleted "root" from group' );
    $m->content_lacks( 'DeleteMember-' . $root->Id );

    $m->submit_form_ok(
        {   form_number => 3,
            fields      => { AddMembersGroups => 'test group2' },
        },
        'Add "test group2" to group',
    );
    $m->content_contains( 'Member added: test group2', 'Added "test group2" to group' );

    my $group2 = RT::Group->new( RT->SystemUser );
    $group2->LoadUserDefinedGroup('test group2');

    $m->form_number(3);
    $m->tick( 'DeleteMember-' . $group2->Id, 1 );
    $m->submit_form_ok( {}, 'Delete "test group2" from group' );
    $m->content_contains( 'Member deleted', 'Deleted "test group2" from group' );
    $m->content_lacks( 'DeleteMember-' . $group2->Id );
}

done_testing;
