#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 111;
use RT::Test;

use File::Temp qw(tempdir);
my $homedir = tempdir( CLEANUP => 1 );

RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir,
                 passphrase => 'rt-test',
                 'no-permission-warning' => undef);

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );


diag "load Everyone group" if $ENV{'TEST_VERBOSE'};
my $everyone;
{
    $everyone = RT::Group->new( $RT::SystemUser );
    $everyone->LoadSystemInternalGroup('Everyone');
    ok $everyone->id, "loaded 'everyone' group";
}

RT::Test->set_rights(
    Principal => $everyone,
    Right => ['CreateTicket'],
);


my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'we get log in';

import_key('rt-recipient@example.com');

my @ticket_ids;

my @files = glob("t/data/mails/gnupg-basic-set/*-signed-*");
foreach my $file ( @files ) {
    diag "testing $file" if $ENV{'TEST_VERBOSE'};

    my ($eid) = ($file =~ m{(\d+)[^/\\]+$});
    ok $eid, 'figured id of a file';

    my $email_content = get_contents( $file );
    ok $email_content, "$eid: got content of email";

    my ($status, $id) = RT::Test->send_via_mailgate( $email_content );
    is $status >> 8, 0, "$eid: the mail gateway exited normally";
    ok $id, "$eid: got id of a newly created ticket - $id";

    my $ticket = RT::Ticket->new( $RT::SystemUser );
    $ticket->Load( $id );
    ok $ticket->id, "$eid: loaded ticket #$id";
    is $ticket->Subject, "Test Email ID:$eid", "$eid: correct subject";

    $m->goto_ticket( $id );
    $m->content_like(
        qr/Not possible to check the signature, the reason is missing public key/is,
        "$eid: signature is not verified",
    );
    $m->content_like(qr/This is .*ID:$eid/ims, "$eid: content is there and message is decrypted");

    push @ticket_ids, $id;
}

diag "import key into keyring" if $ENV{'TEST_VERBOSE'};
import_key('rt-test@example.com', 'public');

foreach my $id ( @ticket_ids ) {
    diag "testing ticket #$id" if $ENV{'TEST_VERBOSE'};

    $m->goto_ticket( $id );
    $m->content_like(
        qr/The signature is good/is,
        "signature is re-verified and now good",
    );
}

sub get_contents {
    my $file = shift;

    open my $mailhandle, '<', $file
        or do { diag "Unable to read $file: $!"; return };

    return do { local $/; <$mailhandle> };
}

sub delete_key {
    require RT::Crypt::GnuPG;
    return RT::Crypt::GnuPG::DeleteKey( shift );
}

sub import_key {
    my $key = shift;
    my $type = shift || 'secret';

    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";
    $key = 't/data/gnupg/keys/'. $key;
    open my $fh, '<:raw', $key or die "couldn't open '$key': $!";

    require RT::Crypt::GnuPG;
    return RT::Crypt::GnuPG::ImportKey( do { local $/; <$fh> } );
}
