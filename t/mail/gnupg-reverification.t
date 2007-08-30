#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 111;
use File::Temp;
use RT::Test;
use Cwd 'getcwd';
use String::ShellQuote 'shell_quote';
use IPC::Run3 'run3';
use Digest::MD5 qw(md5_hex);

my $homedir = File::Spec->catdir( getcwd(), qw(lib t data crypt-gnupg-2) );

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

delete_key('rt-test@example.com');

my @ticket_ids;

my @files = glob("lib/t/data/mail/*-signed-*");
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
import_key('rt-test@example.com');

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
    my $key = shift;

    my %res;

    my %handle; 
    require GnuPG::Handles; require IO::Handle;
    my $handles = GnuPG::Handles->new(
        stdin   => ($handle{'input'}   = new IO::Handle),
        stdout  => ($handle{'output'}  = new IO::Handle),
        stderr  => ($handle{'error'}   = new IO::Handle),
        logger  => ($handle{'logger'}  = new IO::Handle),
        status  => ($handle{'status'}  = new IO::Handle),
        command => ($handle{'command'} = new IO::Handle),
    );

    require GnuPG::Interface; require RT::Crypt::GnuPG;
    my $gnupg = new GnuPG::Interface;
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        RT::Crypt::GnuPG::_PrepareGnuPGOptions( %opt ),
        armor => 1,
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{'LANG', 'LC_ALL'} = ('C', 'C');
        my $pid = $gnupg->wrap_call(
            handles => $handles,
            commands => ['--delete-secret-and-public-key'],
            command_args => [$key],
        );
        close $handle{'input'};
        while ( my $str = readline $handle{'status'} ) {
            if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL delete_key\..*/ ) {
                print { $handle{'command'} } "y\n";
            }
        }
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'output'};

    $res{'exit_code'} = $?;
    foreach ( qw(error logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'error'} ) if $res{'error'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

sub import_key {
    my $key = shift;
    my $type = shift || 'secret';
    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";
    $key = 't/data/mail/gnupg/keys/'. $key;

    my %res;

    my %handle; 
    require GnuPG::Handles; require IO::Handle;
    open my $key_fh, '<:raw', $key or die "couldn't open '$key': $!";
    my $handles = GnuPG::Handles->new(
        stdin   => ($handle{'input'}   = $key_fh),
        stdout  => ($handle{'output'}  = new IO::Handle),
        stderr  => ($handle{'error'}   = new IO::Handle),
        logger  => ($handle{'logger'}  = new IO::Handle),
        status  => ($handle{'status'}  = new IO::Handle),
        command => ($handle{'command'} = new IO::Handle),
    );
    $handles->options('stdin')->{'direct'} = 1;

    require GnuPG::Interface; require RT::Crypt::GnuPG;
    my $gnupg = new GnuPG::Interface;
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        RT::Crypt::GnuPG::_PrepareGnuPGOptions( %opt ),
        armor => 1,
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{'LANG', 'LC_ALL'} = ('C', 'C');
        my $pid = $gnupg->wrap_call(
            handles => $handles,
            commands => ['--import'],
        );
        while ( my $str = readline $handle{'status'} ) {
            diag $str;
            if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL delete_key\..*/ ) {
                print { $handle{'command'} } "y\n";
            }
        }
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'output'};

    $res{'exit_code'} = $?;
    foreach ( qw(error logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'error'} ) if $res{'error'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

