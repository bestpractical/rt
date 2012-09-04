use strict;
use warnings;
use RT::Test tests => 170;

my ( $url, $m ) = RT::Test->started_ok;
my $root = RT::Test->load_or_create_user( Name => 'root' );

diag "create another queue";
my $test_queue = RT::Queue->new( $RT::SystemUser );
ok( $test_queue->Create( Name => 'foo' ) );

diag "create cf cfbar";
my $cfbar = RT::CustomField->new( $RT::SystemUser );
ok(
    $cfbar->Create(
        Name       => 'cfbar',
        Type       => 'Freeform',
        LookupType => 'RT::Queue-RT::Ticket'
    )
);

$cfbar->AddToObject( $test_queue );

diag "create some tickets to link";
# yep, create 3 tickets for DependsOn
my @tickets = map { { Subject => "link of $_" } }
  qw/DependsOn DependsOn DependsOn DependedOnBy HasMember HasMember
  MemberOf RefersTo RefersTo ReferredToBy/;
RT::Test->create_tickets( { Status => 'resolved' },  @tickets );

diag "test different mobile agents";
my @agents = (
    'hiptop',       'Blazer',     'Novarra',  'Vagabond',
    'SonyEricsson', 'Symbian',    'NetFront', 'UP.Browser',
    'UP.Link',      'Windows CE', 'MIDP',     'J2ME',
    'DoCoMo',       'J-PHONE',    'PalmOS',   'PalmSource',
    'iPhone',       'iPod',       'AvantGo',  'Nokia',
    'Android',      'WebOS',      'S60'
);

for my $agent (@agents) {
    $m->agent($agent);
    $m->get_ok($url);
    $m->content_contains( 'Not using a mobile browser',
        "mobile login page for agent $agent" );
}

$m->submit_form( fields => { user => 'root', pass => 'password' } );
is( $m->uri, $url . '/m/', 'logged in via mobile ui' );
ok( $m->find_link( text => 'Home' ), 'has homepage link, so really logged in' );

diag "create some tickets";
$m->follow_link_ok( { text => 'New ticket' } );
like( $m->uri, qr'/m/ticket/select_create_queue', 'queue select page' );
$m->follow_link_ok( { text => 'General' } );
like( $m->uri, qr'/m/ticket/create', 'ticket create page' );
$m->submit_form(
    fields => {
        Subject                   => 'ticket1',
        Content                   => 'content 1',
        Status                    => 'open',
        Cc                        => 'cc@example.com',
        AdminCc                   => 'admincc@example.com',
        InitialPriority           => 13,
        FinalPriority             => 93,
        TimeEstimated             => 2,
        'TimeEstimated-TimeUnits' => 'hours',
        TimeWorked                => 30,
        TimeLeft                  => 60,
        Starts                    => '2011-01-11 11:11:11',
        Due                       => '2011-02-12 12:12:12',
        'new-DependsOn'           => '1 2 3',
        'DependsOn-new'           => '4',
        'new-MemberOf'            => '5 6',
        'MemberOf-new'            => '7',
        'new-RefersTo'            => '8 9',
        'RefersTo-new'            => '10',
    }
);
like( $m->uri, qr'/m/ticket/show', 'ticket show page' );
$m->content_contains( 'ticket1', 'subject' );
$m->content_contains( 'open', 'status' );
$m->content_contains( 'cc@example.com', 'cc' );
$m->content_contains( 'admincc@example.com', 'admincc' );
$m->content_contains( '13/93', 'priority' );
$m->content_contains( '2 hour', 'time estimates' );
$m->content_contains( '30 min', 'time worked' );
$m->content_contains( '60 min', 'time left' );
$m->content_contains( 'Tue Jan 11 11:11:11', 'starts' );
$m->content_contains( 'Sat Feb 12 12:12:12', 'due' );
$m->content_like( qr/(link of DependsOn).*\1.*\1/s, 'depends on' );
$m->content_contains( 'link of DependedOnBy', 'depended on by' );
$m->content_like( qr/(link of HasMember).*\1/s, 'has member' );
$m->content_contains( 'link of MemberOf', 'member of' );
$m->content_like( qr/(link of RefersTo).*\1/s, 'refers to' );
$m->content_contains( 'link of ReferredToBy', 'referred to by' );

