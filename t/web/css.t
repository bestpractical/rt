use utf8;
use strict;
use warnings;

use RT::Test tests => undef, config =>
    'Set(@HighLightOnCondition,
            { "Attribute" => "Owner", "Value" => "__CurrentUser__", "Color" => "red" },
            { "Attribute" => "Status", "Value" => "open", "Color" => "blue" },
            { "Attribute" => "Queue", "Value" => "General", "Color" => "purple" }
    );';

# Each custom field must have a corresponding class selector with invalid characters escaped
{
    my( $baseurl, $m ) = RT::Test->started_ok;
    ok( $m->login, 'logged in' );

    my $queue = RT::Test->load_or_create_queue( Name => 'General' );

    ok ( $m->goto_create_ticket( $queue ) );
    $m->form_name( 'TicketCreate' );
    $m->field( Subject => 'Test Ticket' );
    $m->submit;

    $m->follow_link_ok( { id => 'admin-custom-fields' } );
    $m->follow_link_ok( { id => 'page-create' } );
    $m->form_name( 'ModifyCustomField' );
    $m->field( 'Name' => 'test class% م 例 name' );
    $m->click( 'Update' );
    my ( $cf_id ) = ( $m->uri =~ /id=(\d+)/ );

    $m->follow_link_ok( { text => 'Applies to' } );
    $m->submit_form_ok( {
        with_fields => {
            "AddCustomField-$cf_id" => 0,
        },
        button => 'UpdateObjs',
    }, 'Added new custom field globally' );

    my $res = $m->get( $baseurl . '/Ticket/Display.html?id=1' );
    my $element = $m->dom->at( ".custom-field-$cf_id" );
    like( $element->attr( 'class' ), qr/test-class-م-例-name/, 'Class selector added to custom field, invalid characters have been escaped' );

    # Test highlighting rows based on a condition
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ($id, $tid, $msg) = $ticket->Create(Queue => 'General', Subject => 'test');
    ok($id, $msg);

    # Test our global level color configs
    $m->get_ok( $baseurl );
    $element = $m->dom->at('tr[class*="row-bg-color-purple"]');
    like( $element->attr( 'class' ), qr/row-bg-color-purple/, 'Successfully apply row color class by global condition for status new');

    $element = $m->dom->at('tr[class*="row-bg-color-blue"]' );
    is ( $element, undef, "Did not apply open status color" );
    $element = $m->dom->at('tr[class*="row-bg-color-red"]');
    is ( $element, undef, "Did not apply CurrentUser owner status color" );

    ($id, $msg) = $ticket->SetOwner( 'root' );
    ok($id, $msg);

    ok( $m->login('root', 'password'), 'logged in' );
    $m->get_ok( $baseurl );

    $element = $m->dom->at('tr[class*="row-bg-color-red"]');
    like( $element->attr( 'class' ), qr/row-bg-color-red/, 'Successfully apply row color class by global condition for Current User');

    ($id, $msg) = $ticket->SetStatus('open');
    ok($id, $msg);

    ($id, $msg) = $ticket->SetOwner( 'NoBody' );
    ok($id, $msg);

    $m->get_ok( $baseurl );

    $element = $m->dom->at('tr[class*="row-bg-color-blue"]');
    like( $element->attr( 'class' ), qr/row-bg-color-blue/, 'Successfully apply row color class by global condition for status open');

    # Test overriding global row highlight options with user preferences
    $m->get_ok( $baseurl . '/Prefs/Other.html' );
    $m->submit_form_ok( {
        form_name => 'ModifyPreferences',
        fields    => {
            "Color-Argument"        => 'open',
            "Color-Argument-Groups" => 'Status',
            "Color"                 => 'green',
        },
        button => 'Update',
    }, 'Set user prefs for color row by condition' );
    $m->get_ok( $baseurl );

    $element = $m->dom->at('tr[class*="row-bg-color-green"]');
    like( $element->attr( 'class' ), qr/row-bg-color-green/, 'Successfully apply row color class by user prefs for status open');

    $element = $m->dom->at('tr[class*="row-bg-color-blue"]');
    is($element, undef, 'Successfully overode global color settings')
}

done_testing();
