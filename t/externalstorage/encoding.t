use strict;
use warnings;

use RT;
use RT::Test::ExternalStorage tests => undef;
RT->Config->Set( ExternalStorageCutoffSize => 1 );

my $queue = RT::Test->load_or_create_queue(Name => 'General');

my $non_english_text = Encode::decode("UTF-8",'Příliš žluťoučký kůň pěl ďábelské ódy');

my $message = MIME::Entity->build(
    From     => 'root@localhost',
    Subject  => 'test',
    Charset  => 'UTF-8',
    Encoding => 'quoted-printable',
    Type     => 'text/plain',
    Data     => Encode::encode('UTF-8', $non_english_text),
);

my $ticket = RT::Ticket->new( RT->SystemUser );
my ($id) = $ticket->Create(
    Queue => $queue,
    Subject => 'test',
    MIMEObj => $message,
);

ok $id, 'created a ticket';

my @attachments = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };
is scalar @attachments, 1, "Found one attachment";
is $attachments[0]->ContentType, "text/plain", "Found the text part";
is $attachments[0]->Content, $non_english_text, "Can get the text part content";

ok !system('sbin/rt-externalize-attachments'), "rt-externalize-attachments ran successfully";

@attachments = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };
is scalar @attachments, 1, "Found one attachment";
is $attachments[0]->ContentType, "text/plain", "Found the text part";
is $attachments[0]->Content, $non_english_text, "Can still get the text part content";
is $attachments[0]->ContentEncoding, "external", "Content is external";

done_testing();
