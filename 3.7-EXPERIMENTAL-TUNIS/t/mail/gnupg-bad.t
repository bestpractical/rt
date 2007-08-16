#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 59;
use File::Temp;
use RT::Test;
use Cwd 'getcwd';
use String::ShellQuote 'shell_quote';
use IPC::Run3 'run3';

my $homedir = File::Spec->catdir( getcwd(), qw(lib t data crypt-gnupg) );

RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir );

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

my ($baseurl, $m) = RT::Test->started_ok;
ok(my $user = RT::User->new($RT::SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('recipient@example.com');

diag "no signature" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('no-sig');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "no encryption on encrypted queue" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unencrypted');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "mismatched signature" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('bad-sig');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "unknown public key" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unk-pub-key');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "unknown private key" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unk-priv-key');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "signer != sender" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('signer-not-sender');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "encryption to user whose pubkey is not signed" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unsigned-pub-key');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "no encryption of attachment on encrypted queue" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unencrypted-attachment');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "no signature of attachment" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unsigged-attachment');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "revoked key" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('revoked-key');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "expired key" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('expired-key');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

diag "unknown algorithm" if $ENV{TEST_VERBOSE};
{
    my $mail = get_contents('unknown-algorithm');
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");

    my $tick = get_latest_ticket_ok();
}

sub get_contents {
    my $pattern = shift;

    my $file = glob("lib/t/data/mail/*$pattern*");
    defined $file
        or do { diag "Unable to find lib/t/data/mail/*$pattern*"; return };

    open my $mailhandle, '<', $file
        or do { diag "Unable to read $file: $!"; return };

    my $mail = do { local $/; <$mailhandle> };
    close $mailhandle;

    return $mail;
}

sub get_latest_ticket_ok {
    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy( FIELD => 'id', ORDER => 'DESC' );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => '0' );
    my $tick = $tickets->First();
    ok( $tick->Id, "found ticket " . $tick->Id );
    return $tick;
}

