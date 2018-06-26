use strict;
use warnings;

use RT::Test::GnuPG
  tests         => undef,
  gnupg_options => {
    passphrase    => 'recipient',
    'trust-model' => 'always',
};
use Test::Warn;
use MIME::Head;

use RT::Action::SendEmail;

RT->Config->Set( CommentAddress => 'general@example.com');
RT->Config->Set( CorrespondAddress => 'general@example.com');
RT->Config->Set( DefaultSearchResultFormat => qq{
   '<B><A HREF="__WebPath__/Ticket/Display.html?id=__id__">__id__</a></B>/TITLE:#',
   '<B><A HREF="__WebPath__/Ticket/Display.html?id=__id__">__Subject__</a></B>/TITLE:Subject',
   'OO-__Owner__-O',
   'OR-__Requestors__-O',
   'KO-__KeyOwner__-K',
   'KR-__KeyRequestors__-K',
   Status});


RT::Test->import_gnupg_key('recipient@example.com', 'public');
RT::Test->import_gnupg_key('recipient@example.com', 'secret');
RT::Test->import_gnupg_key('general@example.com', 'public');
RT::Test->import_gnupg_key('general@example.com', 'secret');
RT::Test->import_gnupg_key('general@example.com.2', 'public');
RT::Test->import_gnupg_key('general@example.com.2', 'secret');

