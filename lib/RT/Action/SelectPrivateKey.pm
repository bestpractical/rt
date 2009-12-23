
use strict;
use warnings;

package RT::Action::SelectPrivateKey;
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

    $args->{private_key} = {
        render_as        => 'Select',
        default_value    => defer { $self->default_value },
        available_values => defer { $self->available_values },
    };
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    my $object_type = $self->argument_value('object_type');
    return unless $object_type;
    if ( $RT::Model::ACE::OBJECT_TYPES{$object_type} ) {
        my $object    = $object_type->new;
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

    my $email = $self->object->email;
    my ( $status, $msg ) =
      $self->object->set_private_key( $self->argument_value('private_key') );
    if ( $status ) {
        $self->report_success;
    }
    else {
        Jifty->log->error( $msg );
    }

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
    my $self   = shift;
    my $email = $self->object->email;
    my %keys_meta = RT::Crypt::GnuPG::get_keys_for_signing( $email, 'force' );

    return [
        { display => _('no private key'), value => '' },
        map $_->{'key'},
        @{ $keys_meta{'info'} }
    ];
}

sub default_value {
    my $self      = shift;
    return $self->object->private_key,
}

1;

