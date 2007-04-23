#!/usr/bin/perl
use strict;
use Test::More tests => 36;
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

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPGNG' );

my ($baseurl, $m) = RT::Test->started_ok;

# configure key for General queue
$m->get( $baseurl."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
		 fields      => { CorrespondAddress => 'general@example.com' } );
$m->content_like(qr/general\@example.com.* - never/, 'has key info.');

ok(my $user = RT::User->new($RT::SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('recipient@example.com');

# test simple mail.  supposedly this should fail when
# 1. the queue requires signature
# 2. the from is not what the key is associated with
my $mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<EOF;
From: recipient\@example.com
To: general\@$RT::rtname
Subject: This is a test of new ticket creation as root

Blah!
Foob!
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = get_latest_ticket_ok();
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

# test for signed mail
my $buf = '';

run3(
    shell_quote(
        qw(gpg --armor --sign),
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
    ),
    \"fnord\r\n",
    \$buf,
    \*STDOUT
);

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: signed message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = get_latest_ticket_ok();
    is( $tick->Subject, 'signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my $attach = $txn->Attachments->First;
    TODO: { local $TODO = 'not yet';
    is( $attach->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );
    }
    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr'fnord');
}

SKIP: { skip 'Apr 23 14:34:31 localhost RT: Deep recursion on subroutine "RT::Interface::Email::Auth::GnuPGNG::VerifyDecrypt" at lib/RT/Interface/Email/Auth/GnuPGNG.pm line 67. (lib/RT/Interface/Email/Auth/GnuPGNG.pm:67)', 8;

# test for clear-signed mail
$buf = '';

run3(
    shell_quote(
        qw(gpg --armor --sign --clearsign),
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
    ),
    \"clearfnord\r\n",
    \$buf,
    \*STDOUT
);
diag $buf;
$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: signed message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = get_latest_ticket_ok();
    is( $tick->Subject, 'signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my $attach = $txn->Attachments->First;
    TODO: { local $TODO = 'not yet';
    is( $attach->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );
    }
    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr'clearfnord');
}
}

# test for signed and encrypted mail
$buf = '';

run3(
    shell_quote(
        qw(gpg --encrypt --armor --sign),
        '--recipient'   => 'general@example.com',
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
    ),
    \"orzzzzzz\r\n",
    \$buf,
    \*STDOUT
);

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: Encrypted message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = get_latest_ticket_ok();
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

# test for signed mail by other key
$buf = '';

run3(
    shell_quote(
        qw(gpg --armor --sign),
        '--default-key' => 'rt@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'test',
    ),
    \"should not be there\r\n",
    \$buf,
    \*STDOUT
);

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: signed message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = get_latest_ticket_ok();
    my $txn = $tick->Transactions->First;
    my $attach = $txn->Attachments->First;
    unlike( $attach->Content, qr'should not be there');
}

sub get_latest_ticket_ok {
    my $tickets = RT::Tickets->new($RT::SystemUser);
    $tickets->OrderBy( FIELD => 'id', ORDER => 'DESC' );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => '0' );
    my $tick = $tickets->First();
    ok( $tick->Id, "found ticket " . $tick->Id );
    return $tick;
}
