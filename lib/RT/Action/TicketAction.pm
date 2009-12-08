package RT::Action::TicketAction;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'RT::Action::WithCustomFields';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue($queue, @_);

    $self->set_valid_statuses($queue);
    $self->set_valid_owners($queue);

    $self->add_ticket_custom_fields($queue);
    $self->add_ticket_transaction_custom_fields($queue);
}

sub set_valid_statuses {
    my $self  = shift;
    my $queue = shift;

    my @valid_statuses = $self->_valid_statuses($queue);
    $self->fill_parameter(status => valid_values => \@valid_statuses);
}

sub set_valid_owners {
    my $self  = shift;
    my $queue = shift;

    my $isSU = Jifty->web->current_user->has_right(
        right  => 'SuperUser',
        object => RT->system,
    );

    my $users = RT::Model::UserCollection->new;
    $users->who_have_right(
        right                 => 'OwnTicket',
        object                => $queue,
        include_system_rights => 1,
        include_superusers    => $isSU,
    );

    my %user_uniq_hash;
    while (my $user = $users->next) {
        $user_uniq_hash{ $user->id } = $user;
    }

    # delete nobody here, so we can make them first later
    delete $user_uniq_hash{RT->nobody->id};

    my @valid_owners = sort { uc( $a->name ) cmp uc( $b->name ) }
                       values %user_uniq_hash;
    unshift @valid_owners, RT->nobody;

    $self->fill_parameter(owner => valid_values => [ map { $_->id } @valid_owners ]);
}

sub add_ticket_custom_fields {
    my $self  = shift;
    my $queue = shift;

    my $cfs = $queue->ticket_custom_fields;
    $self->_add_custom_fields(
        cfs    => $cfs,
        method => 'add_ticket_custom_field_parameter',
    );
}

sub add_ticket_transaction_custom_fields {
    my $self  = shift;
    my $queue = shift;

    my $cfs = $queue->ticket_transaction_custom_fields;
    $self->_add_custom_fields(
        cfs    => $cfs,
        method => 'add_ticket_transaction_custom_field_parameter',
    );
}

__PACKAGE__->_add_parameter_type(
    name => 'ticket_custom_field',
);

__PACKAGE__->_add_parameter_type(
    name => 'ticket_transaction_custom_field',
);

1;

