package RT::CustomField::Type::Date;
use strict;
use warnings;

sub CanonicalizeForCreate {
    my ($self, $cf, $ocfv, $args) = @_;

    # in case user input date with time, let's omit it by setting timezone
    # to utc so "hour" won't affect "day"
    my $DateObj = RT::Date->new( $ocfv->CurrentUser );
    $DateObj->Set( Format   => 'unknown',
                   Value    => $args->{'Content'},
                   Timezone => 'UTC',
                 );
    $args->{'Content'} = $DateObj->Date( Timezone => 'UTC' );

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
