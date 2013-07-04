use strict;
use warnings;

use RT::Test tests => 18;

RT->Config->Set( MasonLocalComponentRoot => RT::Test::get_abs_relocatable_dir('html') );

my ($baseurl, $m) = RT::Test->started_ok;

my $queue = RT::Queue->new(RT->SystemUser);
$queue->Load('General');

my $class = RT::Class->new(RT->SystemUser);
my ($ok, $msg) = $class->Create(Name => "issues");
ok($ok, "created class: $msg");

($ok, $msg) = $class->AddToObject($queue);
ok($ok, "applied class to General: $msg");

my $article = RT::Article->new(RT->SystemUser);
($ok, $msg) = $article->Create(Name => "instance of ticket #17421", Class => $class->id);
ok($ok, "created article: $msg");

ok($m->login, "logged in");

my $ticket = RT::Test->create_ticket(Queue => $queue->Id, Subject => 'oh wow! an AUTOLOAD bug');

$m->goto_ticket($ticket->id);
$m->follow_link_ok({text => 'Reply'});

$m->form_name('TicketUpdate');
$m->field('Articles-Include-Article-Named' => $article->Name);
$m->submit;

$m->content_contains('instance of ticket #17421', 'got the name of the article in the ticket');

# delete RT::Article's Name method on the server so we'll need to AUTOLOAD it
my $clone = $m->clone;
$clone->get_ok('/delete-article-name-method.html');
like($clone->content, qr/\{deleted\}/);

$m->form_name('TicketUpdate');
$m->click('SubmitTicket');

$m->follow_link_ok({text => 'Links'});

$m->text_contains('Article #' . $article->id . ': instance of ticket #17421', 'Article appears with its name in the links table');

my $refers_to = $ticket->RefersTo;
is($refers_to->Count, 1, 'the ticket has a refers-to link');
is($refers_to->First->TargetURI->URI, 'fsck.com-article://example.com/article/' . $article->Id, 'when we included the article it created a refers-to');

