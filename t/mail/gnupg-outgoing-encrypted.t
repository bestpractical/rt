#!/usr/bin/perl -w
use strict;
use warnings;

use RT::Test::GnuPG
  tests         => 103,
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
    Encrypt           => 1,
);
ok $queue && $queue->id, 'loaded or created queue';

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in';

create_and_test_outgoing_emails( $queue, $m );

