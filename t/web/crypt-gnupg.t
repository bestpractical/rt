#!/usr/bin/perl -w
use strict;

use Test::More tests => 29;
use RT::Test;
use RT::Action::SendEmail;

eval 'use GnuPG::Interface; 1' or plan skip_all => 'GnuPG required.';

# catch any outgoing emails
unlink "t/mailbox";

sub capture_mail {
    my $MIME = shift;

    open my $handle, '>>', 't/mailbox'
        or die "Unable to open t/mailbox for appending: $!";

    $MIME->print($handle);
    print $handle "%% split me! %%\n";
    close $handle;
}

RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set( LogStackTraces => 'error' );
RT->Config->Set( CommentAddress => 'general@example.com');
RT->Config->Set( CorrespondAddress => 'general@example.com');
RT->Config->Set( MailCommand => \&capture_mail);

use File::Spec ();
use Cwd;
my $homedir = File::Spec->catdir( cwd(), qw(lib t data crypt-gnupg) );
mkdir $homedir;

use_ok('RT::Crypt::GnuPG');

RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir,
                 'no-permission-warning' => undef);
RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

ok(my $user = RT::User->new($RT::SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('recipient@example.com');

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue_name = 'General';
my $qid;
{
    $m->content =~ /<SELECT\s+NAME\s*="Queue"\s*>.*?<OPTION\s+VALUE="(\d+)".*?>\s*\Q$queue_name\E\s*<\/OPTION>/msig;
    ok( $qid = $1, "found id of the '$queue_name' queue");
}

$m->get("$baseurl/Admin/Queues/Modify.html?id=$qid");
$m->form_with_fields('Sign', 'Encrypt');
$m->field(Encrypt => 1);
$m->submit;

$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');

$m->form_name('TicketCreate');
$m->field('Subject', 'Encryption test');
$m->field('Content', 'Some content');
ok($m->value('Encrypt', 2), "encrypt tick box is checked");
ok(!$m->value('Sign', 2), "sign tick box is unchecked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

my $mail = file_content_unlink('t/mailbox');
my @mail = grep {/\S/} split /%% split me! %%/, $mail;
ok(@mail, "got some mail");
for my $mail (@mail) {
    unlike $mail, qr/Some content/, "outgoing mail was encrypted";

    my ($content_type) = $mail =~ /^(Content-Type: .*)/m;
    my ($mime_version) = $mail =~ /^(MIME-Version: .*)/m;
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

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok ($tick->id, "loaded ticket #$id");

    is ($tick->Subject,
        "RT mail sent back into RT",
        "Correct subject"
    );

    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is( $msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        "RT's outgoing mail looks encrypted"
    );
    is( $msg->GetHeader('X-RT-Privacy'),
        'PGP',
        "RT's outgoing mail looks encrypted"
    );

    like( $msg->Content,
            qr/Some content/,
            "incoming mail did NOT have original body"
    );
    my ($content_type) = /(Content-Type: .*)/;
    my ($mime_version) = /(MIME-Version: .*)/;
    $_ = strip_headers($_);

    $_ = << "MAIL";
From: recipient\@example.com
To: general\@$RT::rtname
Subject: This is just RT's response fed back into RT
$mime_version
$content_type


$_
MAIL

    my ($status, $id) = RT::Test->send_via_mailgate($_);
    is ($status >> 8, 0, "The mail gateway exited normally");
    ok ($id, "got id of a newly created ticket - $id");

    my $tick = RT::Ticket->new( $RT::SystemUser );
    $tick->Load( $id );
    ok($tick->id, "loaded ticket #$id");

    is($tick->Subject, "This is just RT's response fed back into RT");
    my $txn = $tick->Transactions->First;
    my ($msg, @attachments) = @{$txn->Attachments->ItemsArrayRef};

    is($msg->GetHeader('X-RT-Incoming-Encryption'),
        'Success',
        "RT's outgoing mail was indeed encrypted");
    is($msg->GetHeader('X-RT-Privacy'),
        'PGP');

    like($attachments[0]->Content, qr/Some content/, "RT's mail includes copy of ticket text");
    like($attachments[0]->Content, qr/\@$RT::rtname/, "RT's mail includes this instance's name");
}

$m->get("$baseurl/Admin/Queues/Modify.html?id=$qid");
$m->form_with_fields('Sign', 'Encrypt');
$m->field(Encrypt => undef);
$m->field(Sign => 1);
$m->submit;

$m->form_name('CreateTicketInQueue');
$m->field('Queue', $qid);
$m->submit;
is($m->status, 200, "request successful");
$m->content_like(qr/Create a new ticket/, 'ticket create page');

unlink "t/mailbox";

$m->form_name('TicketCreate');
$m->field('Subject', 'Signing test');
$m->field('Content', 'Some other content');
ok(!$m->value('Encrypt', 2), "encrypt tick box is unchecked");
ok($m->value('Sign', 2), "sign tick box is checked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

$mail = file_content_unlink('t/mailbox');
@mail = grep {/\S/} split /%% split me! %%/, $mail;
ok(@mail, "got some mail");
for (@mail) {
    like $_, qr/Some other content/, "outgoing mail was not encrypted";
    like $_, qr/-----BEGIN PGP SIGNATURE-----[\s\S]+-----END PGP SIGNATURE-----/, "data has some kind of signature";
}

sub file_content_unlink
{
    my $path = shift;
    diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};
    open my $fh, "<:raw", $path or die "couldn't open file '$path': $!";
    local $/;
    my $content = <$fh>;
    close $fh;
    unlink $path;
    return $content;
}

sub strip_headers
{
    my $mail = shift;
    $mail =~ s/.*?\n\n//s;
    return $mail;
}
