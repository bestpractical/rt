#!/usr/bin/perl -w
use strict;

use Test::More tests => 11;
use RT::Test;

use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

eval 'use GnuPG::Interface; 1' or plan skip_all => 'GnuPG required.';

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

