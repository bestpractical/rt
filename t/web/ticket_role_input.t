use strict;
use warnings;

use RT::Test tests => undef;

# having this set overrides checking against individual configured addresses,
# and the Test default value can't match something that also looks like an email address
RT->Config->Set('RTAddressRegexp', undef);
is( RT->Config->Get('RTAddressRegexp'), undef, 'global RTAddressRegexp is not set');

RT->Config->Set('CommentAddress', 'rt-comment@example.com');
is( RT->Config->Get('CommentAddress'), 'rt-comment@example.com', 'global comment address set');

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

# test the success cases

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
            button => 'SubmitTicket',
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

    $m->follow_link_ok( { url_regex => qr/ShowEmailRecord/ }, 'get the outgoing email page' );
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

# make sure that any warnings from the preceeding (which shouldn't happen) don't affect the tests that follow
$m->no_warnings_ok;

# test the failure cases
ok( $queue->SetCorrespondAddress('rt-general@example.com'), 'Set queue correspond address' );

diag "Test ticket create page (failures)";
{
    $m->goto_create_ticket( $queue );
    $m->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => {
                Subject    => 'test input errors on create',
                Content    => 'test content',
                Requestors => 'sybil, group:think, rt-general@example.com, rt-comment@example.com',
                Cc         => 'sybil, group:think, rt-general@example.com, rt-comment@example.com',
                AdminCc    => 'sybil, group:think, rt-general@example.com, rt-comment@example.com',
            },
            button => 'SubmitTicket',
        },
        'submit form TicketCreate'
    );

    $m->next_warning_like( qr/^Couldn't load (?:user from value sybil|group from value group:think), Couldn't find row$/, 'found expected warning' ) for 1 .. 6;

    foreach my $role (qw(Requestor Cc AdminCc)) {
        $m->text_like( qr/Couldn't add 'sybil' as $role/,       "expected user warning: sybil $role"       );
        $m->text_like( qr/Couldn't add 'group:think' as $role/, "expected user warning: group:think $role" );

        $m->text_like( qr/rt-general\@example.com is an address RT receives mail at. Adding it as a '$role' would create a mail loop/, "expected user warning: rt-general\@example.com $role" );
        $m->text_like( qr/rt-comment\@example.com is an address RT receives mail at. Adding it as a '$role' would create a mail loop/, "expected user warning: rt-comment\@example.com $role" );
    }
}

diag "Test ticket update page (failures)";
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
                UpdateCc      => 'sybil, group:think, rt-general@example.com, rt-comment@example.com',
                UpdateBcc     => 'sybil, group:think, rt-general@example.com, rt-comment@example.com',
            },
            button => 'SubmitTicket',
        },
        'submit form TicketCreate'
    );

    $m->next_warning_like( qr/^Couldn't load (?:user from value sybil|group from value group:think), Couldn't find row$/, 'found expected warning' ) for 1 .. 4;

    foreach my $role (qw(Cc Bcc)) {
        $m->text_like( qr/Couldn't add 'sybil' to 'One-time $role'/,       "expected user warning: sybil $role"       );
        $m->text_like( qr/Couldn't add 'group:think' to 'One-time $role'/, "expected user warning: group:think $role" );

        $m->text_like( qr/rt-general\@example.com is an address RT receives mail at. Adding it as a 'One-time $role' would create a mail loop/, "expected user warning: rt-general\@example.com $role" );
        $m->text_like( qr/rt-comment\@example.com is an address RT receives mail at. Adding it as a 'One-time $role' would create a mail loop/, "expected user warning: rt-comment\@example.com $role" );
    }
}


done_testing;
