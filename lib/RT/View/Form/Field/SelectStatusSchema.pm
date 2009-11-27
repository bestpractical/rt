package RT::View::Form::Field::SelectStatusSchema;
use warnings;
use strict;
use base 'Jifty::Web::Form::Field::Select';

sub _available_values {
    return [ map { { display => $_, value => $_ } } RT::Workflow->list ];
}


1;

