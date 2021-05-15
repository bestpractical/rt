use strict;
use warnings;

use RT::Test::Crypt SMIME => 1, tests => undef;

my $openssl = RT::Test->find_executable('openssl');
my $keyring = File::Spec->catfile(RT::Test->temp_directory, "smime" );
my $ca = RT::Test::find_relocatable_path(qw(data smime keys CAWithCRL));
$ca = File::Spec->catfile($ca, 'cacert.pem');

RT->Config->Set('SMIME', Enable => 1,
    Passphrase => {'sender-crl\@example.com' => '123456'},
    OpenSSL => $openssl,
    Keyring => $keyring,
    CAPath  => $ca,
    CheckCRL => 1,
    CheckOSCP => 1,
);

RT::Test::Crypt->smime_import_key('sender-crl@example.com');

if (!RT::Crypt::SMIME->SupportsCRLfile) {
    RT::Test::plan( skip_all => 'This version of openssl does not support the -CRLfile option');
}

if (!$ENV{RT_TEST_SMIME_REVOCATION}) {
    RT::Test::plan( skip_all => 'Skipping tests that would download a CRL because RT_TEST_SMIME_REVOCATION environment variable not set to 1');
}

my $crt;
{
    local $/;
    if (open my $fh, "<" . File::Spec->catfile($keyring, 'sender-crl@example.com.pem')) {
        $crt = <$fh>;
        close($fh);
    } else {
        die("Could not read " . File::Spec->catfile($keyring, 'sender-crl@example.com.pem') . ": $!");
    }
}

my %res;
%res = RT::Crypt::SMIME->GetCertificateInfo(Certificate => $crt);

is ($res{info}[0]{Trust}, 'Signed by trusted CA fake.ca.bestpractical.com (NOTE: Unable to download CRL)', "We attempted to download CRL, but it failed.");

done_testing;
