use strict;
use warnings;

use RT::Test::SMIME tests => undef;

my $openssl = RT::Test->find_executable('openssl');
my $keyring = File::Spec->catfile(RT::Test->temp_directory, "smime" );
my $ca = RT::Test::find_relocatable_path(qw(data smime keys));
$ca = File::Spec->catfile($ca, 'revoked-ca.pem');

RT->Config->Set('SMIME', Enable => 1,
    Passphrase => {'revoked\@example.com' => '123456'},
    OpenSSL => $openssl,
    Keyring => $keyring,
    CAPath  => $ca,
);

RT::Test::SMIME->import_key('revoked@example.com');


if (!$::RT::Crypt::SMIME::OpenSSL_Supports_CRL_Download) {
    RT::Test::plan( skip_all => 'This version of openssl does not support the -crl_download option');
}

my $crt;
{
    local $/;
    if (open my $fh, "<" . File::Spec->catfile($keyring, 'revoked@example.com.pem')) {
        $crt = <$fh>;
        close($fh);
    } else {
        die("Could not read " . File::Spec->catfile($keyring, 'revoked@example.com.pem') . ": $!");
    }
}

my %res;
%res = RT::Crypt::SMIME->GetCertificateInfo(Certificate => $crt);
is ($res{info}[0]{Trust}, 'REVOKED certificate checked against OCSP URI http://ocsp.digicert.com', 'Trust info indicates revoked certificate using OCSP');
is ($res{info}[0]{TrustTerse}, 'none (revoked certificate)', 'TrustTerse indicates revoked certificate');

# Now pretend we couldn't use OCSP
{
    no warnings 'redefine';
    *RT::Crypt::SMIME::CheckRevocationUsingOCSP = sub { return undef; };
    %res = RT::Crypt::SMIME->GetCertificateInfo(Certificate => $crt);
    is ($res{info}[0]{Trust}, 'REVOKED certificate from CA DigiCert SHA2 Secure Server CA', 'Trust info indicates revoked certificate using CRL');
    is ($res{info}[0]{TrustTerse}, 'none (revoked certificate)', 'TrustTerse indicates revoked certificate');
}

done_testing;
