#!/usr/bin/perl -w
use strict;
use warnings;

use Test::More;
use RT::Test strict => 1;

plan skip_all => 'GnuPG required.'
    unless eval 'use GnuPG::Interface; 1';
plan skip_all => 'gpg executable is required.'
    unless RT::Test->find_executable('gpg');

plan tests => 14;

use File::Temp qw(tempdir);
use_ok('RT::Crypt::GnuPG');
RT->config->set(
    gnupg => {
        enable                   => 1,
        outgoing_messages_format => 'RFC',
    }
);

RT->config->set(
    gnupg_options => {
        homedir                 => scalar tempdir( CLEANUP => 0 ),
        passphrase              => 'rt-test',
        'no-permission-warning' => undef,
    }
);

diag "GnuPG --homedir ". RT->config->get('gnupg_options')->{'homedir'} if $ENV{TEST_VERBOSE};

my $queue = RT::Model::Queue->new( current_user => RT->system_user );
ok($queue->load('General'), 'load General queue');
$queue->set_correspond_address( 'general@example.com' );
RT::Test->import_gnupg_key('general@example.com');
RT::Test->import_gnupg_key('general@example.com','secret');
my ($baseurl, $agent) = RT::Test->started_ok;
ok $agent->login, 'logged in';
$agent->get_ok('/admin/queues/?id=' . $queue->id);
$agent->follow_link_ok( { text => 'GnuPG' }, 'follow GnuPG link');
$agent->content_contains('GnuPG private key', 'has private key section' );
$agent->content_contains('general@example.com', 'email is right' );


RT::Test->import_gnupg_key('general@example.com.2');
RT::Test->import_gnupg_key('general@example.com.2','secret');
my $user_general = RT::Test->load_or_create_user(
    name     => 'user_general',
    password => 'password',
    email => 'general@example.com',
);

$agent->get_ok('/admin/users/?id=' . $user_general->id);
$agent->follow_link_ok( { text => 'GnuPG' }, 'follow GnuPG link');
$agent->content_contains('GnuPG public key', 'has public key section' );
my %keys_meta = RT::Crypt::GnuPG::get_keys_for_signing( 'general@example.com', 'force' );
my @keys = map $_->{'key'}, @{ $keys_meta{'info'} };
my $moniker = 'user_select_private_key';
$agent->fill_in_action_ok( $moniker, private_key => $keys[0] );
$agent->submit;
$agent->content_contains(('Updated private key selection')x2);
is( $user_general->private_key, $keys[0], 'private key is indeed selected' );

