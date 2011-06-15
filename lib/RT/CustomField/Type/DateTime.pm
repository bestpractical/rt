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

sub Limit {
    my ($self, $tickets, $field, $value, $op, %rest) = @_;
    return unless $op eq '=';
    if ( $value =~ /:/ ) {
        # there is time speccified.
        my $date = RT::Date->new( $tickets->CurrentUser );
        $date->Set( Format => 'unknown', Value => $value );

        $tickets->_CustomFieldLimit(
            'CF', '=', $date->ISO, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
        );
    }
    else {
        # no time specified, that means we want everything on a
        # particular day.  in the database, we need to check for >
        # and < the edges of that day.
        my $date = RT::Date->new( $tickets->CurrentUser );
        $date->Set( Format => 'unknown', Value => $value );
        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $tickets->_OpenParen;


        $tickets->_CustomFieldLimit(
            'CF', '>=', $daystart, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
        );

        $tickets->_CustomFieldLimit(
            'CF', '<=', $dayend, %rest,
            SUBKEY => $rest{'SUBKEY'}. '.Content',
            ENTRYAGGREGATOR => 'AND',
        );

        $tickets->_CloseParen;
    }
    return 1;

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
            Arguments => { ShowTime => 1 },
        });
}

1;
