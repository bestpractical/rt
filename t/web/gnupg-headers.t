use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 15,
  gnupg_options => {
    passphrase    => 'recipient',
    'trust-model' => 'always',
  };

RT::Test->import_gnupg_key( 'recipient@example.com', 'public' );
RT::Test->import_gnupg_key( 'general@example.com',   'secret' );

ok( my $user = RT::User->new( RT->SystemUser ) );
ok( $user->Load('root'), "Loaded user 'root'" );
$user->SetEmailAddress('recipient@example.com');

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'general@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';
my $qid = $queue->id;

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

diag "test with Encrypt and Sign disabled";

$m->goto_create_ticket($queue);
$m->form_name('TicketCreate');
$m->field( 'Subject', 'Signing test' );
$m->field( 'Content', 'Some other content' );
$m->submit;
$m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
$m->follow_link_ok( { text => 'with headers' } );
$m->content_contains('X-RT-Encrypt: 0');
$m->content_contains('X-RT-Sign: 0');

diag "test with Encrypt and Sign enabled";

$m->goto_create_ticket($queue);
$m->form_name('TicketCreate');
$m->field( 'Subject', 'Signing test' );
$m->field( 'Content', 'Some other content' );
$m->tick( 'Encrypt', 1 );
$m->tick( 'Sign',    1 );
$m->submit;
$m->content_like( qr/Ticket \d+ created/i, 'created the ticket' );
$m->follow_link_ok( { text => 'with headers' } );
$m->content_contains('X-RT-Encrypt: 1');
$m->content_contains('X-RT-Sign: 1');

