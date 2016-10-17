use strict;
use warnings;

use RT;
use RT::Test::ExternalStorage tests => undef;
RT->Config->Set( ExternalStorageCutoffSize => 1 );

my $queue = RT::Test->load_or_create_queue(Name => 'General');
ok $queue && $queue->id;

my $non_english_text = 'Příliš žluťoučký kůň pěl ďábelské ódy';

my $message = MIME::Entity->build(
    From     => 'root@localhost',
    Subject  => 'test',
		Charsert => 'UTF-8',
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

my @attachs = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };

is $attachs[0]->ContentType, "text/plain", "Found the text part";
is $attachs[0]->Content, $non_english_text, "Can get the text part content";
is $attachs[0]->ContentEncoding, "quoted-printable", "Content is not external";

my $dir = RT::Test::ExternalStorage->attachments_dir;
ok !<$dir/*>, "Attachments directory is empty";

ok -e 'sbin/rt-externalize-attachments', "Found rt-externalize-attachments script";
ok -x 'sbin/rt-externalize-attachments', "rt-externalize-attachments is executable";
ok !system('sbin/rt-externalize-attachments'), "rt-externalize-attachments ran successfully";

@attachs = @{ $ticket->Transactions->First->Attachments->ItemsArrayRef };
is $attachs[0]->Content, $non_english_text, "Can still get the text part content";
is $attachs[0]->ContentEncoding, "external", "Content is external";

ok <$dir/*>, "Attachments directory contains files";

done_testing();
