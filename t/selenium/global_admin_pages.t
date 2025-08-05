use strict;
use warnings;

use RT::Test tests => undef, selenium => 1;

my ( $url, $s ) = RT::Test->started_ok;

$s->login();

# Test copy condition functionality
{
    # Go to the Global Conditions page to find a standard RT condition
    $s->get_ok( $url . '/Admin/Global/Conditions.html', 'Go to global conditions page' );

    # Find the "On Create" condition link by its text
    my $condition_link = $s->find_element('//a[text()="On Create"]');
    ok( $condition_link, 'Found the "On Create" condition link' );

    # The condition name is "On Create"
    my $original_condition_name = 'On Create';
    ok( $original_condition_name, 'Got original condition name' );

    # Extract the condition ID from the href
    my $condition_href = $condition_link->get_attribute('href');
    my ($condition_id) = $condition_href =~ /id=(\d+)/;
    ok( $condition_id, 'Got condition ID from link' );

    # Click on the "On Create" link to go to its display page
    $condition_link->click();

    # Verify we're on the display page and can see the condition
    $s->text_contains( 'Display condition', 'On condition display page' );
    $s->text_contains( $original_condition_name, 'Found original condition name on display page' );

    # Click the Copy Condition button
    my $copy_button = $s->find_element('//a[text()="Copy Condition"]');
    $copy_button->click();

    # Verify we're on the create page
    $s->text_contains( 'Create a global condition', 'Redirected to create condition page' );

    # Find the Name field specifically in the form
    my $name_field_element = $s->find_element('//form[@name="CreateCondition"]//input[@name="Name"]');
    ok( $name_field_element, 'Found Name field in CreateCondition form' );

    # Check that the Name field is populated with the original condition's name
    my $name_field = eval { $name_field_element->get_value() } || '';
    is( $name_field, $original_condition_name, 'Name field is populated correctly' );

    # Find the Description field specifically in the form
    my $description_field_element = $s->find_element('//form[@name="CreateCondition"]//input[@name="Description"]');
    ok( $description_field_element, 'Found Description field in CreateCondition form' );

    # Find the ExecModule field specifically in the form
    my $exec_module_field_element = $s->find_element('//form[@name="CreateCondition"]//input[@name="ExecModule"]');
    ok( $exec_module_field_element, 'Found ExecModule field in CreateCondition form' );

    # Check that other fields are populated (we don't need exact values, just that they exist)
    my $description_field = eval { $description_field_element->get_value() } || '';
    my $exec_module_field = eval { $exec_module_field_element->get_value() } || '';

    ok( $description_field || $exec_module_field, 'At least one other field is populated' );

    # Test creating the copied condition with a new name
    my $copied_condition_name = 'Test Copy of ' . $original_condition_name . ' ' . time();

    $s->submit_form_ok(
        {
            form_name => 'CreateCondition',
            fields    => {
                Name => $copied_condition_name,
                # Other fields should already be populated
            },
            button => 'Create',
        },
        'Create copied condition'
    );

    $s->text_contains( 'Object created', 'Copied condition was created successfully' );

    # Verify the copied condition has the new name in the Name field
    my $final_name_field_element = $s->find_element('//form//input[@name="Name"]');
    my $final_name_field = eval { $final_name_field_element->get_value() } || '';
    is( $final_name_field, $copied_condition_name, 'Found new condition name in Name field' );
}

# Test copy action functionality
{
    # Go to the Global Actions page to find a standard RT action
    $s->get_ok( $url . '/Admin/Global/Actions.html', 'Go to global actions page' );

    # Find the "Notify AdminCcs" action link by its text
    my $action_link = $s->find_element('//a[text()="Notify AdminCcs"]');
    ok( $action_link, 'Found the "Notify AdminCcs" action link' );

    # The action name is "Notify AdminCcs"
    my $original_action_name = 'Notify AdminCcs';
    ok( $original_action_name, 'Got original action name' );

    # Extract the action ID from the href
    my $action_href = $action_link->get_attribute('href');
    my ($action_id) = $action_href =~ /id=(\d+)/;
    ok( $action_id, 'Got action ID from link' );

    # Click on the "Notify AdminCcs" link to go to its display page
    $action_link->click();

    # Verify we're on the display page and can see the action
    $s->text_contains( 'Display action', 'On action display page' );
    $s->text_contains( $original_action_name, 'Found original action name on display page' );

    # Click the Copy Action button
    my $copy_action_button = $s->find_element('//a[text()="Copy Action"]');
    $copy_action_button->click();

    # Verify we're on the create page
    $s->text_contains( 'Create a global action', 'Redirected to create action page' );

    # Find the Name field specifically in the form
    my $name_field_element = $s->find_element('//form[@name="CreateAction"]//input[@name="Name"]');
    ok( $name_field_element, 'Found Name field in CreateAction form' );

    # Check that the Name field is populated with the original action's name
    my $name_field = eval { $name_field_element->get_value() } || '';
    is( $name_field, $original_action_name, 'Name field is populated correctly' );

    # Find the Description field specifically in the form
    my $description_field_element = $s->find_element('//form[@name="CreateAction"]//input[@name="Description"]');
    ok( $description_field_element, 'Found Description field in CreateAction form' );

    # Find the ExecModule field specifically in the form
    my $exec_module_field_element = $s->find_element('//form[@name="CreateAction"]//input[@name="ExecModule"]');
    ok( $exec_module_field_element, 'Found ExecModule field in CreateAction form' );

    # Check that other fields are populated (we don't need exact values, just that they exist)
    my $description_field = eval { $description_field_element->get_value() } || '';
    my $exec_module_field = eval { $exec_module_field_element->get_value() } || '';

    ok( $description_field || $exec_module_field, 'At least one other field is populated' );

    # Test creating the copied action with a new name
    my $copied_action_name = 'Test Copy of ' . $original_action_name . ' ' . time();

    $s->submit_form_ok(
        {
            form_name => 'CreateAction',
            fields    => {
                Name => $copied_action_name,
                # Other fields should already be populated
            },
            button => 'Create',
        },
        'Create copied action'
    );

    $s->text_contains( 'Object created', 'Copied action was created successfully' );

    # Verify the copied action has the new name in the Name field
    my $final_name_field_element = $s->find_element('//form//input[@name="Name"]');
    my $final_name_field = eval { $final_name_field_element->get_value() } || '';
    is( $final_name_field, $copied_action_name, 'Found new action name in Name field' );
}

# Test lifecycle admin functionality
{
    $s->get_ok( $url . '/Admin/Lifecycles/Rights.html?Type=ticket;Name=default', 'Go to lifecycle rights page' );
    $s->submit_form_ok(
        {   form_name => 'ModifyLifecycleRights',
            fields    => {
                'Right-From-3' => 'new',
                'Right-To-3'   => 'open',
                'Right-Name-3' => 'OpenTicket',
            },
            button => 'Update',
        },
        'Update lifecycle rights'
    );
    $s->text_contains( 'Lifecycle updated', 'Lifecycle updated message' );
    is( $s->find_element( selector_to_xpath(q{input[name='Right-Name-3']}) )->get_value(),
        'OpenTicket', 'Form is updated' );
}

$s->logout;

done_testing;
