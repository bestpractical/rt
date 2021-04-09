use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';
my $root = RT::User->new( RT->SystemUser );
ok( $root->Load( 'root' ), 'load root user' );

my $alice = RT::Test->load_or_create_user( Name => 'alice', EmailAddress => 'alice@example.com' );
ok( $alice->id, 'created user alice' );

my $bob = RT::Test->load_or_create_user( Name => 'bob', EmailAddress => 'bob@example.com' );
ok( $bob->id, 'created user bob' );

my $richard = RT::Test->load_or_create_user( Name => 'richard', EmailAddress => 'richard@example.com' );
ok( $richard->id, 'created user richard' );

my $group_foo = RT::Test->load_or_create_group( 'foo' );
ok( $group_foo->id, 'created group foo' );

my $group_admin_user = RT::Test->load_or_create_group( 'admin user' );
ok( $group_admin_user->id, 'created group admin user' );

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok $queue->id, 'loaded queue General';

diag "Test ticket create page";
{
    $m->goto_create_ticket( $queue );
    $m->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => {
                Subject    => 'test inputs on create',
                Content    => 'test content',
                Requestors => 'alice, root@localhost, group:' . $group_foo->id,
                Cc         => 'richard@example.com, ' . $alice->id,
                AdminCc    => 'group:admin user, bob',
            },
        },
        'submit form TicketCreate'
    );
    $m->content_like( qr/Ticket \d+ created/, 'created ticket' );

    my $ticket = RT::Test->last_ticket;
    for my $member ( $root, $alice, $group_foo ) {
        ok( $ticket->Requestor->HasMember( $member->PrincipalObj ), 'Requestor has member ' . $member->Name );
    }

    for my $member ( $alice, $richard ) {
        ok( $ticket->Cc->HasMember( $member->PrincipalObj ), 'Cc has member ' . $member->Name );
    }

    for my $member ( $bob, $group_admin_user ) {
        ok( $ticket->AdminCc->HasMember( $member->PrincipalObj ), 'AdminCc has member ' . $member->Name );
    }
}

diag "Test ticket people page";
{

    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'test inputs on people',
        Content => 'test content',
    );
    $m->goto_ticket( $ticket->id, 'ModifyPeople' );

    $m->submit_form_ok(
        {
            form_name => 'TicketPeople',
            fields    => {
                WatcherTypeEmail1    => 'Requestor',
                WatcherAddressEmail1 => 'alice',
                WatcherTypeEmail2    => 'AdminCc',
                WatcherAddressEmail2 => 'group: foo',
            },
            button => 'SubmitTicket',
        },
        'submit form TicketPeople'
    );

    $m->text_contains( 'Added alice as Requestor for this ticket' );
    $m->text_contains( 'Added foo as AdminCc for this ticket' );

    ok( $ticket->Requestor->HasMember( $alice->PrincipalObj ),   'Requestor has member ' . $alice->Name );
    ok( $ticket->AdminCc->HasMember( $group_foo->PrincipalObj ), 'AdminCc has member ' . $group_foo->Name );
}

diag "Test ticket update page";
{

    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'test inputs on update',
        Content => 'test content',
    );
    $m->goto_ticket( $ticket->id, 'Update' );

    $m->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => {
                UpdateContent => 'test content',
                UpdateCc      => 'alice, bob@example.com',
                UpdateBcc     => 'richard',
            },
            button => 'SubmitTicket',
        },
        'submit form TicketUpdate'
    );
    $m->content_contains('Comments added');

    $m->follow_link_ok( { text => 'Show' }, 'get the outgoing email page' );
    $m->content_contains( 'CC: alice@example.com, bob@example.com' );
    $m->content_contains( 'BCC: richard@example.com' );
}

diag "Test ticket bulk update page";
{

    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'test role inputs on bulk update',
            Content => 'test content',
        },
        ( {} ) x 3
    );

    $m->get_ok( '/Search/Bulk.html?Rows=10&Query=Subject="test role inputs on bulk update"' );
    $m->submit_form_ok(
        {
            form_name => 'BulkUpdate',
            fields    => {
                AddRequestor => 'alice',
                AddAdminCc => 'group: admin user',
            },
        },
        'submit form BulkUpdate'
    );

    $m->text_contains( 'Added alice as Requestor for this ticket' );
    $m->text_contains( 'Added admin user as AdminCc for this ticket' );

    for my $ticket ( @tickets ) {
        ok( $ticket->Requestor->HasMember( $alice->PrincipalObj ), 'Requestor has member ' . $alice->Name );
        ok( $ticket->AdminCc->HasMember( $group_admin_user->PrincipalObj ),
            'AdminCc has member ' . $group_admin_user->Name );
    }

    $m->get_ok( '/Search/Bulk.html?Rows=10&Query=Subject="test role inputs on bulk update"' );
    $m->submit_form_ok(
        {
            form_name => 'BulkUpdate',
            fields    => {
                DeleteRequestor => $alice->id,
                DeleteAdminCc => 'group: ' . $group_admin_user->id,
            },
        },
        'submit form BulkUpdate'
    );
    $m->text_contains( 'admin user is no longer AdminCc for this ticket' );
    for my $ticket ( @tickets ) {
        ok( !$ticket->AdminCc->HasMember( $group_admin_user->PrincipalObj ),
            'AdminCc has no member ' . $group_admin_user->Name );
    }
}

done_testing;
