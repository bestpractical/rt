use strict;
use warnings;

use RT::Test tests => undef, actual_server => 1;

# we can't simply call Encode::HanExtra->require here because we are testing
# if Encode::HanExtra could be automatically loaded.
plan skip_all => 'Encode::HanExtra required' if system $^X, '-MEncode::HanExtra', '-e1';

my ( $baseurl, $m ) = RT::Test->started_ok;

{
    my $gb18030_ticket_email =
      RT::Test::get_relocatable_file( 'new-ticket-from-gb18030', ( File::Spec->updir(), 'data', 'emails' ) );
    my $content = RT::Test->file_content( $gb18030_ticket_email );

    my ( $status, $id ) = RT::Test->send_via_mailgate_and_http( $content );
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket" );

    my $ticket = RT::Ticket->new( RT->SystemUser );
    $ticket->Load( $id );
    ok( $ticket->id, 'loaded ticket' );

    my $txns = $ticket->Transactions;
    $txns->Limit( FIELD => 'Type', VALUE => 'Create' );
    my $attachment     = $txns->First->Attachments->First;
    my $encode_headers = $attachment->EncodedHeaders( 'gb18030' );
    is( $encode_headers, Encode::encode( 'gb18030', $attachment->Headers ) );
}

done_testing;
