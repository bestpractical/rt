use strict;
use warnings;

use RT::Test tests => undef;

my $user = RT::Test->load_or_create_user(
    Name            => 'user1',
    EmailAddress    => 'user1@example.com',
);

ok(
    RT::Test->set_rights(
        { Principal => 'Everyone',  Right => [qw/CreateTicket ReplyToTicket CommentOnTicket/] },
        { Principal => 'Requestor', Right => [qw/ShowTicket/] },
    ),
    'set rights'
);

my $ticket_a = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'ticket A',
        Requestor   => 'user1@example.com',
        Content     => "First ticket",
    );

my $ticket_b = RT::Test->create_ticket(
        Queue       => 'General',
        Subject     => 'ticket b',
        Requestor   => 'user1@example.com',
        Content     => "Second ticket",
    );

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login( 'root', 'password' ), 'logged in as root';

RT::Test->clean_caught_mails;

# AttachTickets is mostly used in RTIR
diag "Submit a comment with attached tickets";

$m->get_ok('/Ticket/Display.html?id=' . $ticket_b->Id);
$m->follow_link_ok({text => "Comment"}, "Followed link to comment");
$m->form_name('TicketUpdate');
$m->field('UpdateCc', 'user1@example.com');
$m->field('UpdateContent', 'some content');
$m->field('AttachTickets', $ticket_a->Id);
$m->click('SubmitTicket');
is( $m->status, 200, "request successful" );

my @mail = RT::Test->fetch_caught_mails;
ok @mail, "got some outgoing emails";

# Match the first occurance of Content-Type in the email. This should be the
# outermost part
$mail[0] =~ /^.*?Content\-Type\: (.*?)\;/sm;
is( $1, 'multipart/mixed', 'Outer message is multipart mixed');

done_testing;
