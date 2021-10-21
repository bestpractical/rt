use strict;
use warnings;

use RT::Test::Crypt SMIME => 1, tests => undef;
use IPC::Run3 'run3';

RT::Test::Crypt->smime_import_key( 'sender@example.com' );

diag "No OtherCertificatesToSend";

my $mime = MIME::Entity->build(
    From => 'sender@example.com',
    Type => 'text/plain',
    Data => ["this is body\n"],
);

RT::Crypt::SMIME->SignEncrypt( Entity => $mime, Signer => 'sender@example.com', Sign => 1, Encrypt => 0 );

my ( $pk7, $err, $cert );
run3( [ RT::Crypt::SMIME->OpenSSLPath, qw(smime -pk7out) ], \$mime->as_string, \$pk7, \$err );
ok( $pk7,  'got pk7 signature' );
ok( !$err, 'no errors' );

run3( [ RT::Crypt::SMIME->OpenSSLPath, qw(pkcs7 -print_certs -text) ], \$pk7, \$cert, \$err );
ok( $cert, 'got cert' );
ok( !$err, 'no errors' );

chomp $cert;
open my $fh, '<', RT::Test::Crypt->smime_key_path( 'sender@example.com.crt' ) or die $!;
my $sender_cert = do { local $/; <$fh> };

# Variations in how different versions of OpenSSL print certificates
# can lead to incorrect test falures.  So only compare the *actual*
# certificate data between the BEGIN CERTIFICATE and END CERTIFICATE lines
$cert =~ s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/s;
$sender_cert =~ s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/s;

is( $cert, $sender_cert, 'cert is the same one' );

diag "Has OtherCertificatesToSend";

RT->Config->Get( 'SMIME' )->{OtherCertificatesToSend} = RT::Test::Crypt->smime_key_path( 'demoCA', 'cacert.pem' );

$mime = MIME::Entity->build(
    From => 'sender@example.com',
    Type => 'text/plain',
    Data => ["this is body\n"],
);

RT::Crypt::SMIME->SignEncrypt( Entity => $mime, Signer => 'sender@example.com', Sign => 1, Encrypt => 0 );

run3( [ RT::Crypt::SMIME->OpenSSLPath, qw(smime -pk7out) ], \$mime->as_string, \$pk7, \$err );
ok( $pk7,  'got pk7 signature' );
ok( !$err, 'no errors' );

run3( [ RT::Crypt::SMIME->OpenSSLPath, qw(pkcs7 -print_certs -text) ], \$pk7, \$cert, \$err );
ok( $cert, 'got cert' );
ok( !$err, 'no errors' );

chomp $cert;
my @certs = split /\n(?=Certificate:)/, $cert;
is( scalar @certs, 2, 'found 2 certs' );

open $fh, '<', RT::Test::Crypt->smime_key_path( 'demoCA', 'cacert.pem' ) or die $!;
my $ca_cert = do { local $/; <$fh> };

# Variations in how different versions of OpenSSL print certificates
# can lead to incorrect test falures.  So only compare the *actual*
# certificate data between the BEGIN CERTIFICATE and END CERTIFICATE lines
$certs[0] =~ s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/s;
$certs[1] =~ s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/s;
$ca_cert =~ s/.*-----BEGIN CERTIFICATE-----/-----BEGIN CERTIFICATE-----/s;

is( $certs[0], $ca_cert,     'got ca cert' );
is( $certs[1], $sender_cert, 'got sender cert' );

done_testing;
