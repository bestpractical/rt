package RT::CustomField::Type::DateTime;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set( Format => 'unknown',
                   Value  => $args->{'Content'} );
    $args->{'Content'} = $DateObj->ISO;

    return wantarray ? (1) : 1;
}

1;
