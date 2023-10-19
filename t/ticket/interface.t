use strict;
use warnings;

use RT::Test tests => undef, config => 'Set($DevelMode, 1);', actual_server => 1;

my ( $baseurl, $m ) = RT::Test->started_ok;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
my $cf    = RT::Test->load_or_create_custom_field( Name => 'Interface', Type => 'FreeformSingle', Queue => $queue->Id );

my $scrip = RT::Scrip->new( RT->SystemUser );
my ( $ret, $msg ) = $scrip->Create(
    Queue             => $queue->id,
    ScripCondition    => 'On Create',
    ScripAction       => 'User Defined',
    CustomPrepareCode => 'return 1',
    CustomCommitCode  => q{
        $self->TicketObj->AddCustomFieldValue( Field => 'Interface', Value => RT->CurrentInterface );
    },
    Template => 'Blank',
);
ok( $ret, $msg );


diag 'Test API interface';
my $ticket = RT::Ticket->new( RT->SystemUser );
( $ret, undef, $msg ) = $ticket->Create( Queue => $queue, Subject => 'Test API interface' );
ok( $ret, $msg );
is( $ticket->FirstCustomFieldValue('Interface'), 'API', 'Interface is set to API' );


diag 'Test CLI interface';
my $template = RT::Template->new( RT->SystemUser );
$template->Create( Name => 'CLICreateTicket', Content => <<'EOF');
===Create-Ticket: test
Queue: General
Subject: Test CLI interface
Content: test
ENDOFCONTENT
EOF

my $root = RT::Test->load_or_create_user( Name => 'root' );
$root->SetGecos( ( getpwuid($<) )[0] );

system(
    "$RT::BinPath/rt-crontool", '--search',      'RT::Search::FromSQL',       '--search-arg',
    "id = " . $ticket->Id,      '--action',      'RT::Action::CreateTickets', '--template',
    $template->Id,              '--transaction', 'first',
) && die $?;

$ticket = RT::Test->last_ticket;
is( $ticket->Subject,                            'Test CLI interface', 'Created ticket via rt-crontool' );
is( $ticket->FirstCustomFieldValue('Interface'), 'CLI',                'Interface is set to CLI' );


diag 'Test Email interface';
my ( $status, $id ) = RT::Test->send_via_mailgate_and_http(<<'EOF');
From: root@localhost
Subject: Test Email interface

Test
EOF
is( $status >> 8, 0, "The mail gateway exited normally" );
ok( $id, "Created ticket" );
$ticket = RT::Test->last_ticket;
is( $ticket->FirstCustomFieldValue('Interface'), 'Email', 'Interface is set to Email' );


diag 'Test Web interface';
ok( $m->login(), 'Logged in' );
$m->goto_create_ticket( $queue->Id );
$m->submit_form( form_name => 'TicketCreate', fields => { Subject => 'Test Web interface' }, button => 'SubmitTicket' );
$ticket = RT::Test->last_ticket;
is( $ticket->FirstCustomFieldValue('Interface'), 'Web', 'Interface is set to Web' );


diag 'Test REST interface';
my $content = "id: ticket/new
Queue: General
Requestor: root
Subject: Test REST interface
Cc:
AdminCc:
Text: Test
";

$m->post(
    "$baseurl/REST/1.0/ticket/new",
    [
        user    => 'root',
        pass    => 'password',
        content => $content,
    ],
    Content_Type => 'form-data'
);

($id) = $m->content =~ /Ticket (\d+) created/;
ok( $id, "Created ticket #$id" );

$ticket->Load($id);
is( $ticket->FirstCustomFieldValue('Interface'), 'REST', 'Interface is set to REST' );

diag 'Test REST2 interface';
require RT::Test::REST2;
my $user = RT::Test::REST2->user;
$user->PrincipalObj->GrantRight( Right => $_ )
    for qw/CreateTicket SeeQueue ShowTicket ModifyCustomField SeeCustomField/;
my $rest2_m = RT::Test::REST2->mech;

my $res = $rest2_m->post_json(
    "/REST/2.0/ticket",
    {
        Subject => 'Test REST2 interface',
        Queue   => 'General',
        Content => 'Test',
    },
    'Authorization' => RT::Test::REST2->authorization_header,
);
is( $res->code, 201 );
ok( ($id) = $res->header('location') =~ qr[/ticket/(\d+)] );
$ticket->Load($id);
is( $ticket->FirstCustomFieldValue('Interface'), 'REST2', 'Interface is set to REST2' );

done_testing;
