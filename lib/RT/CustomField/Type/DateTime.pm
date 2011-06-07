package RT::CustomField::Type::DateTime;
use strict;
use warnings;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set( Format => 'unknown',
                   Value  => $args->{'Content'} );
    $args->{'Content'} = $DateObj->ISO;

    return wantarray ? (1) : 1;
}

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');

    return $content
}

sub CanonicalizeForSearch {
    my ($self, $cf, $value, $op ) = @_;
    return $value;
}

1;
