use strict;
use warnings;

package RT::Action::EditWatchers;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('object');

sub arguments {
    my $self = shift;
    return {} unless $self->object;
    my $args = {};
    $args->{object_id} = {
        render_as     => 'hidden',
        default_value => $self->object->id,
    };
    $args->{object_type} = {
        render_as     => 'hidden',
        default_value => ref $self->object,
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

    my $object_type = $self->argument_value('object_type');
    return unless $object_type;
    if ( $object_type eq 'RT::System' ) {
        $self->object( RT->system );
    }
    elsif ( $RT::Model::ACE::OBJECT_TYPES{$object_type} ) {
        my $object =
          $object_type->new( current_user => Jifty->web->current_user );
        my $object_id = $self->argument_value('object_id');
        $object->load($object_id);
        unless ( $object->id ) {
            Jifty->log->error("couldn't load $object_type #$object_id");
            return;
        }

        $self->object($object);
    }
    else {
        Jifty->log->error("object type '$object_type' is incorrect");
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
            my ( $val, $msg ) = $self->object->delete_watcher(
                type      => $type,
                principal => $id,
            );
            Jifty->log->error($msg) unless $val;
        }

        for my $id ( keys %ids ) {
            next if $current{$id};
            my ( $val, $msg ) = $self->object->add_watcher(
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
    $self->result->message('Success');
}

sub available_values {
    my $self     = shift;
    my $sub_type = shift;
    if ( $sub_type eq 'users' ) {
        my $users =
          RT::Model::UserCollection->new(
            current_user => Jifty->web->current_user );

        #XXX do we need to limit to only privileged people?
        $users->limit_to_privileged;
        $users->order_by( { column => 'name', order => 'ASC' } );
        my @users;
        while ( my $user = $users->next ) {
            push @users,
              {
                display =>
                  RT::View::Form::Field::SelectUser->_render_user($user),
                value => $user->principal_id
              };
        }
        return \@users;
    }
    else {
        my $groups =
          RT::Model::GroupCollection->new(
            current_user => Jifty->web->current_user );
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
    my $group    = $self->object->role_group($type);
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

