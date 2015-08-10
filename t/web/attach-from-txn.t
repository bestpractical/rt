use strict;
use warnings;

use RT::Test tests => 70;

my $LogoName    = 'image.png';
my $ImageName   = 'owls.jpg';
my $LogoFile    = RT::Test::get_relocatable_file($LogoName, '..', 'data');
my $ImageFile   = RT::Test::get_relocatable_file($ImageName, '..', 'data');

# reply to ticket = nothing
# reply to correspond = getting the right list
# maintaining the checked ones
# storing the header
# getting attached to mail
# showing up in the web history

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Queue->new(RT->Nobody);
my $qid = $queue->Load('General');
ok( $qid, "Loaded General queue" );

# Create ticket
$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->field('Requestors', 'owls@localhost');
$m->submit;
is($m->status, 200, "request successful");
$m->content_contains("Create a new ticket", 'ticket create page');

$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_contains('Attachments test', 'we have subject on the page');
$m->content_contains('Some content', 'and content');

# Reply with uploaded attachments
$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->content_lacks('AttachExisting');
$m->form_name('TicketUpdate');
$m->field('Attach', $LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form_name('TicketUpdate');
$m->field('Attach', $ImageFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_contains("Download $LogoName", 'page has file name');
$m->content_contains("Download $ImageName", 'page has file name');

# clear mail catcher
RT::Test->fetch_caught_mails;

# Reply to first correspondence, including an attachment
$m->follow_link_ok({text => 'Reply', n => 3}, "reply to the reply");
$m->content_contains('AttachExisting');
$m->content_contains($LogoName);
$m->content_contains($ImageName);
# check stuff
$m->form_name('TicketUpdate');
$m->current_form->find_input('AttachExisting', 'checkbox', 2)->check; # owls.jpg
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

# ensure it's still checked
$m->form_name('TicketUpdate');
ok $m->current_form->find_input('AttachExisting', 'checkbox', 2)->value, 'still checked';
$m->field('UpdateContent', 'Here are some attachments');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

# yep, we got it and processed the header!
$m->content_contains('Here are some attachments');
$m->content_like(qr/RT-Attach:.+?\Q$ImageName\E/s, 'found rt attach header');

# outgoing looks good
$m->follow_link_ok({text => 'Show', n => 3}, "found show link");
$m->content_like(qr/RT-Attach: \d+/, "found RT-Attach header");
$m->content_like(qr/RT-Attachment: \d+\/\d+\/\d+/, "found RT-Attachment header");
$m->content_lacks($ImageName);
$m->back;

# check that it got into mail
my @mails = RT::Test->fetch_caught_mails;
is scalar @mails, 1, "got one outgoing email";
my $mail = shift @mails;
like $mail, qr/To: owls\@localhost/, 'got To';
like $mail, qr/RT-Attach: \d+/, "found attachment we expected";
like $mail, qr/RT-Attachment: \d+\/\d+\/\d+/, "found RT-Attachment header";
like $mail, qr/filename=.?\Q$ImageName\E.?/, "found filename";

# Reply to first correspondence, including an attachment with an uploaded one
$m->follow_link_ok({text => 'Reply', n => 3}, "reply to the reply");
$m->form_name('TicketUpdate');
$m->current_form->find_input('AttachExisting', 'checkbox', 2)->check; # owls.jpg
$m->field( 'UpdateContent', 'attachments from both list and upload' );
$m->field('Attach', $LogoFile);
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

# yep, we got it and processed the header!
$m->content_contains('attachments from both list and upload');
$m->content_like(qr/(RT-Attach:.+?\Q$ImageName\E).*\1/s, 'found rt attach header');
$m->content_like(qr/Subject:.+?\Q$LogoName\E/s, 'found rt attach header');

# outgoing looks good
$m->follow_link_ok({text => 'Show', n => 4}, "found show link");
$m->content_like(qr/RT-Attach: \d+/, "found RT-Attach header");
$m->content_like(qr/RT-Attachment: \d+\/\d+\/\d+/, "found RT-Attachment header");
$m->content_lacks($ImageName);
$m->content_lacks($LogoName);
$m->back;

# check that it got into mail
@mails = RT::Test->fetch_caught_mails;
is scalar @mails, 1, "got one outgoing email";
$mail = shift @mails;
like $mail, qr/To: owls\@localhost/, 'got To';
like $mail, qr/RT-Attach: \d+/, "found attachment we expected";
like $mail, qr/RT-Attachment: \d+\/\d+\/\d+/, "found RT-Attachment header";
like $mail, qr/filename=.?\Q$ImageName\E.?/, "found selected filename";
like $mail, qr/filename=.?\Q$LogoName\E.?/, "found uploaded filename";

# add header to template, make a normal reply, and see that it worked
my $link = $m->find_link(text_regex => qr/\Q$LogoName\E/, url_regex => qr/Attachment/);
ok $link;
my ($LogoId) = $link->url =~ /Attachment\/\d+\/(\d+)/;
ok $LogoId;
my $template = RT::Template->new( RT->SystemUser );
$template->LoadGlobalTemplate('Correspondence in HTML');
ok $template->Id;
my $old_template = $template->Content;
$template->SetContent( "RT-Attach: $LogoId\n" . $template->Content );
like $template->Content, qr/RT-Attach:/, "updated template";

# reply...
$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->form_name('TicketUpdate');
$m->field('UpdateContent', 'who gives a hoot');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");
$m->content_contains('who gives a hoot');

# then see if we got the right mail
@mails = RT::Test->fetch_caught_mails;
is scalar @mails, 1, "got one outgoing email";
$mail = shift @mails;
like $mail, qr/To: owls\@localhost/, 'got To';
like $mail, qr/RT-Attach: $LogoId/, "found attachment we expected";
like $mail, qr/RT-Attachment: \d+\/\d+\/$LogoId/, "found RT-Attachment header";
like $mail, qr/filename=.?\Q$LogoName\E.?/, "found filename";

# create a new, privileged user who can't see this ticket but can reply
$template->SetContent($old_template);
unlike $template->Content, qr/RT-Attach:/, "no header in template anymore";

my $peter = RT::Test->load_or_create_user(
    Name            => 'peter',
    EmailAddress    => 'peter@localhost',
);
ok( RT::Test->add_rights({ Principal => 'Everyone', Right => [qw(ReplyToTicket)] }), 'add ReplyToTicket rights');

my $ticket = RT::Ticket->new($peter);
$ticket->Load(1);
ok $ticket->Id, "loaded ticket";

my ($ok, $msg, $txn) = $ticket->Correspond( AttachExisting => $LogoId, Content => 'Hi' );
ok $ok, $msg;

# check mail that went out doesn't contain the logo
@mails = RT::Test->fetch_caught_mails;
is scalar @mails, 1, "got one outgoing email";
$mail = shift @mails;
like $mail, qr/RT-Attach: $LogoId/, "found header we expected";
unlike $mail, qr/RT-Attachment: \d+\/\d+\/$LogoId/, "lacks RT-Attachment header";
unlike $mail, qr/filename=.?\Q$LogoName\E.?/, "lacks filename";
