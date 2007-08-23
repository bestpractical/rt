#!/usr/bin/perl -w
use strict;

use Test::More tests => 14;
use RT::Test;
use RT::Action::SendEmail;

eval 'use GnuPG::Interface; 1' or plan skip_all => 'GnuPG required.';

# catch any outgoing emails
unlink "t/mailbox";

is (__PACKAGE__, 'main', "We're operating in the main package");
{
    no warnings qw/redefine/;
    sub RT::Action::SendEmail::SendMessage {
        my $self = shift;
        my $MIME = shift;

        open my $handle, '>>', 't/mailbox'
            or die "Unable to open t/mailbox for appending: $!";

        print $handle map {"$_\n"} @{$MIME->body};
        print $handle "%% split me! %%\n";
    }
}

RT->Config->Set( LogToScreen => 'debug' );
RT->Config->Set( LogStackTraces => 'error' );

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
                 passphrase => 'rt-test',
                 'no-permission-warning' => undef);

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
$m->field('Subject', 'Attachments test');
$m->field('Content', 'Some content');
ok($m->value('Encrypt', 2), "encrypt tick box is checked");
ok(!$m->value('Sign', 2), "sign tick box is unchecked");
$m->submit;
is($m->status, 200, "request successful");

$m->get($baseurl); # ensure that the mail has been processed

my $mail = file_content('t/mailbox');
my @mail = split /\n%% split me! %%\n/, $mail;
pop @mail;
ok(@mail, "got some mail");
for (@mail) {
    unlike $_, qr/Some content/, "outgoing mail was encrypted";
}

sub file_content
{
    my $path = shift;
    diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};
    open my $fh, "<:raw", $path or die "couldn't open file '$path': $!";
    local $/;
    return scalar <$fh>;
}
