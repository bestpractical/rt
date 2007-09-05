#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 176;
use RT::Test;

use Digest::MD5 qw(md5_hex);

use File::Temp qw(tempdir);
my $homedir = tempdir( CLEANUP => 1 );

RT::Test->set_mail_catcher;

RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir,
                 passphrase => 'rt-test',
                 'no-permission-warning' => undef,
                 'trust-model' => 'always',
);

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');


diag "prepare 'Regression' queue" if $ENV{'TEST_VERBOSE'};
my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'load or create queue';

RT::Test->set_rights(
    Principal => 'Everyone',
    Right => ['CreateTicket', 'ShowTicket', 'SeeQueue'],
);

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we did log in';

unlink "t/mailbox";

{
    ok $m->goto_create_ticket( $queue ),
        '-> Create ticket in queue '. $queue->Name;
    $m->form_number(3);
    $m->tick( Encrypt => 1 );

    $m->field( Subject => 'test' );
    $m->field( Requestors => 'rt-test@example.com' );
    $m->field( Content => 'test' );
    $m->submit;

    my @mails = RT::Test->fetch_caught_mails;
    diag $_ foreach @mails;
}