ok(my $user = RT::User->new(RT->SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('recipient@example.com');

my $queue = RT::Test->load_or_create_queue(
    Name              => 'General',
    CorrespondAddress => 'general@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';
my $qid = $queue->id;

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

$m->get_ok("/Admin/Queues/Modify.html?id=$qid");
$m->form_with_fields('Sign', 'Encrypt');
$m->field(Encrypt => 1);
$m->submit;

RT::Test->clean_caught_mails;

$m->goto_create_ticket( $queue );
$m->form_name('TicketCreate');
$m->field('Requestors', 'recipient@example.com');
$m->field('Subject', 'Encryption test');
$m->field('Content', 'Some content');
ok($m->value('Encrypt', 2), "encrypt tick box is checked");
ok(!$m->value('Sign', 2), "sign tick box is unchecked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

my @mail = RT::Test->fetch_caught_mails;
ok(@mail, "got some mail");

$user->SetEmailAddress('general@example.com');
for my $mail (@mail) {
    unlike $mail, qr/Some content/, "outgoing mail was encrypted";

    my ($content_type, $mime_version) = get_headers($mail, "Content-Type", "MIME-Version");
    my $body = strip_headers($mail);

    $mail = << "MAIL";
Subject: RT mail sent back into RT
From: general\@example.com
To: recipient\@example.com
$mime_version
$content_type

$body
MAIL
 
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    is ($tick->Subject,
        "RT mail sent back into RT",
        "Correct subject"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        "RT's outgoing mail has crypto"
    );
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        "RT's outgoing mail looks encrypted"
    );

    like($attachments[0]->Content, qr/Some content/, "RT's mail includes copy of ticket text");
    like($attachments[0]->Content, qr/$RT::rtname/, "RT's mail includes this instance's name");
}

$m->get("$baseurl/Admin/Queues/Modify.html?id=$qid");
$m->form_with_fields('Sign', 'Encrypt');
$m->field(Encrypt => undef);
$m->field(Sign => 1);
$m->submit;

RT::Test->clean_caught_mails;

$m->goto_create_ticket( $queue );
$m->form_name('TicketCreate');
$m->field('Requestors', 'recipient@example.com');
$m->field('Subject', 'Signing test');
$m->field('Content', 'Some other content');
ok(!$m->value('Encrypt', 2), "encrypt tick box is unchecked");
ok($m->value('Sign', 2), "sign tick box is checked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

@mail = RT::Test->fetch_caught_mails;
ok(@mail, "got some mail");
for my $mail (@mail) {
    like $mail, qr/Some other content/, "outgoing mail was not encrypted";
    like $mail, qr/-----BEGIN PGP SIGNATURE-----[\s\S]+-----END PGP SIGNATURE-----/, "data has some kind of signature";

    my ($content_type, $mime_version) = get_headers($mail, "Content-Type", "MIME-Version");
    my $body = strip_headers($mail);

    $mail = << "MAIL";
Subject: More RT mail sent back into RT
From: general\@example.com
To: recipient\@example.com
$mime_version
$content_type

$body
MAIL
 
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    is ($tick->Subject,
        "More RT mail sent back into RT",
        "Correct subject"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        "RT's outgoing mail has crypto"
    );
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        "RT's outgoing mail looks unencrypted"
    );
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        'general <general@example.com>',
        "RT's outgoing mail looks signed"
    );

    like($attachments[0]->Content, qr/Some other content/, "RT's mail includes copy of ticket text");
    like($attachments[0]->Content, qr/$RT::rtname/, "RT's mail includes this instance's name");
}

$m->get("$baseurl/Admin/Queues/Modify.html?id=$qid");
$m->form_with_fields('Sign', 'Encrypt');
$m->field(Encrypt => 1);
$m->field(Sign => 1);
$m->submit;

RT::Test->clean_caught_mails;


$m->goto_create_ticket( $queue );
$m->form_name('TicketCreate');
$m->field('Requestors', 'recipient@example.com');
$m->field('Subject', 'Crypt+Sign test');
$m->field('Content', 'Some final? content');
ok($m->value('Encrypt', 2), "encrypt tick box is checked");
ok($m->value('Sign', 2), "sign tick box is checked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

@mail = RT::Test->fetch_caught_mails;
ok(@mail, "got some mail");
for my $mail (@mail) {
    unlike $mail, qr/Some other content/, "outgoing mail was encrypted";

    my ($content_type, $mime_version) = get_headers($mail, "Content-Type", "MIME-Version");
    my $body = strip_headers($mail);

    $mail = << "MAIL";
Subject: Final RT mail sent back into RT
From: general\@example.com
To: recipient\@example.com
$mime_version
$content_type

$body
MAIL
 
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    is ($tick->Subject,
        "Final RT mail sent back into RT",
        "Correct subject"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        "RT's outgoing mail has crypto"
    );
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        "RT's outgoing mail looks encrypted"
    );
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        'general <general@example.com>',
        "RT's outgoing mail looks signed"
    );

    like($attachments[0]->Content, qr/Some final\? content/, "RT's mail includes copy of ticket text");
    like($attachments[0]->Content, qr/$RT::rtname/, "RT's mail includes this instance's name");
}

RT::Test->clean_caught_mails;

$m->goto_create_ticket( $queue );
$m->form_name('TicketCreate');
$m->field('Requestors', 'recipient@example.com');
$m->field('Subject', 'Test crypt-off on encrypted queue');
$m->field('Content', 'Thought you had me figured out didya');
$m->field(Encrypt => undef, 2); # turn off encryption
ok(!$m->value('Encrypt', 2), "encrypt tick box is now unchecked");
ok($m->value('Sign', 2), "sign tick box is still checked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

@mail = RT::Test->fetch_caught_mails;
ok(@mail, "got some mail");
for my $mail (@mail) {
    like $mail, qr/Thought you had me figured out didya/, "outgoing mail was unencrypted";

    my ($content_type, $mime_version) = get_headers($mail, "Content-Type", "MIME-Version");
    my $body = strip_headers($mail);

    $mail = << "MAIL";
Subject: Post-final! RT mail sent back into RT
From: general\@example.com
To: recipient\@example.com
$mime_version
$content_type

$body
MAIL
 
    my ($status, $id) = RT::Test->send_via_mailgate($mail);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( RT->SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    is ($tick->Subject,
        "Post-final! RT mail sent back into RT",
        "Correct subject"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Privacy'),
        'GnuPG',
        "RT's outgoing mail has crypto"
    );
    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Not encrypted',
        "RT's outgoing mail looks unencrypted"
    );
    is( $msg->GetHeader('X-RT-Incoming-Signature'),
        'general <general@example.com>',
        "RT's outgoing mail looks signed"
    );

    like($attachments[0]->Content, qr/Thought you had me figured out didya/, "RT's mail includes copy of ticket text");
    like($attachments[0]->Content, qr/$RT::rtname/, "RT's mail includes this instance's name");
}

sub get_headers {
    my $mail = shift;
    open my $fh, "<", \$mail or die $!;
    my $head = MIME::Head->read($fh);
    return @{[
        map {
            my $hdr = "$_: " . $head->get($_);
            chomp $hdr;
            $hdr;
        }
        @_
    ]};
}

sub strip_headers
{
    my $mail = shift;
    $mail =~ s/.*?\n\n//s;
    return $mail;
}

# now test the OwnerNameKey and RequestorsKey fields

my $nokey = RT::Test->load_or_create_user(Name => 'nokey', EmailAddress => 'nokey@example.com');
$nokey->PrincipalObj->GrantRight(Right => 'CreateTicket');
$nokey->PrincipalObj->GrantRight(Right => 'OwnTicket');

my $tick = RT::Ticket->new( RT->SystemUser );
warning_like {
    $tick->Create(Subject => 'owner lacks pubkey', Queue => 'general',
                  Owner => $nokey);
} [
    qr/nokey\@example.com: skipped: public key not found/,
    qr/Recipient 'nokey\@example.com' is unusable/,
];
ok(my $id = $tick->id, 'created ticket for owner-without-pubkey');

$tick = RT::Ticket->new( RT->SystemUser );
$tick->Create(Subject => 'owner has pubkey', Queue => 'general',
              Owner => 'root');
ok($id = $tick->id, 'created ticket for owner-with-pubkey');

my $mail = << "MAIL";
Subject: Nokey requestor
From: nokey\@example.com
To: general\@example.com

hello
MAIL
 
my $status;
warning_like {
    ($status, $id) = RT::Test->send_via_mailgate($mail);
} [
    qr/nokey\@example.com: skipped: public key not found/,
    qr/Recipient 'nokey\@example.com' is unusable/,
];

is ($status >> 8, 0, "The mail gateway exited normally");
ok ($id, "got id of a newly created ticket - $id");

$tick = RT::Ticket->new( RT->SystemUser );
$tick->Load( $id );
ok ($tick->id, "loaded ticket #$id");

is ($tick->Subject,
    "Nokey requestor",
    "Correct subject"
);

# test key selection
my $key1 = "EC1E81E7DC3DB42788FB0E4E9FA662C06DE22FC2";
my $key2 = "75E156271DCCF02DDD4A7A8CDF651FA0632C4F50";

ok($user = RT::User->new(RT->SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
is($user->PreferredKey, $key1, "preferred key is set correctly");
$m->get("$baseurl/Prefs/Other.html");
like($m->content, qr/Preferred key/, "preferred key option shows up in preference");

# XXX: mech doesn't let us see the current value of the select, apparently
like($m->content, qr/$key1/, "first key shows up in preferences");
like($m->content, qr/$key2/, "second key shows up in preferences");
like($m->content, qr/$key1.*?$key2/s, "first key shows up before the second");

$m->form_name('ModifyPreferences');
$m->select("PreferredKey" => $key2);
$m->submit;

ok($user = RT::User->new(RT->SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
is($user->PreferredKey, $key2, "preferred key is set correctly to the new value");

$m->get("$baseurl/Prefs/Other.html");
like($m->content, qr/Preferred key/, "preferred key option shows up in preference");

# XXX: mech doesn't let us see the current value of the select, apparently
like($m->content, qr/$key2/, "second key shows up in preferences");
like($m->content, qr/$key1/, "first key shows up in preferences");
like($m->content, qr/$key2.*?$key1/s, "second key (now preferred) shows up before the first");

$m->no_warnings_ok;

# test that the new fields work
$m->get("$baseurl/Search/Simple.html?q=General");
my $content = $m->content;
$content =~ s/&#40;/(/g;
$content =~ s/&#41;/)/g;
$content =~ s/<(a|span)\b[^>]+>//g;
$content =~ s/<\/(a|span)>//g;
$content =~ s/&lt;/</g;
$content =~ s/&gt;/>/g;

like($content, qr/OO-Nobody in particular-O/,
     "original Owner untouched");
like($content, qr/OO-nokey-O/,
     "original Owner untouched");
like($content, qr/OO-root \(Enoch Root\)-O/,
     "original Owner untouched");
like($content, qr/OR-<recipient\@example\.com>-O/,
     "original Requestors untouched");
like($content, qr/OR-nokey-O/,
     "original Requestors untouched");

like($content, qr/KO-Nobody in particular \(no pubkey!\)-K/,
     "KeyOwner issues no-pubkey warning for nobody");
like($content, qr/KO-nokey \(no pubkey!\)-K/,
     "KeyOwner issues no-pubkey warning for root");
like($content, qr/KO-root \(Enoch Root\)-K/,
     "KeyOwner does not issue no-pubkey warning for recipient");
like($content, qr/KR-<recipient\@example\.com>-K/,
     "KeyRequestors does not issue no-pubkey warning for recipient\@example.com");
like($content, qr/KR-nokey \(no pubkey!\)-K/,
     "KeyRequestors DOES issue no-pubkey warning for nokey\@example.com");

$m->next_warning_like(qr/public key not found/);
$m->next_warning_like(qr/public key not found/);
$m->no_leftover_warnings_ok;

done_testing;
