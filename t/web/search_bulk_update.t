use strict;
use warnings;

use RT::Test tests => 46;
my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

my $rtname = RT->Config->Get('rtname');

# create tickets
use RT::Ticket;

my ( @link_tickets, @search_tickets );
for ( 1 .. 3 ) {
    my $link_ticket = RT::Ticket->new(RT->SystemUser);
    my ( $ret, $msg ) = $link_ticket->Create(
        Subject   => "link ticket $_",
        Queue     => 'general',
        Owner     => 'root',
        Requestor => 'root@localhost',
    );
    ok( $ret, "link ticket created: $msg" );
    push @link_tickets, $ret;
}

for ( 1 .. 3 ) {
    my $ticket = RT::Ticket->new(RT->SystemUser);
    my ( $ret, $msg ) = $ticket->Create(
        Subject   => "search ticket $_",
        Queue     => 'general',
        Owner     => 'root',
        Requestor => 'root@localhost',
    );
    ok( $ret, "search ticket created: $msg" );
    push @search_tickets, $ret;
}

# let's add link to 1 search ticket first
$m->get_ok( $url . "/Search/Bulk.html?Query=id=$search_tickets[0]&Rows=10" );
$m->content_contains( 'Current Links', 'has current links part' );
$m->content_lacks( 'DeleteLink--', 'no delete link stuff' );
$m->submit_form(
    form_name => 'BulkUpdate',
    fields      => {
        'Ticket-DependsOn' => $link_tickets[0],
        'Ticket-MemberOf'  => $link_tickets[1],
        'Ticket-RefersTo'  => $link_tickets[2],
    },
);
$m->content_contains(
    "Ticket $search_tickets[0] depends on Ticket $link_tickets[0]",
    'depends on msg',
);
$m->content_contains(
    "Ticket $search_tickets[0] member of Ticket $link_tickets[1]",
    'member of msg',
);
$m->content_contains(
    "Ticket $search_tickets[0] refers to Ticket $link_tickets[2]",
    'refers to msg',
);

$m->content_contains(
    "DeleteLink--DependsOn-fsck.com-rt://$rtname/ticket/$link_tickets[0]",
    'found depends on link' );
$m->content_contains(
    "DeleteLink--MemberOf-fsck.com-rt://$rtname/ticket/$link_tickets[1]",
    'found member of link' );
$m->content_contains(
    "DeleteLink--RefersTo-fsck.com-rt://$rtname/ticket/$link_tickets[2]",
    'found refers to link' );

# here we check the *real* bulk update
my $query = join ' OR ', map { "id=$_" } @search_tickets;
$m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );
$m->content_contains( 'Current Links', 'has current links part' );
$m->content_lacks( 'DeleteLink--', 'no delete link stuff' );

$m->form_name('BulkUpdate');
my @fields = qw/Owner AddRequestor DeleteRequestor AddCc DeleteCc AddAdminCc
DeleteAdminCc Subject Priority Queue Status Starts_Date Told_Date Due_Date
UpdateSubject/;
for my $field ( @fields ) {
    is( $m->value($field), '', "default $field is empty" );
}

like( $m->value('UpdateContent'), qr/^\s*$/, "default UpdateContent is effectively empty" );

# test DependsOn, MemberOf and RefersTo
$m->submit_form(
    form_name => 'BulkUpdate',
    fields      => {
        'Ticket-DependsOn' => $link_tickets[0],
        'Ticket-MemberOf'  => $link_tickets[1],
        'Ticket-RefersTo'  => $link_tickets[2],
    },
);

$m->content_contains(
    "DeleteLink--DependsOn-fsck.com-rt://$rtname/ticket/$link_tickets[0]",
    'found depends on link' );
$m->content_contains(
    "DeleteLink--MemberOf-fsck.com-rt://$rtname/ticket/$link_tickets[1]",
    'found member of link' );
$m->content_contains(
    "DeleteLink--RefersTo-fsck.com-rt://$rtname/ticket/$link_tickets[2]",
    'found refers to link' );

$m->submit_form(
    form_name => 'BulkUpdate',
    fields      => {
        "DeleteLink--DependsOn-fsck.com-rt://$rtname/ticket/$link_tickets[0]" =>
          1,
        "DeleteLink--MemberOf-fsck.com-rt://$rtname/ticket/$link_tickets[1]" =>
          1,
        "DeleteLink--RefersTo-fsck.com-rt://$rtname/ticket/$link_tickets[2]" =>
          1,
    },
);

$m->content_lacks( 'DeleteLink--', 'links are all deleted' );

# test DependedOnBy, Members and ReferredToBy

$m->submit_form(
    form_name => 'BulkUpdate',
    fields      => {
        'DependsOn-Ticket' => $link_tickets[0],
        'MemberOf-Ticket'  => $link_tickets[1],
        'RefersTo-Ticket'  => $link_tickets[2],
    },
);

$m->content_contains(
    "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[0]-DependsOn-",
    'found depended on link' );
$m->content_contains(
    "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[1]-MemberOf-",
    'found members link' );
$m->content_contains(
    "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[2]-RefersTo-",
    'found referrd to link' );

$m->submit_form(
    form_name => 'BulkUpdate',
    fields      => {
        "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[0]-DependsOn-" =>
          1,
        "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[1]-MemberOf-" =>
          1,
        "DeleteLink-fsck.com-rt://$rtname/ticket/$link_tickets[2]-RefersTo-" =>
          1,
    },
);
$m->content_lacks( 'DeleteLink--', 'links are all deleted' );

