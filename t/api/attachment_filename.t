use strict;
use warnings;
use RT::Test tests => 5;
use MIME::Entity;
my $ticket = RT::Ticket->new(RT->SystemUser);
my $mime   = MIME::Entity->build(
    From => 'test@example.com',
    Type => 'text/html',
    Data => ["test attachment's filename\n"],
);

$mime->attach(
    Path     => 'share/static/images/bpslogo.png',
    Type     => 'image/png',
);

$mime->attach(
    Path     => 'share/static/images/bpslogo.png',
    Type     => 'image/png',
    Filename => 'bpslogo.png',
);

$mime->attach(
    Path     => 'share/static/images/bpslogo.png',
    Filename => 'images/bpslogo.png',
    Type     => 'image/png',
);

my $id = $ticket->Create( MIMEObj => $mime, Queue => 'General' );
ok( $id, "created ticket $id" );

my $atts = RT::Attachments->new( RT->SystemUser );
$atts->Limit( FIELD => 'ContentType', VALUE => 'image/png' );
is( $atts->Count, 3, 'got 3 png files' );

# no matter if mime's filename include path or not,
# we should throw away the path all the time.
while ( my $att = $atts->Next ) {
    is( $att->Filename, 'bpslogo.png', "attachment's filename" );
}

