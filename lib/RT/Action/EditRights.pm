
use strict;
use warnings;

package RT::Action::EditRights;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;

__PACKAGE__->mk_accessors('record');

# don't use this directly, use EditUserRights or EditGroupRights instead
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
          unless ( $arg =~ /^rights_(\d+)$/ );

        my $principal_id = $1;

        my @rights;
        my $value = $self->argument_value($arg);
        if ( UNIVERSAL::isa( $self->argument_value($arg), 'ARRAY' ) ) {
            @rights = @$value;
        }
        else {
            @rights = $value;
        }

        @rights = grep $_, @rights;

        my $principal = RT::Model::Principal->new;
        $principal->load($principal_id);

        my $current_rights = $self->default_value($principal_id);
        my %current_rights = map { $_ => 1 } @$current_rights;
        my %rights         = map { $_ => 1 } @rights;

        for my $right ( keys %current_rights ) {
            next if $rights{$right};
            my ( $val, $msg ) =
              $principal->revoke_right( object => $self->record, right => $right );
            Jifty->log->error($msg) unless $val;
        }

        for my $right ( keys %rights ) {
            next if $current_rights{$right};
            my ( $val, $msg ) =
              $principal->grant_right( object => $self->record, right => $right );
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
    $self->result->message(_('Updated rights'));
}

sub available_values {
    my $self   = shift;
    my $object = $self->record;
    my $rights = $object->available_rights;
    return [ sort keys %$rights ];
}

sub default_value {
    my $self  = shift;
    my $principal_id = shift;

    my $object = $self->record;
    my $acl_obj = RT::Model::ACECollection->new;
    my $ACE = RT::Model::ACE->new;
    $acl_obj->limit_to_object($object);
    $acl_obj->limit_to_principal( id => $principal_id );
    $acl_obj->order_by( column => 'right_name' );

    my @rights;
    while ( my $acl = $acl_obj->next ) {
        push @rights, $acl->right_name;
    }
    return [@rights];
}

1;

