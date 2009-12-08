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

    $self->set_valid_owners($queue);
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

1;

