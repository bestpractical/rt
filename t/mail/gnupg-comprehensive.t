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

my $id = 0;
for my $usage (qw/signed encrypted signed&encrypted/)
{
    for my $format (qw/MIME inline/)
    {
        for my $attachment (qw/plain text-attachment binary-attachment/)
        {
            my $ok = email_ok(++$id, $usage, $format, $attachment);
            ok($ok, "$usage, $attachment email with $format key");
        }
    }
}

sub get_contents
{
    my $id = shift;

    my $file = glob("lib/t/data/mail/$id-*");
    defined $file
        or do { diag "Unable to find lib/t/data/mail/$id-*"; return };

    open my $mailhandle, '<', $file
        or do { diag "Unable to read $file: $!"; return };
    my $mail = do { local $/; <$mailhandle> };
    close $mailhandle;

    return $mail;
}

sub email_ok
{
    my ($id, $usage, $format, $attachment) = @_;

    my $mail = get_contents($id)
        or return 0;

    my $mailgate = RT::Test->open_mailgate_ok($baseurl);
    print $mailgate $mail;
    RT::Test->close_mailgate_ok($mailgate);

    return 0;
}

