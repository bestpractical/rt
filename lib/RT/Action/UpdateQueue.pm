package RT::Action::UpdateQueue;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::Queue' }

use constant report_detailed_messages => 1;

sub arguments {
    my $self = shift;

    my $args = $self->SUPER::arguments();
    for (qw/sign encrypt/) {
        $args->{$_} = {
            default_value => $self->record->$_,
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
    for (qw/sign encrypt/) {
        my $method = "set_$_";
        $self->record->$method( $self->argument_value($_) );
    }
    $self->SUPER::take_action;
    return 1;
}

1;
