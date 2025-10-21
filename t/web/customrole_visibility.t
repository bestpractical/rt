use strict;
use warnings;

use RT::Test tests => undef;

# Test the new custom role visibility using page layouts instead of the old URL-based approach

# Set up test data
my $queue = RT::Test->load_or_create_queue( Name => 'TestQueue' );
ok($queue->Id, 'Created test queue');

for my $name (qw/SingleTestCustomRole MultipleTestCustomRole/) {
    my $role = RT::CustomRole->new( RT->SystemUser );
    my ( $ok, $msg ) = $role->Create(
        Name      => $name,
        MaxValues => $name =~ /Single/ ? 1 : 0,
    );
    ok( $ok, "Created custom role: $msg" );

    ( $ok, $msg ) = $role->AddToObject( $queue->Id );
    ok( $ok, "Added role to queue: $msg" );
}


# Create a test ticket
my $ticket = RT::Test->create_ticket(
    Queue => $queue->Id,
    Subject => 'test ticket',
);
ok($ticket->Id, 'Created test ticket');

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Test that custom role is visible by default
$m->get_ok( "/Ticket/Create.html?Queue=" . $queue->Id );
$m->content_contains( $_, "Custom roles are visible on Create page by default" )
    for qw/SingleTestCustomRole MultipleTestCustomRole/;

$m->get_ok( "/Ticket/Display.html?id=" . $ticket->Id );
$m->content_contains( $_, "Custom roles are visible on display page by default" )
    for qw/SingleTestCustomRole MultipleTestCustomRole/;

$m->get_ok( "/Ticket/Update.html?id=" . $ticket->Id );
$m->content_contains( 'SingleTestCustomRole', "SingleCustomRole is visible on update page by default" );

diag( 'Test hiding custom roles with page layout configuration' );

# Configure page layout to hide custom role in Message widget
my %layout = (
    'RT::Ticket' => {
        'Create' => {
            'Default' => [
                {   'Elements' => [
                        [   {   Name        => 'Message',
                                HiddenRoles => ['MultipleTestCustomRole'],
                            },
                            'Submit'
                        ],
                        [ 'Basics', ]
                    ]
                }
            ]
        },
        'Display' => {
            'Default' => [
                {   'Layout'   => 'col-12',
                    'Elements' => [
                        [   { Name => 'Basics', HiddenRoles => ['SingleTestCustomRole'] },
                            {   Name        => 'People',
                                HiddenRoles => [ 'SingleTestCustomRole', 'MultipleTestCustomRole' ]
                            },
                        ]
                    ]
                }
            ]
        },
        'Update' => {
            'Default' => [
                {   'Elements' => [
                        [ 'Message', 'Submit' ],
                        [ { Name => 'Basics', HiddenRoles => ['SingleTestCustomRole'] } ],
                    ]
                }
            ]

        }
    }
);

my $config = RT::Configuration->new( RT->SystemUser );
my ( $ret, $msg ) = $config->Create( Name => 'PageLayouts', Content => \%layout );
ok( $ret, 'Updated config' );


$m->get_ok( '/Ticket/Create.html?Queue=' . $queue->Id );
$m->text_contains( 'SingleTestCustomRole', 'SingleTestCustomRole still appears on page in Basics widget' );
$m->text_lacks( 'MultipleTestCustomRole', 'MultipleTestCustomRole is now hidden' );

$m->get_ok( '/Ticket/Display.html?id=' . $ticket->Id );
$m->text_lacks( 'TestCustomRole', 'TestCustomRoles are hidden' );

$m->get_ok( '/Ticket/Update.html?id=' . $ticket->Id );
$m->text_lacks( 'SingleTestCustomRole', 'SingleTestCustomRole is hidden' );

done_testing();
