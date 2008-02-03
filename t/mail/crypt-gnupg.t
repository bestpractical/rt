#!/usr/bin/perl

use strict;
use warnings;
use RT::Test; use Test::More;
eval 'use GnuPG::Interface; 1' or plan skip_all => 'GnuPG required.';

plan tests => 94;

use Data::Dumper;

use File::Spec ();
use Cwd;
my $homedir = File::Spec->catdir( cwd(), qw(lib t data crypt-gnupg) );
mkdir $homedir;

use_ok('RT::Crypt::GnuPG');
use_ok('MIME::Entity');

RT->config->set( 'GnuPG',
                 enable => 1,
                 outgoing_messages_format => 'RFC' );

RT->config->set( 'GnuPGOptions',
                 homedir => $homedir );


diag 'only signing. correct passphrase' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, encrypt => 0, passphrase => 'test' );
    ok( $entity, 'signed entity');
    ok( !$res{'logger'}, "log is here as well" );
    warn $res{'logger'};
    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 2, 'two records: passphrase, signing');
    is( $status[0]->{'operation'}, 'passphrase_check', 'operation is correct');
    is( $status[0]->{'status'}, 'DONE', 'good passphrase');
    is( $status[1]->{'operation'}, 'sign', 'operation is correct');
    is( $status[1]->{'status'}, 'DONE', 'done');
    is( $status[1]->{'user'}->{'email'}, 'rt@example.com', 'correct email');

    ok( $entity->is_multipart, 'signed message is multipart' );
    is( $entity->parts, 2, 'two parts' );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'type'}, 'signed', "have signed part" );
    is( $parts[0]->{'format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'top'}, $entity, "it's the same entity" );

    my @res = RT::Crypt::GnuPG::verify_decrypt( entity => $entity );
    is scalar @res, 1, 'one operation';
    @status = RT::Crypt::GnuPG::parse_status( $res[0]{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'operation'}, 'verify', 'operation is correct');
    is( $status[0]->{'status'}, 'DONE', 'good passphrase');
    is( $status[0]->{'trust'}, 'ULTIMATE', 'have trust value');
}

diag 'only signing. missing passphrase' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, encrypt => 0, passphrase => '' );
    ok( $res{'exit_code'}, "couldn't sign without passphrase");
    ok( $res{'error'}, "error is here" );
    ok( $res{'logger'}, "log is here as well" );
    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'operation'}, 'passphrase_check', 'operation is correct');
    is( $status[0]->{'status'}, 'MISSING', 'missing passphrase');
}

diag 'only signing. wrong passphrase' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, encrypt => 0, passphrase => 'wrong' );
    ok( $res{'exit_code'}, "couldn't sign with bad passphrase");
    ok( $res{'error'}, "error is here" );
    ok( $res{'logger'}, "log is here as well" );

    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'operation'}, 'passphrase_check', 'operation is correct');
    is( $status[0]->{'status'}, 'BAD', 'wrong passphrase');
}

diag 'encryption only' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, "successful encryption" );
    ok( !$res{'logger'}, "no records in logger" );

    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'operation'}, 'encrypt', 'operation is correct');
    is( $status[0]->{'status'}, 'DONE', 'done');

    ok($entity, 'get an encrypted part');

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'top'}, $entity, "it's the same entity" );
}

diag 'encryption only, bad recipient' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'keyless@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( $res{'exit_code'}, 'no way to encrypt without keys of recipients');
    ok( $res{'logger'}, "errors are in logger" );

    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'keyword'}, 'INV_RECP', 'invalid recipient');
}

