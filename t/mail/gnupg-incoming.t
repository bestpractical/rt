#!/usr/bin/perl
use strict;
use Test::More tests => 18;
use File::Temp;
use RT::Test;
use Cwd 'getcwd';
use String::ShellQuote 'shell_quote';
use IPC::Run3 'run3';

my $homedir = File::Spec->catdir( getcwd(), qw(lib t data crypt-gnupg) );

RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir );

RT->Config->Set( 'MailPlugins' => 'Auth::GnuPGNG', 'Auth::MailFrom' );

my ($baseurl, $m) = RT::Test->started_ok;

# configure key for General queue
$m->get( $baseurl."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
		 fields      => { CorrespondAddress => 'general@example.com' } );
$m->content_like(qr/general\@example.com.* - never/, 'has key info.');

my $mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<EOF;
From: root\@localhost
To: rt\@$RT::rtname
Subject: This is a test of new ticket creation as root

Blah!
Foob!
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy( FIELD => 'id', ORDER => 'DESC' );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => '0' );
    my $tick = $tickets->First();
    ok( UNIVERSAL::isa( $tick, 'RT::Ticket' ) );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject,
        'This is a test of new ticket creation as root',
        "Created the ticket"
    );
    my $txn = $tick->Transactions->First;
    TODO: {
    local $TODO = 'not yet';
    like(
        $txn->Attachments->First->Headers,
        qr/^X-RT-Incoming-Encryption: Not encrypted/m,
        'recorded incoming mail that is not encrypted'
    );
    }
    like( $txn->Attachments->First->Content, qr'Blah');
}

# test for encrypted mail
my $buf = '';

run3(
    shell_quote(
        qw(gpg --encrypt --armor),
        '--recipient' => 'general@example.com',
        '--homedir'   => $homedir,
    ),
    \"orzzzzzz\r\n",
    \$buf,
    \*STDERR
);

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: root\@localhost
To: rt\@$RT::rtname
Subject: Encrypted message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy( FIELD => 'id', ORDER => 'DESC' );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => '0' );
    my $tick = $tickets->First();
    ok( UNIVERSAL::isa( $tick, 'RT::Ticket' ) );
    ok( $tick->Id, "found ticket " . $tick->Id );
    is( $tick->Subject, 'Encrypted message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my $attach = $txn->Attachments->First;
    TODO: { local $TODO = 'not yet';
    is( $attach->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    }
    like( $attach->Content, qr'orz');
}

