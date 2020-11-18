use strict;
use warnings;

use RT::Test::SMIME tests => undef;

sub extract_email_address
{
    my ($base) = @_;
    my $cert;
    {
        local $/;
        open(my $fh, "<t/data/smime/keys/$base.crt") or die ("Cannot open t/data/smime/keys/$base.crt: $!");
        $cert = <$fh>;
        close($fh);
    }
    if ($cert =~ /^-----BEGIN \s+ CERTIFICATE----- \s* $
    (.*?)
    ^-----END \s+ CERTIFICATE----- \s* $/smx) {
        $cert = MIME::Base64::decode_base64($1);
    }

    my $c = Crypt::X509->new(cert => $cert);
    return RT::Crypt::SMIME->ExtractSubjectEmailAddress($c);
}

foreach my $addr ('dianne@skoll.ca', 'root@example.com', 'sender@example.com', 'smime@example.com') {
    is (extract_email_address($addr), $addr, "$addr: Correct email address extracted from S/MIME certificate");
}


done_testing;
