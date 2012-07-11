#!/usr/bin/perl
use strict;
use warnings;

use RT::Test::SMIME tests => 3;

{ # OpenSSL 0.9.8r 8 Feb 2011
    my $cert = <<'END';
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            8a:6a:cd:51:be:94:a0:16
        Signature Algorithm: sha1WithRSAEncryption
        Issuer:
            countryName=AU
            stateOrProvinceName=Some-State
            organizationName=Internet Widgits Pty Ltd
            commonName=CA Owner
            emailAddress=ca.owner@example.com
        Validity
            Not Before: Dec 28 21:46:42 2011 GMT
            Not After : Aug 18 21:46:42 2036 GMT
        Subject:
            countryName=AU
            stateOrProvinceName=Some-State
            organizationName=Internet Widgits Pty Ltd
            commonName=Enoch Root
            emailAddress=root@example.com
SHA1 Fingerprint=3C:CC:22:59:BA:65:41:7D:75:CE:99:54:7F:B9:9B:75:0C:8C:74:B0
END
    my $expected = {
        'Certificate' => {
            'Data' => {
                'Version' => '3 (0x2)',
                'Subject' => {
                               'commonName' => 'Enoch Root',
                               'emailAddress' => 'root@example.com',
                               'organizationName' => 'Internet Widgits Pty Ltd',
                               'stateOrProvinceName' => 'Some-State',
                               'countryName' => 'AU'
                             },
                'Serial Number' => '8a:6a:cd:51:be:94:a0:16',
                'Issuer' => {
                              'commonName' => 'CA Owner',
                              'emailAddress' => 'ca.owner@example.com',
                              'organizationName' => 'Internet Widgits Pty Ltd',
                              'stateOrProvinceName' => 'Some-State',
                              'countryName' => 'AU'
                            },
                'Validity' => {
                                'Not Before' => 'Dec 28 21:46:42 2011 GMT',
                                'Not After' => 'Aug 18 21:46:42 2036 GMT'
                              },
                'Signature Algorithm' => 'sha1WithRSAEncryption',
            },
        },
        'SHA1 Fingerprint' => '3C:CC:22:59:BA:65:41:7D:75:CE:99:54:7F:B9:9B:75:0C:8C:74:B0'
    };

    my %info = RT::Crypt::SMIME->ParseCertificateInfo( $cert );
    is_deeply(
        \%info,
        $expected,
    );
}

{ # OpenSSL 1.0.1 14 Mar 2012
    my $cert = <<'END';
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 9974010075738841110 (0x8a6acd51be94a016)
    Signature Algorithm: sha1WithRSAEncryption
        Issuer:
            countryName=AU
            stateOrProvinceName=Some-State
            organizationName=Internet Widgits Pty Ltd
            commonName=CA Owner
            emailAddress=ca.owner@example.com
        Validity
            Not Before: Dec 28 21:46:42 2011 GMT
            Not After : Aug 18 21:46:42 2036 GMT
        Subject:
            countryName=AU
            stateOrProvinceName=Some-State
            organizationName=Internet Widgits Pty Ltd
            commonName=Enoch Root
            emailAddress=root@example.com
SHA1 Fingerprint=3C:CC:22:59:BA:65:41:7D:75:CE:99:54:7F:B9:9B:75:0C:8C:74:B0
END
    my $expected = {
        'Certificate' => {
            'Data' => {
                'Version' => '3 (0x2)',
                'Subject' => {
                               'commonName' => 'Enoch Root',
                               'emailAddress' => 'root@example.com',
                               'organizationName' => 'Internet Widgits Pty Ltd',
                               'stateOrProvinceName' => 'Some-State',
                               'countryName' => 'AU'
                             },
                'Serial Number' => '9974010075738841110 (0x8a6acd51be94a016)',
                'Issuer' => {
                              'commonName' => 'CA Owner',
                              'emailAddress' => 'ca.owner@example.com',
                              'organizationName' => 'Internet Widgits Pty Ltd',
                              'stateOrProvinceName' => 'Some-State',
                              'countryName' => 'AU'
                            },
                'Validity' => {
                                'Not Before' => 'Dec 28 21:46:42 2011 GMT',
                                'Not After' => 'Aug 18 21:46:42 2036 GMT'
                              },
            },
            'Signature Algorithm' => 'sha1WithRSAEncryption',
        },
        'SHA1 Fingerprint' => '3C:CC:22:59:BA:65:41:7D:75:CE:99:54:7F:B9:9B:75:0C:8C:74:B0'
    };

    my %info = RT::Crypt::SMIME->ParseCertificateInfo( $cert );
    is_deeply(
        \%info,
        $expected,
    );
}

