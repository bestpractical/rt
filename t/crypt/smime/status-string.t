use strict;
use warnings;

use RT::Test tests => 2;

require RT::Crypt::SMIME;
note "simple round trip";
{
    my %data = (Foo => 'bar', Baz => 'zoo');
    is_deeply(
        [ RT::Crypt::SMIME->ParseStatus( RT::Crypt::SMIME->FormatStatus( \%data, \%data ) ) ],
        [ \%data, \%data ],
    );
}

note "status appendability";
{
    my %data = (Foo => 'bar', Baz => 'zoo');
    is_deeply(
        [ RT::Crypt::SMIME->ParseStatus(
            RT::Crypt::SMIME->FormatStatus( \%data )
            . RT::Crypt::SMIME->FormatStatus( \%data )
        ) ],
        [ \%data, \%data ],
    );
}
