use strict;
use warnings;

package RT::Action::EditWatchers;
use base qw/RT::Action Jifty::Action/;
use RT::View::Helpers qw/render_user/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('record');

sub arguments {
    my $self = shift;
    return {} unless $self->record;
    my $args = {};
    $args->{record_id} = {
        render_as     => 'hidden',
        default_value => $self->record->id,
    };
    $args->{record_class} = {
        render_as     => 'hidden',
        default_value => ref $self->record,
    };

    for my $type (qw/cc admin_cc/) {
        for my $sub_type (qw/users groups/) {
            $args->{"${type}_$sub_type"} = {
                default_value => defer {
                    $self->default_value( $type, $sub_type );
                },
                available_values =>
                  defer { $self->available_values($sub_type) },
                render_as => 'Checkboxes',
                multiple  => 1,
                label     => "$type $sub_type",
            };
        }
    }

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $record_class = $self->argument_value('record_class');
    return unless $record_class;
    if ( $record_class eq 'RT::System' ) {
        $self->record( RT->system );
    }
    elsif ( $RT::Model::ACE::OBJECT_TYPES{$record_class} ) {
        my $object = $record_class->new;
        my $record_id = $self->argument_value('record_id');
        $object->load($record_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load $record_class #$record_id");
            return;
        }

        $self->record($object);
    }
    else {
        Jifty->log->error("record class '$record_class' is incorrect");
        return;
    }

    for my $arg ( $self->argument_names ) {
        next
          unless ( $arg =~ /^(cc|admin_cc)_(users|groups)$/ );
        use Data::Dumper;

        #        Jifty->log->error( Dumper \%ids );

        my ( $type, $sub_type ) = ( $1, $2 );
        my @ids;
        my $value = $self->argument_value($arg);
        if ( UNIVERSAL::isa( $self->argument_value($arg), 'ARRAY' ) ) {
            @ids = @$value;
        }
        else {
            @ids = $value;
        }

        @ids = grep $_, @ids;

        my $current = $self->default_value( $type, $sub_type );
        my %current = map { $_->{value} => 1 } @$current;
        my %ids     = map { $_          => 1 } @ids;

        for my $id ( keys %current ) {
            next if $ids{$id};
            my ( $val, $msg ) = $self->record->delete_watcher(
                type      => $type,
                principal => $id,
            );
            Jifty->log->error($msg) unless $val;
        }

        for my $id ( keys %ids ) {
            next if $current{$id};
            my ( $val, $msg ) = $self->record->add_watcher(
                type      => $type,
                principal => $id,
            );
            Jifty->log->error($msg) unless $val;
        }
    }

    $self->report_success;
    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(_('Updated watchers'));
}

sub available_values {
    my $self     = shift;
    my $sub_type = shift;
    if ( $sub_type eq 'users' ) {
        my $users = RT::Model::UserCollection->new;

        #XXX do we need to limit to only privileged people?
        $users->limit_to_privileged;
        $users->order_by( { column => 'name', order => 'ASC' } );
        my @users;
        while ( my $user = $users->next ) {
            push @users,
              {
                display => render_user($user),
                value => $user->principal_id
              };
        }
        return \@users;
    }
    else {
        my $groups = RT::Model::GroupCollection->new;
        $groups->limit_to_user_defined_groups;
        $groups->order_by( { column => 'name', order => 'ASC' } );
        my @groups;
        while ( my $group = $groups->next ) {
            push @groups,
              { display => $group->name, value => $group->principal_id };
        }
        return \@groups;
    }
}

sub default_value {
    my $self     = shift;
    my $type     = shift;
    my $sub_type = shift;
    my $group    = $self->record->role_group($type);
    return [] unless $group->id;
    my $current =
        $sub_type eq 'users'
      ? $group->user_members( recursively => 0 )
      : $group->group_members( recursively => 0 );

    my @current;
    while ( my $member = $current->next ) {
        push @current,
          {
            value   => $member->id,
            display => $member->name
          };
    }
    return \@current;
}

1;

