#!/usr/bin/perl
use strict;
use warnings;

use RT::Test tests => 6;

plan skip_all => 'GnuPG required.'
    unless eval 'use GnuPG::Interface; 1';
plan skip_all => 'gpg executable is required.'
    unless RT::Test->find_executable('gpg');


use Cwd 'getcwd';

my $homedir = RT::Test::get_abs_relocatable_dir(File::Spec->updir(),
    qw(data gnupg keyrings));

RT->Config->Set( 'GnuPG',
                 Enable => 1,
                 OutgoingMessagesFormat => 'RFC' );

RT->Config->Set( 'GnuPGOptions',
                 homedir => $homedir,
                 passphrase => 'test',
                 'no-permission-warning' => undef);

RT->Config->Set( 'MailPlugins' => 'Auth::MailFrom', 'Auth::GnuPG' );

my ($baseurl, $m) = RT::Test->started_ok;

$m->get( $baseurl."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->get( $baseurl.'/Admin/Queues/');
$m->follow_link_ok( {text => 'General'} );
$m->submit_form( form_number => 3,
         fields      => { CorrespondAddress => 'rt@example.com' } );
$m->content_like(qr/rt\@example.com.* - never/, 'has key info.');

ok(my $user = RT::User->new($RT::SystemUser));
ok($user->Load('root'), "Loaded user 'root'");
$user->SetEmailAddress('rt@example.com');

if (0) {
    # XXX: need to generate these mails
    diag "no signature" if $ENV{TEST_VERBOSE};
    diag "no encryption on encrypted queue" if $ENV{TEST_VERBOSE};
    diag "mismatched signature" if $ENV{TEST_VERBOSE};
    diag "unknown public key" if $ENV{TEST_VERBOSE};
    diag "unknown private key" if $ENV{TEST_VERBOSE};
    diag "signer != sender" if $ENV{TEST_VERBOSE};
    diag "encryption to user whose pubkey is not signed" if $ENV{TEST_VERBOSE};
    diag "no encryption of attachment on encrypted queue" if $ENV{TEST_VERBOSE};
    diag "no signature of attachment" if $ENV{TEST_VERBOSE};
    diag "revoked key" if $ENV{TEST_VERBOSE};
    diag "expired key" if $ENV{TEST_VERBOSE};
    diag "unknown algorithm" if $ENV{TEST_VERBOSE};
}

