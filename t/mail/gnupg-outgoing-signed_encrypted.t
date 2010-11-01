#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 101,
  gnupg_options => {
    passphrase    => 'rt-test',
    'trust-model' => 'always',
  };

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key( 'rt-test@example.com', 'public' );

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
    Sign              => 1,
    Encrypt           => 1,
);
ok $queue && $queue->id, 'loaded or created queue';

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @variants =
  ( {}, { Sign => 1 }, { Encrypt => 1 }, { Sign => 1, Encrypt => 1 }, );

# collect emails
my %mail;

# create a ticket for each combination
foreach my $ticket_set (@variants) {
    create_a_ticket( $queue, \%mail, $m, %$ticket_set );
}

my $tid;
{
    my $ticket = RT::Ticket->new( RT->SystemUser );
    ($tid) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => 'rt-test@example.com',
    );
    ok $tid, 'ticket created';
}

# again for each combination add a reply message
foreach my $ticket_set (@variants) {
    update_ticket( $tid, \%mail, $m, %$ticket_set );
}

# ------------------------------------------------------------------------------
# now delete all keys from the keyring and put back secret/pub pair for rt-test@
# and only public key for rt-recipient@ so we can verify signatures and decrypt
# like we are on another side recieve emails
# ------------------------------------------------------------------------------

unlink $_ foreach glob( RT->Config->Get('GnuPGOptions')->{'homedir'} . "/*" );
RT::Test->import_gnupg_key( 'rt-recipient@example.com', 'public' );
RT::Test->import_gnupg_key('rt-test@example.com');

$queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-test@example.com',
    CommentAddress    => 'rt-test@example.com',
);
ok $queue && $queue->id, 'changed props of the queue';

for my $type ( keys %mail ) {
    for my $mail ( map cleanup_headers($_), @{ $mail{$type} } ) {
        send_email_and_check_transaction( $mail, $type );
    }
}

