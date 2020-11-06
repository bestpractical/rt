use strict;
use warnings;

use RT::Test::SMIME tests => undef;

my $openssl = RT::Test->find_executable('openssl');
my $keyring = File::Spec->catfile(RT::Test->temp_directory, "smime" );
my $ca = RT::Test::find_relocatable_path(qw(data smime keys CAWithCRL));
$ca = File::Spec->catfile($ca, 'cacert.pem');

RT->Config->Set('SMIME', Enable => 1,
    Passphrase => {'sender-crl\@example.com' => '123456'},
    OpenSSL => $openssl,
    Keyring => $keyring,
    CAPath  => $ca,
);

RT::Test::SMIME->import_key('sender-crl@example.com');


if (!$::RT::Crypt::SMIME::OpenSSL_Supports_CRL_Download) {
    RT::Test::plan( skip_all => 'This version of openssl does not support the -crl_download option');
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

is ($res{info}[0]{Trust}, 'Signed by trusted CA fake.ca.bestpractical.com (NOTE: Unable to download CRL)', "We attempted to use -crl_download, but it failed.");

done_testing;