diag "test ticket reply";
$m->follow_link_ok( { text => 'Reply' } );
like( $m->uri, qr'/m/ticket/reply', 'ticket reply page' );
$m->submit_form(
    fields => {
        UpdateContent    => 'reply 1',
        UpdateTimeWorked => '30',
        UpdateStatus     => 'resolved',
        UpdateType       => 'response',
    },
    button => 'SubmitTicket',
);
like( $m->uri, qr'/m/ticket/show', 'back to ticket show page' );
$m->content_contains( '1 hour', 'time worked' );
$m->content_contains( 'resolved', 'status' );
$m->follow_link_ok( { text => 'Reply' } );
like( $m->uri, qr'/m/ticket/reply', 'ticket reply page' );
$m->submit_form(
    fields => {
        UpdateContent    => 'reply 2',
        UpdateSubject    => 'ticket1',
        UpdateStatus     => 'open',
        UpdateType       => 'private',
    },
    button => 'SubmitTicket',
);
$m->no_warnings_ok;
$m->content_contains( 'ticket1', 'subject' );
$m->content_contains( 'open', 'status' );

like( $m->uri, qr'/m/ticket/show', 'back to ticket show page' );

diag "test ticket history";
$m->follow_link_ok( { text => 'History' } );
like( $m->uri, qr'/m/ticket/history', 'ticket history page' );
$m->content_contains( 'content 1', 'has main content' );
$m->content_contains( 'reply 1', 'has replied content' );
$m->content_contains( 'reply 2', 'has replied content' );

diag "create another ticket in queue foo";
$m->follow_link_ok( { text => 'Home' } );
is( $m->uri, "$url/m/", 'main mobile page' );
$m->follow_link_ok( { text => 'New ticket' } );
like( $m->uri, qr'/m/ticket/select_create_queue', 'queue select page' );
$m->follow_link_ok( { text => 'foo' } );
like( $m->uri, qr'/m/ticket/create', 'ticket create page' );
$m->content_contains( 'cfbar', 'has cf name' );
$m->content_contains( 'Object-RT::Ticket--CustomField-' . $cfbar->id .  '-Value', 'has cf input name' );
$m->submit_form(
    fields => {
        Subject => 'ticket2',
        Content => 'content 2',
        Owner   => $root->id,
        'Object-RT::Ticket--CustomField-' . $cfbar->id . '-Value' => 'cfvalue',
    }
);
$m->no_warnings_ok;
like( $m->uri, qr'/m/ticket/show', 'ticket show page' );
$m->content_contains( 'cfbar', 'has cf name' );
$m->content_contains( 'cfvalue', 'has cf value' );

$m->follow_link_ok( { text => 'Home' } );
is( $m->uri, "$url/m/", 'main mobile page' );

diag "test unowned tickets link";
$m->follow_link_ok( { text => 'Unowned tickets' } );
$m->content_contains( 'Found 1 ticket', 'found 1 ticket' );
$m->content_contains( 'ticket1', 'has ticket1' );
$m->content_lacks( 'ticket2', 'no ticket2' );
$m->back;

diag "test tickets I own link";
$m->follow_link_ok( { text => 'Tickets I own' } );
$m->content_contains( 'Found 1 ticket', 'found 1 ticket' );
$m->content_lacks( 'ticket1', 'no ticket1' );
ok( $m->find_link( text_regex => qr/ticket2/ ), 'has ticket2 link' );
$m->back;

diag "test all tickets link";
$m->follow_link_ok( { text => 'All tickets' } );
$m->content_contains( 'Found 12 tickets', 'found 12 tickets' );
ok( $m->find_link( text_regex => qr/ticket1/ ), 'has ticket1 link' );
ok( $m->find_link( text_regex => qr/ticket2/ ), 'has ticket2 link' );
$m->back;

diag "test bookmarked tickets link";
my $ticket = RT::Ticket->new(RT::CurrentUser->new('root'));
$ticket->Load(11);
$root->ToggleBookmark($ticket);

$m->follow_link_ok( { text => 'Bookmarked tickets' } );
$m->content_contains( 'Found 1 ticket', 'found 1 ticket' );
ok( $m->find_link( text_regex => qr/ticket1/ ), 'has ticket1 link' );
$m->content_lacks( 'ticket2', 'no ticket2' );
$m->back;

diag "test tickets search";
$m->submit_form( fields => { q => 'ticket2' } );
$m->content_contains( 'Found 1 ticket', 'found 1 ticket' );
$m->content_lacks( 'ticket1', 'no ticket1' );
ok( $m->find_link( text_regex => qr/ticket2/ ), 'has ticket2 link' );
$m->back;

diag "test logout link";
$m->follow_link_ok( { text => 'Logout' } );
is( $m->uri, "$url/m/", 'still in mobile' );
$m->submit_form( fields => { user => 'root', pass => 'password' } );

diag "test notmobile link";
$m->follow_link_ok( { text => 'Home' } );
$m->follow_link_ok( { text => 'Not using a mobile browser?' } );
is( $m->uri, $url . '/', 'got full ui' );

