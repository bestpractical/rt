#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
eval 'use RT::Test; 1'
    or plan skip_all => 'requires 3.7 to run tests.';

plan tests => 10;

use IPC::Run3 'run3';
use Cwd 'abs_path';
use RT::Interface::Email;

use_ok('RT::Crypt::SMIME');

RT::Config->Set( 'MailCommand' => 'sendmail'); # we intercept MIME::Entity::send

RT->Config->Set( 'OpenSSLPath', '/usr/bin/openssl' );
RT->Config->Set( 'SMIMEKeys', abs_path('testkeys') );
RT->Config->Set( 'SMIMEPasswords', {'sender@example.com' => '123456'} );
RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::SMIME' );

RT::Handle->InsertData('etc/initialdata');

my ($url, $m) = RT::Test->started_ok;
# configure key for General queue
$m->get( $url."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->get( $url.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
		 fields      => { CorrespondAddress => 'sender@example.com' } );

my $user = RT::User->new($RT::SystemUser);
ok($user->LoadByEmail('root@localhost'), "Loaded user 'root'");
diag $user->Id;
ok($user->Load('root'), "Loaded user 'root'");
is( $user->EmailAddress, 'root@localhost' );
my $val = $user->FirstCustomFieldValue('PublicKey');
# XXX: delete if it's already there
unless (defined $val) {
    local $/;
    open my $fh, 'testkeys/recipient.crt' or die $!;
    $user->AddCustomFieldValue( Field => 'PublicKey', Value => <$fh> );
    $val = $user->FirstCustomFieldValue('PublicKey');
}

no warnings 'once';
local *MIME::Entity::send = sub {
    my $mime_obj = shift;
    my ($buf, $err);
    ok(eval { run3([qw(openssl smime -decrypt -passin pass:123456 -inkey testkeys/recipient.key -recip testkeys/recipient.crt)],
	 \$mime_obj->as_string, \$buf, \$err) }, 'can decrypt');
    diag $err if $err;
    diag "Error code: $?" if $?;
    like($buf, qr'This message has been automatically generated in response');
    # XXX: check signature as wel
};


RT::Interface::Email::Gateway( {queue => 1, action => 'correspond',
			       message => 'From: root@localhost
To: rt@example.com
Subject: This is a test of new ticket creation as an unknown user

Blah!
Foob!'});

my $tickets = RT::Tickets->new($RT::SystemUser);
$tickets->OrderBy(FIELD => 'id', ORDER => 'DESC');
$tickets->Limit(FIELD => 'id' ,OPERATOR => '>', VALUE => '0');
my $tick = $tickets->First();
ok ($tick->Id, "found ticket ".$tick->Id);
