use utf8;
use strict;
use warnings;

use RT::Test tests => undef;

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
}

done_testing();
