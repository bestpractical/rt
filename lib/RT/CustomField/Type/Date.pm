package RT::CustomField::Type::Date;
use strict;
use warnings;

use base qw(RT::CustomField::Type);

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

sub SearchBuilderUIArguments {
    my ($self, $cf) = @_;

    return (
        Op => {
            Type => 'component',
            Path => '/Elements/SelectDateRelation',
            Arguments => {},
        },
        Value => {
            Type => 'component',
            Path => '/Elements/SelectDate',
            Arguments => { ShowTime => 0 },
        });
}

1;
