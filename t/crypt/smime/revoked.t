use strict;
use warnings;

use RT::Test::Crypt SMIME => 1, tests => undef, actual_server => 1;

if ( !RT::Crypt::SMIME->SupportsCRLfile ) {
    RT::Test::plan( skip_all => 'This version of openssl does not support the -CRLfile option' );
}

my $openssl = RT::Test->find_executable('openssl');
my $certs   = File::Spec->catdir( RT::Test->temp_directory, 'certs' );
mkdir $certs or die "Could not create $certs: $!";

my $ocsp_port = RT::Test->find_idle_port;

use Cwd;
my $cwd = getcwd;

diag 'Generate revoked cert';

chdir $certs;

open my $fh, '>', 'revoked.ext' or die "Could not write to $certs/revoked.ext: $!";
print $fh <<"EOF";
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
subjectAltName=\@alt_names
authorityInfoAccess=OCSP;URI:http://localhost:$ocsp_port, CA Issuers;URI:http://localhost:$RT::Test::port/static/ca.pem
crlDistributionPoints=URI:http://localhost:$RT::Test::port/static/example.crl
[alt_names]
DNS.1=revoked.example.com
EOF
close $fh;

system( $openssl,
    qw!req -newkey rsa:2048 -nodes -keyout revoked.key -text -out revoked.csr -subj /CN=revoked.example.com! )
    && die "Could not create key/csr: $?";

system( $openssl, qw!req -x509 -sha256 -nodes -newkey rsa:2048 -keyout ca.key -text -out ca.pem -subj /CN=example.com! )
    && die "Could not create CA: $?";

system( $openssl,
    qw!x509 -req -CA ca.pem -CAkey ca.key -in revoked.csr -out revoked.pem -CAcreateserial -extfile revoked.ext!,
) && die "Could not sign cert: $?";

my $crt;
{
    local $/;
    open my $fh, '<', 'revoked.pem' or die "Could not read $certs/revoked.pem: $!";
    $crt = <$fh>;
    close($fh);
}

# default CA dir
mkdir 'demoCA' or die "Could not create $certs/demoCA: $!";

# Create empty index.txt for OCSP
open $fh, '>', File::Spec->catfile( 'demoCA', 'index.txt' ) or die "Could not write to $certs/demoCA/index.txt: $!";
close $fh;

system( $openssl, qw!ca -revoke revoked.pem -keyfile ca.key -cert ca.pem! ) && die "Could not revoke cert: $?";


open $fh, '>', File::Spec->catfile( 'demoCA', 'crlnumber' ) or die "Could not write to $certs/demoCA/crlnumber: $!";
print $fh '01';    # initial crlnumber
close $fh;

system( $openssl, qw!ca -gencrl -out example.crl -keyfile ca.key -cert ca.pem!, )
    && die "Could not generate example.crl: $?";

if ( my $pid = fork() ) {
    chdir $cwd;    # get back from temp dir that will be cleaned up
    my $ca      = File::Spec->catfile( $certs,                   'ca.pem' );
    my $keyring = File::Spec->catfile( RT::Test->temp_directory, 'smime' );
    RT->Config->Set(
        'SMIME',
        Enable    => 1,
        OpenSSL   => $openssl,
        Keyring   => $keyring,
        CAPath    => $ca,
        CheckCRL  => 1,
        CheckOCSP => 1,
    );

    # so openssl can download ca.pem and example.crl
    RT->Config->Set( LocalStaticPath => $certs );

    RT::Test->started_ok;

    my %res;
    %res = RT::Crypt::SMIME->GetCertificateInfo( Certificate => $crt );
    is(
        $res{info}[0]{Trust},
        "REVOKED certificate checked against OCSP URI http://localhost:$ocsp_port",
        'Trust info indicates revoked certificate using OCSP'
    );
    is( $res{info}[0]{TrustTerse}, 'none (revoked certificate)', 'TrustTerse indicates revoked certificate' );

    # Now disable OCSP
    RT::Test->stop_server;
    RT->Config->Set(
        'SMIME',
        Enable    => 1,
        OpenSSL   => $openssl,
        Keyring   => $keyring,
        CAPath    => $ca,
        CheckCRL  => 1,
        CheckOCSP => 0,
    );
    RT::Test->started_ok;

    %res = RT::Crypt::SMIME->GetCertificateInfo( Certificate => $crt );
    is(
        $res{info}[0]{Trust},
        'REVOKED certificate from CA example.com',
        'Trust info indicates revoked certificate using CRL'
    );
    is( $res{info}[0]{TrustTerse}, 'none (revoked certificate)', 'TrustTerse indicates revoked certificate' );

    # Disable both OCSP and CRL... cert should verify
    RT::Test->stop_server;
    RT->Config->Set(
        'SMIME',
        Enable    => 1,
        OpenSSL   => $openssl,
        Keyring   => $keyring,
        CAPath    => $ca,
        CheckCRL  => 0,
        CheckOSCP => 0,
    );
    RT::Test->started_ok;

    %res = RT::Crypt::SMIME->GetCertificateInfo( Certificate => $crt );
    is( $res{info}[0]{Trust},      'Signed by trusted CA example.com' );
    is( $res{info}[0]{TrustTerse}, 'full' );

    kill 'KILL', $pid;
    waitpid $pid, 0;
    done_testing;
}
else {
    # start ocsp server
    exec( $openssl, qw!ocsp -index demoCA/index.txt -CA ca.pem -rsigner ca.pem -rkey ca.key -port!, $ocsp_port );
}
