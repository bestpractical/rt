#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 159, strict => 1;
use RT::Test::Email;

skip_rest('GnuPG required.')
    unless eval 'use GnuPG::Interface; 1';
skip_rest('executable is required.')
    unless RT::Test->find_executable('gpg');

# the test imports a bunch of signed email but not loading the public
# keys into the server first.  We then check if the message can be
# reverified after importing the public keys.

use File::Temp qw(tempdir);
my $homedir = tempdir( CLEANUP => 1 );

RT->config->set(
    'gnupg',
    {
        enable                   => 1,
        outgoing_messages_format => 'RFC',
    }
);

RT->config->set(
    'gnupg_options',
    {
        homedir                 => $homedir,
        passphrase              => 'rt-test',
        'no-permission-warning' => undef,
    }
);

RT->config->set( 'mail_plugins' => ['Auth::MailFrom', 'Auth::GnuPG'] );


diag "load Everyone group" if $ENV{'TEST_VERBOSE'};
my $everyone;
{
    $everyone = RT::Model::Group->new(current_user => RT->system_user );
    $everyone->load_system_internal('Everyone');
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

my $emaildatadir = RT::Test::get_relocatable_dir(File::Spec->updir(),
    qw(data gnupg emails));
my @files = glob("$emaildatadir/*-signed-*");
foreach my $file ( @files ) {
    my ($eid) = ($file =~ m{(\d+)[^/\\]+$});
    ok $eid, 'figured id of a file';

    my $email_content = RT::Test->file_content( $file );
    ok $email_content, "$eid: got content of email";
    my ($from) = $email_content =~ m/^From: .*?(.*)$/mg;
    my ($addr) = map { $_->address } Email::Address->parse( $from );
    diag "testing $file from ".$addr if $ENV{'TEST_VERBOSE'};
    my ($status, $id);
    mail_ok {
        # XXX: also expect an error from server saying no pubkey.
        ($status, $id) = RT::Test->send_via_mailgate( $email_content );
        is $status >> 8, 0, "$eid: the mail gateway exited normally";
        ok $id, "$eid: got id of a newly created ticket - $id";
    } {
        to => $addr,
        subject => qr/We do not have your public key/,
        body => qr/we do not have your public PGP key/,
    }, {
        to => 'root',
        subject => qr/Some users have problems with public keys/,
        body => qr/following user/, # XXX: fix me, the user list is not there
    };

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

    $m->warnings_like(qr/Recipient '\Q$addr\E' is unusable/);

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

