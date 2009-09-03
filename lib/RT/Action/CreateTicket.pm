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

    $self->add_role_group_parameter(
        name          => 'requestors',
        default_value => Jifty->web->current_user->email,
    );
}

sub role_group_parameters {
    my $self = shift;
    return @{ $self->{_role_group_parameters} || [] };
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

    $self->{_cached_arguments}{owner}{valid_values} = [
        map { {
            display => $_->name, # XXX: should use ShowUser or something
            value   => $_->id,
        } } @valid_owners,
    ];
}

sub add_role_group_parameter {
    my $self = shift;
    my %args = @_;

    my $name = delete $args{name};

    push @{ $self->{_role_group_parameters} }, $name;

    $self->{_cached_arguments}{$name} = {
        render_as      => 'text',
        display_length => 40,
        %args,
    };
}

1;

