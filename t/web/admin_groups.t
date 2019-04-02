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
}


done_testing;
