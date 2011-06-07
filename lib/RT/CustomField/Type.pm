package RT::CustomField::Type;
use strict;
use warnings;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;
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