diag 'encryption and signing with combined method' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, passphrase => 'test' );
    ok( !$res{'exit_code'}, "successful encryption with signing" );
    ok( !$res{'logger'}, "no records in logger" );

    my @status = RT::Crypt::GnuPG::parse_status( $res{'status'} );
    is( scalar @status, 3, 'three records: passphrase, sign and encrypt');
    is( $status[0]->{'operation'}, 'passphrase_check', 'operation is correct');
    is( $status[0]->{'status'}, 'DONE', 'done');
    is( $status[1]->{'operation'}, 'sign', 'operation is correct');
    is( $status[1]->{'status'}, 'DONE', 'done');
    is( $status[2]->{'operation'}, 'encrypt', 'operation is correct');
    is( $status[2]->{'status'}, 'DONE', 'done');

    ok($entity, 'get an encrypted and signed part');

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'top'}, $entity, "it's the same entity" );
}

diag 'encryption and signing with cascading, sign on encrypted' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, 'successful encryption' );
    ok( !$res{'logger'}, "no records in logger" );
    %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, encrypt => 0, passphrase => 'test' );
    ok( !$res{'exit_code'}, 'successful signing' );
    ok( !$res{'logger'}, "no records in logger" );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 1, 'one protected part, top most' );
    is( $parts[0]->{'type'}, 'signed', "have signed part" );
    is( $parts[0]->{'format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'top'}, $entity, "it's the same entity" );
}

diag 'find signed/encrypted part deep inside' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, "success" );
    $entity->make_multipart( 'mixed', Force => 1 );
    $entity->attach(
        Type => 'text/plain',
        Data => ['-'x76, 'this is mailing list'],
    );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 1, 'one protected part' );
    is( $parts[0]->{'type'}, 'encrypted', "have encrypted part" );
    is( $parts[0]->{'format'}, 'RFC3156', "RFC3156 format" );
    is( $parts[0]->{'top'}, $entity->parts(0), "it's the same entity" );
}

diag 'wrong signed/encrypted parts: no protocol' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => undef );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'wrong signed/encrypted parts: not enought parts' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, 'success' );
    $entity->parts([ $entity->parts(0) ]);

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'wrong signed/encrypted parts: wrong proto' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, sign => 0 );
    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => 'application/bad-proto' );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'wrong signed/encrypted parts: wrong proto' if $ENV{'TEST_VERBOSE'};
{
    my $entity = MIME::Entity->build(
        From    => 'rt@example.com',
        To      => 'rt@example.com',
        Subject => 'test',
        Data    => ['test'],
    );
    my %res = RT::Crypt::GnuPG::sign_encrypt( entity => $entity, encrypt => 0, passphrase => 'test' );
    ok( !$res{'exit_code'}, 'success' );
    $entity->head->mime_attr( 'Content-Type.protocol' => 'application/bad-proto' );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 0, 'no protected parts' );
}

diag 'verify inline and in attachment signatures' if $ENV{'TEST_VERBOSE'};
{
    open my $fh, "$homedir/signed_old_style_with_attachment.eml";
    my $parser = new MIME::Parser;
    my $entity = $parser->parse( $fh );

    my @parts = RT::Crypt::GnuPG::find_protected_parts( entity => $entity );
    is( scalar @parts, 2, 'two protected parts' );
    is( $parts[1]->{'type'}, 'signed', "have signed part" );
    is( $parts[1]->{'format'}, 'inline', "inline format" );
    is( $parts[1]->{'data'}, $entity->parts(0), "it's first part" );

    is( $parts[0]->{'type'}, 'signed', "have signed part" );
    is( $parts[0]->{'format'}, 'attachment', "attachment format" );
    is( $parts[0]->{'data'}, $entity->parts(1), "data in second part" );
    is( $parts[0]->{'signature'}, $entity->parts(2), "file's signature in third part" );

    my @res = RT::Crypt::GnuPG::verify_decrypt( entity => $entity );
    my @status = RT::Crypt::GnuPG::parse_status( $res[0]->{'status'} );
    is( scalar @status, 1, 'one record');
    is( $status[0]->{'operation'}, 'verify', 'operation is correct');
    is( $status[0]->{'status'}, 'DONE', 'good passphrase');
    is( $status[0]->{'trust'}, 'ULTIMATE', 'have trust value');

    $parser->filer->purge();
}

