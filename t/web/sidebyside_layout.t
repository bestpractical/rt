use strict;
use warnings;
use RT::Test tests => 11;

RT->Config->Set( UseSideBySideLayout => 0 );

my $root = RT::Test->load_or_create_user( Name => 'root', );
my ( $status, $msg ) = $root->SetPreferences(
    $RT::System => {
        %{ $root->Preferences($RT::System) || {} }, 'UseSideBySideLayout' => 1
    }
);
ok( $status, 'use side by side layout for root' );

my $user_a = RT::Test->load_or_create_user(
    Name     => 'user_a',
    Password => 'password',
);
ok( $user_a->id, 'created user_a' );

ok(
    RT::Test->set_rights(
        {
            Principal => $user_a,
            Right     => ['CreateTicket']
        },
    ),
    'granted user_a the right of CreateTicket'
);

my ( $url, $m ) = RT::Test->started_ok;
$m->login;
$m->get_ok( $url . '/Ticket/Create.html?Queue=1', "root's ticket create page" );
$m->content_like( qr/<body [^>]*class="[^>"]*\bsidebyside\b/,
    'found sidebyside css for root' );

my $m_a = RT::Test::Web->new;
ok $m_a->login( 'user_a', 'password' ), 'logged in as user_a';
$m_a->get_ok( $url . '/Ticket/Create.html?Queue=1',
    "user_a's ticket create page" );
$m_a->content_unlike(
    qr/<body [^>]*class="[^>"]*\bsidebyside\b/,
    "didn't find sidebyside class for user_a"
);

