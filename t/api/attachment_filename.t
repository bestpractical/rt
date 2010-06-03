use RT::Test tests => 5;
use MIME::Entity;
my $ticket = RT::Ticket->new($RT::SystemUser);
my $mime   = MIME::Entity->build(
    From => 'test@example.com',
    Type => 'text/html',
    Data => ["test attachment's filename\n"],
);

$mime->attach(
    Path     => 'share/html/NoAuth/images/bplogo.gif',
    Type     => 'image/gif',
);

$mime->attach(
    Path     => 'share/html/NoAuth/images/bplogo.gif',
    Type     => 'image/gif',
    Filename => 'bplogo.gif',
);

$mime->attach(
    Path     => 'share/html/NoAuth/images/bplogo.gif',
    Filename => 'images/bplogo.gif',
    Type     => 'image/gif',
);

my $id = $ticket->Create( MIMEObj => $mime, Queue => 'General' );
ok( $id, "created ticket $id" );

my $atts = RT::Attachments->new( $RT::SystemUser );
$atts->Limit( FIELD => 'ContentType', VALUE => 'image/gif' );
is( $atts->Count, 3, 'got 3 gif files' );

# no matter if mime's filename include path or not,
# we should throw away the path all the time.
while ( my $att = $atts->Next ) {
    is( $att->Filename, 'bplogo.gif', "attachment's filename" );
}

