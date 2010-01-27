use strict;
use warnings;

package RT::Action::ConfigMyRT;
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

    if ( ref $self->record ne 'RT::System' ) {
        $args->{'reset'} = {
            render_as     => 'Button',
            default_value => ('Reset'),
            label => '',
        };

        $args->{'summary_rows'} = {
            default_value => defer {
                $self->record->preferences( 'SummaryRows',
                    RT->config->get('default_summary_rows') );
            },
            label => 'Rows per box',
        };

    }

    for my $type ( qw/body summary/ ) {
        $args->{$type} = {
            available_values => defer { $self->available_values },
            default_value => defer { $self->default_value( $type ) },
            render_as => 'OrderedList',
            with_select => 1,
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

    if ( $self->argument_value('reset') && $record_class ne 'RT::System' ) {
        $self->record->set_preferences('HomepageSettings', {});
        Jifty->web->session->set( 'my_rt_portlets',
            $self->record->attributes->named('HomepageSettings') );
    }
    else {
        if (   $self->argument_value('summary_rows')
            && $record_class ne 'RT::System' )
        {
            my $value = int $self->argument_value('summary_rows');
            $value = 0 if $value < 0;
            $self->record->set_preferences( 'SummaryRows', $value );
        }

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

        if ( ref $self->record eq 'RT::System' ) {
            my ($settings) =
              $self->record->attributes->named('HomepageSettings');
            $settings->set_content($content);
        }
        else {
            $self->record->set_preferences( 'HomepageSettings' => $content );
            Jifty->web->session->set( 'my_rt_portlets', $content );
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

    my @objs = RT->system;
    push @objs, RT::SavedSearches->new()->_privacy_objects
      if ref $self->record ne 'RT::System' && Jifty->web->current_user->has_right(
        right  => 'LoadSavedSearch',
        object => RT->system
      );
      
    for my $obj (@objs) {
        for ( $obj->saved_searches ) {
            my ( $desc, $search ) = @$_;
            my $SearchType = $search->content->{'SearchType'} || 'Ticket';
            if ( ref $obj eq 'RT::System' && $SearchType eq 'Ticket' ) {
                push @items, { value => "system-$desc", display => $desc };
            }
            else {
                my $oid =
                  ref($obj) . '-' . $obj->id . '-SavedSearch-' . $search->id;
                my $type =
                  ( $SearchType eq 'Ticket' ) ? _('Saved Search') : $SearchType;
                push @items,
                  { value => "saved-$oid", display => _($type) . ": $desc" };
            }
        }
    }
    return \@items;
}

sub default_value {
    my $self     = shift;
    my $type     = shift;
    my ( $settings ) = RT->system->attributes->named('HomepageSettings');
    my $content  = $settings ? $settings->content : {};

    if ( ref $self->record ne 'RT::System' ) {
        $content = $self->record->preferences( 'HomepageSettings', $content );
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
    $self->result->message(_('Updated myrt'));
}


1;

