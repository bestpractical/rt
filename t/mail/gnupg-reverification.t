#!/usr/bin/perl
use strict;
use warnings;

use RT::Test; use Test::More tests => 111;


use File::Temp qw(tempdir);
my $homedir = tempdir( CLEANUP => 1 );

RT->config->set( LogToScreen => 'debug' );
RT->config->set( 'GnuPG',
                 enable => 1,
                 outgoing_messages_format => 'RFC' );

RT->config->set( 'GnuPGOptions',
                 homedir => $homedir,
                 passphrase => 'rt-test',
                 'no-permission-warning' => undef);

RT->config->set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );


diag "load Everyone group" if $ENV{'TEST_VERBOSE'};
my $everyone;
{
    $everyone = RT::Model::Group->new(current_user => RT->system_user );
    $everyone->load_system_internal_group('Everyone');
    ok $everyone->id, "loaded 'everyone' group";
}

RT::Test->set_rights(
    principal => $everyone,
    right => ['CreateTicket'],
);


my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we get log in';

RT::Test->import_gnupg_key('rt-recipient@example.com');

my @ticket_ids;

my @files = glob("t/data/mails/gnupg-basic-set/*-signed-*");
foreach my $file ( @files ) {
    diag "testing $file" if $ENV{'TEST_VERBOSE'};

    my ($eid) = ($file =~ m{(\d+)[^/\\]+$});
    ok $eid, 'figured id of a file';

    my $email_content = RT::Test->file_content( $file );
    ok $email_content, "$eid: got content of email";

    my ($status, $id) = RT::Test->send_via_mailgate( $email_content );
    is $status >> 8, 0, "$eid: the mail gateway exited normally";
    ok $id, "$eid: got id of a newly created ticket - $id";

    my $ticket = RT::Model::Ticket->new(current_user => RT->system_user );
    $ticket->load( $id );
    ok $ticket->id, "$eid: loaded ticket #$id";
    is $ticket->subject, "Test Email ID:$eid", "$eid: correct subject";

    $m->goto_ticket( $id );
    $m->content_like(
        qr/Not possible to check the signature, the reason is missing public key/is,
        "$eid: signature is not verified",
    );
    $m->content_like(qr/This is .*ID:$eid/ims, "$eid: content is there and message is decrypted");

    push @ticket_ids, $id;
}

diag "import key into keyring" if $ENV{'TEST_VERBOSE'};
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

foreach my $id ( @ticket_ids ) {
    diag "testing ticket #$id" if $ENV{'TEST_VERBOSE'};

    $m->goto_ticket( $id );
    $m->content_like(
        qr/The signature is good/is,
        "signature is re-verified and now good",
    );
}

