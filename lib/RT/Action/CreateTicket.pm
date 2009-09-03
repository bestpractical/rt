package RT::Action::CreateTicket;
use strict;
use warnings;
use base 'RT::Action::QueueBased', 'Jifty::Action::Record::Create';

use constant record_class => 'RT::Model::Ticket';
use constant report_detailed_messages => 1;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param status =>
        render as 'select',
        valid_values are 'new', 'open'; # XXX

    param owner =>
        render as 'select',
        valid_values are RT->nobody;
};

sub after_set_queue {
    my $self  = shift;
    my $queue = shift;
    $self->SUPER::after_set_queue(@_);

    $self->set_valid_statuses($queue);
    $self->set_valid_owners($queue);
}

sub set_valid_statuses {
    my $self  = shift;
    my $queue = shift;

    my @valid_statuses = $queue->status_schema->valid;
    $self->{_cached_arguments}{status}{valid_values} = \@valid_statuses;
}

sub set_valid_owners {
    my $self  = shift;
    my $queue = shift;

    my $isSU = Jifty->web->current_user->has_right(
        right => 'SuperUser',
        object => RT->system,
    );

    my $users = RT::Model::UserCollection->new;
    $users->who_have_right(
        right               => 'OwnTicket',
        object              => $queue,
        include_system_rights => 1,
        include_superusers   => $isSU,
    );

    my %user_uniq_hash;
    while (my $user = $users->next) {
        # skip nobody here, so we can make them first later
        next if $user->id == RT->nobody->id;

        $user_uniq_hash{ $user->id } = $user;
    }

    my @valid_owners = sort { uc( $a->name ) cmp uc( $b->name ) }
                       values %user_uniq_hash;
    unshift @valid_owners, RT->nobody;

    $self->{_cached_arguments}{status}{valid_values} = \@valid_owners;
}

1;

