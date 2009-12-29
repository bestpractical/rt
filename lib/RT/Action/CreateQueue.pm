package RT::Action::CreateQueue;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Create/;

sub record_class { 'RT::Model::Queue' }

use constant report_detailed_messages => 1;

sub arguments {
    my $self = shift;

    my $args = $self->SUPER::arguments();
    for (qw/sign encrypt/) {
        $args->{$_} = {
            default_value => 0,
            render_as     => 'checkbox',
            label         => _($_),
        };
    }
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;
    $self->SUPER::take_action;
    for (qw/sign encrypt/) {
        my $method = "set_$_";
        $self->record->$method( $self->argument_value($_) );
    }
    return 1;
}

1;
