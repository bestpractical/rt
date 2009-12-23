use strict;
use warnings;

package RT::Action::ConfigMyRT;
use base qw/RT::Action Jifty::Action/;
use RT::View::Helpers qw/render_user/;
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

    if ( ref $self->object ne 'RT::System' ) {
        $args->{'reset'} = {
            render_as     => 'InlineButton',
            default_value => 1,
            label => 'Reset',
        };
    }

    for my $type ( qw/body summary/ ) {
        $args->{$type} = {
            available_values => defer { $self->available_values },
            default_value => defer { $self->default_value( $type ) },
            render_as => 'Checkboxes',
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
        my $object = $object_type->new;
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

    if ( $self->argument_value('reset') && $object_type ne 'RT::System' ) {
        $self->object->set_preferences('HomepageSettings', {});
    }
    else {

        my $content = $self->default_value || {};
        for my $arg ( $self->argument_names ) {
            next unless ( $arg =~ /^body|summary$/ );
            my $value = $self->argument_value($arg);

            my @panes;
            if ( UNIVERSAL::isa( $self->argument_value($arg), 'ARRAY' ) ) {
                @panes = @$value;
            }
            else {
                @panes = $value;
            }

            @panes =
              map { /(\w+)-(.*)/ ? { type => $1, name => $2 } : () }
              grep { $_ } @panes;
            $content->{$arg} = \@panes;
        }

        if ( ref $self->object eq 'RT::System' ) {
            my ($settings) =
              $self->object->attributes->named('HomepageSettings');
            $settings->set_content($content);
        }
        else {
            $self->object->set_preferences( 'HomepageSettings' => $content );
        }
    }
    $self->report_success;
    return 1;

}

sub available_values {
    my $self = shift;

    my @items =
      map { { value => "component-$_", display => $_ } }
      sort @{ RT->config->get('homepage_components') };
    my $sys = RT->system;
    for ( $sys->saved_searches ) {
        my ( $desc, $search ) = @$_;
        my $SearchType = $search->content->{'SearchType'} || 'Ticket';
        if ( $SearchType eq 'Ticket' ) {
            push @items, { value => "system-$desc", display => $desc };
        }
        else {
            my $oid =
              ref($sys) . '-' . $sys->id . '-SavedSearch-' . $search->id;
            my $type =
              ( $SearchType eq 'Ticket' ) ? _('Saved Search') : $SearchType;
            push @items, { value => "saved-$oid", display => _($type) . ": $desc" };
        }
    }
    return \@items;
}

sub default_value {
    my $self     = shift;
    my $type     = shift;
    my ( $settings ) = RT->system->attributes->named('HomepageSettings');
    my $content  = $settings ? $settings->content : {};

    if ( ref $self->object ne 'RT::System' ) {
        $content = $self->object->preferences( 'HomepageSettings', $content );
    }

    return $content unless $type;

    return unless $content && $content->{$type};

    my $values = $content->{$type} || [];
    return [ map { join '-', $_->{type}, $_->{name} } @$values ];
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}


1;

