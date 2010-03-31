#!/usr/bin/perl
use strict;
use warnings;
use RT::Test strict => 1;
use Test::More;

plan skip_all => 'GnuPG required.'
    unless eval 'use GnuPG::Interface; 1';
plan skip_all => 'gpg executable is required.'
    unless RT::Test->find_executable('gpg');

plan tests => 2;


use Cwd 'getcwd';

my $homedir = RT::Test::get_abs_relocatable_dir(File::Spec->updir(),
    qw(data gnupg keyrings));

RT->config->set(
    'gnupg',
    {
        enable                   => 1,
        outgoing_messages_format => 'RFC',
    }
);

RT->config->set(
    'gnupg_options',
    {
        homedir                 => $homedir,
        passphrase              => 'test',
        'no-permission-warning' => undef,
    }
);

RT->config->set( 'mail_plugins' => ['Auth::MailFrom', 'Auth::GnuPG'] );

my $queue = RT::Model::Queue->new( current_user => RT->system_user );
$queue->load('General');
$queue->set_correspond_address( 'rt@example.com' );

ok(my $user = RT::Model::User->new(current_user => RT->system_user));
ok($user->load('root'), "loaded user 'root'");
$user->set_email('rt@example.com');

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

