use strict;
use warnings;

my $homedir;
BEGIN {
    require RT::Test;
    $homedir =
      RT::Test::get_abs_relocatable_dir( File::Spec->updir(),
        qw/data gnupg keyrings/ );
}

use RT::Test::GnuPG
  tests         => 53,
  actual_server => 1,
  gnupg_options => {
    passphrase => 'rt-test',
    homedir    => $homedir,
  };

use String::ShellQuote 'shell_quote';
use IPC::Run3 'run3';
use MIME::Base64;

my ($baseurl, $m) = RT::Test->started_ok;

# configure key for General queue
ok( $m->login, 'we did log in' );
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
                 fields      => { CorrespondAddress => 'general@example.com' } );
$m->content_like(qr/general\@example.com.* - never/, 'has key info.');

ok(my $user = RT::User->new(RT->SystemUser));
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
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject,
        'This is a test of new ticket creation as root',
        "Created the ticket"
    );
    my $txn = $tick->Transactions->First;
    like(
        $txn->Attachments->First->Headers,
        qr/^X-RT-Incoming-Encryption: Not encrypted/m,
        'recorded incoming mail that is not encrypted'
    );
    like( $txn->Attachments->First->Content, qr/Blah/);
}

# test for signed mail
my $buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --armor --sign),
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
        '--no-permission-warning',
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
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );
    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr/fnord/);
}

# test for clear-signed mail
$buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --armor --sign --clearsign),
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
        '--no-permission-warning',
    ),
    \"clearfnord\r\n",
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
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'signed message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        'recorded incoming mail that is encrypted'
    );
    # test for some kind of PGP-Signed-By: Header
    like( $attach->Content, qr/clearfnord/);
}

# test for signed and encrypted mail
$buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --encrypt --armor --sign),
        '--recipient'   => 'general@example.com',
        '--default-key' => 'recipient@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'recipient',
        '--no-permission-warning',
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
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'Encrypted message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        'recorded incoming mail that is encrypted'
    );
    like( $attach->Content, qr/orz/);

    is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message');
    ok(index($orig->Content, $buf) != -1, 'found original msg');
}


# test that if it gets base64 transfer-encoded, we still get the content out
$buf = encode_base64($buf);
$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Content-transfer-encoding: base64
Subject: Encrypted message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'Encrypted message for queue',
        "Created the ticket"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, $attach, $orig) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        'recorded incoming mail that is encrypted'
    );
    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        'recorded incoming mail that is encrypted'
    );
    like( $attach->Content, qr/orz/);

    is( $orig->GetHeader('Content-Type'), 'application/x-rt-original-message');
    ok(index($orig->Content, $buf) != -1, 'found original msg');
}

# test for signed mail by other key
$buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --armor --sign),
        '--default-key' => 'rt@example.com',
        '--homedir'     => $homedir,
        '--passphrase'  => 'test',
        '--no-permission-warning',
    ),
    \"alright\r\n",
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
    my $tick = RT::Test->last_ticket;
    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    # XXX: in this case, which credential should we be using?
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        'Test User <rt@example.com>',
        'recorded incoming mail signed by others'
    );
}

# test for encrypted mail with key not associated to the queue
$buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --armor --encrypt),
        '--recipient'   => 'random@localhost',
        '--homedir'     => $homedir,
        '--no-permission-warning',
    ),
    \"should not be there either\r\n",
    \$buf,
    \*STDOUT
);

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: encrypted message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);

{
    my $tick = RT::Test->last_ticket;
    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    
    TODO:
    {
        local $TODO = "this test requires keys associated with queues";
        unlike( $attach->Content, qr/should not be there either/);
    }
}

# test for badly encrypted mail
{
$buf = '';

run3(
    shell_quote(
        qw(gpg --batch --no-tty --armor --encrypt),
        '--recipient'   => 'rt@example.com',
        '--homedir'     => $homedir,
        '--no-permission-warning',
    ),
    \"really should not be there either\r\n",
    \$buf,
    \*STDOUT
);

$buf =~ s/PGP MESSAGE/SCREWED UP/g;

RT::Test->fetch_caught_mails;

$mail = RT::Test->open_mailgate_ok($baseurl);
print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: encrypted message for queue

$buf
EOF
RT::Test->close_mailgate_ok($mail);
my @mail = RT::Test->fetch_caught_mails;
is(@mail, 1, 'caught outgoing mail.');
}

{
    my $tick = RT::Test->last_ticket;
    my $txn = $tick->Transactions->First;
    my ($msg, $attach) = @{$txn->Attachments->ItemsArrayRef};
    unlike( ($attach ? $attach->Content : ''), qr/really should not be there either/);
}


# test that if it gets base64 transfer-encoded long mail then it doesn't hang
{
    local $SIG{ALRM} = sub {
        ok 0, "timed out, web server is probably in deadlock";
        exit;
    };
    alarm 30;
    $buf = encode_base64('a'x(250*1024));
    $mail = RT::Test->open_mailgate_ok($baseurl);
    print $mail <<"EOF";
From: recipient\@example.com
To: general\@$RT::rtname
Content-transfer-encoding: base64
Subject: Long not encrypted message for queue

$buf
EOF
    RT::Test->close_mailgate_ok($mail);
    alarm 0;

    my $tick = RT::Test->last_ticket;
    is( $tick->Subject, 'Long not encrypted message for queue',
        "Created the ticket"
    );
    my $content = $tick->Transactions->First->Content;
    like $content, qr/a{1024,}/, 'content is not lost';
}
