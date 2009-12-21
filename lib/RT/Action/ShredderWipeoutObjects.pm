use strict;
use warnings;

package RT::Action::ShredderWipeoutObjects;
use base qw/RT::Action Jifty::Action/;
use Scalar::Defer;
use RT::Shredder;
use RT::Shredder::Plugin;

__PACKAGE__->mk_accessors('plugin', 'search_args');

sub arguments {
    my $self = shift;
    return {} unless $self->plugin && $self->search_args;
    my $args = {
        plugin => {
            render_as     => 'hidden',
            default_value => $self->plugin,
        },
    };

    my $plugin_obj;
    my @objs;
    $plugin_obj = $self->plugin_object;
    return unless $plugin_obj;
    my ( $status, $msg );
    {    # use additional block({}) to effectively exit block on errors

        ( $status, $msg ) =
          $plugin_obj->has_support_for_args( keys %{ $self->search_args } );
        unless ($status) {
            Jifty->log->error($msg);
#            $search = '';
            last;
        }

        ( $status, $msg ) =
          eval { $plugin_obj->test_args( %{ $self->search_args } ) };
        catch_non_fatals() && last if $@;
        unless ($status) {
            Jifty->log->error($msg);
#            $search = '';
            last;
        }
    }

    {    # use additional block({}) to effectively exit block on errors
        my $status;
        ( $status, @objs ) = eval { $plugin_obj->run };
        catch_non_fatals() && last if $@;
        unless ($status) {
            Jifty->log->error( $objs[0] );
#            $search = '';
            @objs   = ();
            last;
        }
        my $shredder = RT::Shredder->new;
        foreach my $o ( grep defined, splice @objs ) {
            eval {
                push @objs, $shredder->cast_objects_to_records( objects => $o );
            };
            catch_non_fatals() && last if $@;
        }
    }

    # TODO need more spec to the display values
    $args->{'wipeout_objects'} = {
        available_values => [
            map { { display => $_->_as_string, value => $_->_as_string } } @objs
        ],
        render_as => 'Checkboxes',
        label => _('Check objects to be wiped out'),
    };

    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self = shift;
    my $plugin = $self->argument_value('plugin');
    return unless $plugin;
    $self->plugin($plugin);

    my $plugin_obj = $self->plugin_object;
    return unless $plugin_obj;


    my $dump_file = '';
    my @messages;

    {    # use additional block({}) to effectively exit block on errors
        my $shredder = new RT::Shredder( force => 1 );
        my $backup_plugin = RT::Shredder::Plugin->new;
        my ( $status, $msg ) = $backup_plugin->load_by_name('SQLDump');
        unless ($status) {
            push @messages, $msg;
#            $search = '';
#            @objs   = ();
            last;
        }
        ( $status, $msg ) = $backup_plugin->test_args;

        unless ($status) {
            push @messages, $msg;
#            $search = '';
#            @objs   = ();
            last;
        }

        ($dump_file) = $backup_plugin->file_name;
        push @messages, "SQL dump file is '$dump_file'";

        $shredder->add_dump_plugin( object => $backup_plugin );

        $shredder->put_objects(
            objects => $self->argument_value('wipeout_objects') );
        ( $status, $msg ) = $plugin_obj->set_resolvers( Shredder => $shredder );
        unless ($status) {
            push @messages, $msg;
#            $search = '';
#            @objs   = ();
            last;
        }
        eval { $shredder->wipeout_all };

        catch_non_fatals() && last if $@;

        push @messages, _('Objects were successfuly removed');
    }

    $self->report_success( @messages );
    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message(@_);
}

sub catch_non_fatals {
    require RT::Shredder::Exceptions;
    if ( my $e = RT::Shredder::Exception::Info->caught ) {
        Jifty->log->error($e);
#        $search = '';
#        @objs   = ();
        return 1;
    }
    if ( UNIVERSAL::isa( $@, 'Class::Exception' ) ) {
        $@->rethrow;
    }
    else {
        die $@;
    }
}

sub plugin_object {
    my $self = shift;
    my $plugin_obj = RT::Shredder::Plugin->new;
    my ( $status, $msg ) = $plugin_obj->load_by_name($self->plugin);
    unless ($status) {
        Jifty->log->error($msg);
        return;
    }
    return $plugin_obj;
}

1;

