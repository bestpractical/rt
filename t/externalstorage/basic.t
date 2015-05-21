use strict;
use warnings;

use RT::Extension::ExternalStorage::Test tests => undef;

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok $queue && $queue->id;

my $message = MIME::Entity->build(
    From    => 'root@localhost',
    Subject => 'test',
    Data    => 'test',
);
$message->attach(
    Type     => 'image/special',
    Filename => 'afile.special',
    Data     => 'boo',
);
$message->attach(
    Type     => 'application/octet-stream',
    Filename => 'otherfile.special',
    Data     => 'thing',
);
my $ticket = RT::Ticket->new( RT->SystemUser );
my ($id) = $ticket->Create(
    Queue => $queue,
    Subject => 'test',
    MIMEObj => $message,
);

ok $id, 'created a ticket';

my @attachs = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };
is scalar @attachs, 4, "Contains a multipart and two sub-parts";

is $attachs[0]->ContentType, "multipart/mixed", "Found the top multipart";
ok !$attachs[0]->StoreExternally, "Shouldn't store multipart part on disk";

is $attachs[1]->ContentType, "text/plain", "Found the text part";
is $attachs[1]->Content, 'test', "Can get the text part content";
is $attachs[1]->ContentEncoding, "none", "Content is not encoded";
ok !$attachs[1]->StoreExternally, "Won't store text part on disk";

is $attachs[2]->ContentType, "image/special", "Found the image part";
is $attachs[2]->Content, 'boo',  "Can get the image content";
is $attachs[2]->ContentEncoding, "none", "Content is not encoded";
ok !$attachs[2]->StoreExternally, "Won't store images on disk";

is $attachs[3]->ContentType, "application/octet-stream", "Found the binary part";
is $attachs[3]->Content, 'thing',  "Can get the binary content";
is $attachs[3]->ContentEncoding, "none", "Content is not encoded";
ok $attachs[3]->StoreExternally, "Will store binary data on disk";

my $dir = RT::Extension::ExternalStorage::Test->attachments_dir;
ok !<$dir/*>, "Attachments directory is empty";


ok -e 'sbin/extract-attachments', "Found extract-attachments script";
ok -x 'sbin/extract-attachments', "extract-attachments is executable";
ok !system('sbin/extract-attachments'), "extract-attachments ran successfully";

@attachs = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };
is $attachs[1]->Content, 'test', "Can still get the text part content";
is $attachs[1]->ContentEncoding, "none", "Content is not encoded";

is $attachs[2]->Content, 'boo',  "Can still get the image content";
is $attachs[2]->ContentEncoding, "none", "Content is not encoded";

is $attachs[3]->ContentType, "application/octet-stream", "Found the binary part";
is $attachs[3]->Content, 'thing',  "Can still get the binary content";
isnt $attachs[3]->__Value('Content'), "thing", "Content in database is not the raw content";
is $attachs[3]->ContentEncoding, "external", "Content encoding is 'external'";

ok <$dir/*>, "Attachments directory contains files";

done_testing();
