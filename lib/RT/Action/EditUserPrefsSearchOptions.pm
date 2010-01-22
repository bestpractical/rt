use strict;
use warnings;

package RT::Action::EditUserPrefsSearchOptions;
use base qw/RT::Action::EditUserPrefs/;
use RT::Interface::Web::QueryBuilder;
__PACKAGE__->mk_accessors('available_columns', 'format', 'name');
use Scalar::Defer qw/defer/;

sub arguments {
    my $self = shift;
    my $args = {};
    return $args unless $self->name;

    for my $n ( 1 .. 4 ) {
        $args->{"order_$n"} = {
            label         => _("order $n"),
            default_value => defer {
                $self->default_value("order_$n");
            },
            available_values =>
              [ map { { display => _($_), value => $_ } } 'ASC', 'DESC' ],
            render_as => 'Select',
        };
        $args->{"order_by_$n"} = {
            label         => _("order by $n"),
            default_value => defer {
                $self->default_value("order_by_$n");
            },
            available_values => defer {
                $self->available_values("order_by");
            },
            render_as => 'Select',
        };
    }
    $args->{'rows_per_page'} = {
        default_value => defer { $self->default_value('rows_per_page') },
    };
    $args->{'format'} = {
        default_value => defer { $self->format },
        render_as => 'hidden',
    };
    $args->{'save'} = {
        label => _('Save'),
        render_as => 'InlineButton',
    };
    $args->{'name'} = {
        render_as     => 'hidden',
        default_value => ref $self->name
        ? ref( $self->name ) . '-' . $self->name->id
        : $self->name,
    };
    return $args;
}

sub take_action {
    my $self = shift;

    return
      unless $self->argument_value('save')
          && $self->argument_value('name');

    my $name = $self->argument_value('name');
    if ( $name =~ /RT::Model::Attribute-(\d+)/ ) {
        my $id = $1;
        my $search = RT::Model::Attribute->new;
        my ( $status, $msg ) = $search->load_by_id($id);
        unless ( $status ) {
            Jifty->log->error( "faild to load search: $name" );
            return;
        }

        $self->name($search);
    }
    else {
        $self->name($name);
    }

    my @order;
    my @order_by;
    for my $n ( 1 .. 4 ) {
        if ( $self->argument_value("order_by_$n") ) {
            push @order, $self->argument_value("order_$n")
              if $self->argument_value("order_$n");
            push @order_by, $self->argument_value("order_by_$n");
        }
    }

    my $order    = join '|', @order;
    my $order_by = join '|', @order_by;

    my ( $status, $msg ) = $self->user->set_preferences(
        $self->name,
        {
            order         => $order,
            order_by      => $order_by,
            format        => $self->argument_value('format'),
            rows_per_page => $self->argument_value('rows_per_page'),
        }
    );
    Jifty->log->error($msg) unless $status;

    $self->report_success;
    return 1;
}

sub preferences {
    my $self = shift;
    return $self->user->preferences($self->name, ref $self->name ?
            $self->name->content : () ) || {};
}

sub default_value {
    my $self = shift;
    my $arg  = shift;
    if ( $arg eq 'format' ) {
        return Jifty->web->request->argument($arg)
          || $self->preferences->{$arg};
    }
    elsif ( $arg eq 'rows_per_page' ) {
        return
             Jifty->web->request->argument($arg)
          || $self->preferences->{$arg}
          || 50;
    }
    elsif ( $arg =~ /order_(\d+)/ ) {
        my $num = $1;
        my @order =
             split '\|', Jifty->web->request->argument('order')
          || $self->preferences->{'order'}
          || 'ASC';
        return $order[$num-1];
    }
    elsif ( $arg =~ /order_by_(\d+)/ ) {
        my $num = $1;
        my @order_by =
             split '\|', Jifty->web->request->argument('order_by')
          || $self->preferences->{'order_by'}
          || 'id';
        return $order_by[$num-1];
    }
    else {
        Jifty->log->error( "unknown field: $arg" );
    }
}

sub available_values {
    my $self = shift;
    my $arg  = shift;
    if ( $arg eq 'order_by' ) {
        my $tickets = RT::Model::TicketCollection->new();
        my %fields  = %{ $tickets->columns };
        map {
            $fields{$_}->[0] =~ /^(?:ENUM|INT|DATE|STRING|ID)$/
              || delete $fields{$_}
        } keys %fields;
        delete $fields{'effective_id'};
        $fields{'Owner'} = 1;
        $fields{ $_ . '.email' } = 1 foreach (qw(Requestor Cc AdminCc));

        my @cfs = grep /^CustomField/, @{$self->available_columns};
        $fields{$_} = 1 for @cfs;

        # Add PAW sort
        $fields{'Custom.Ownership'} = 1;
        return [
            { display => _('none'), value => '' },
            map { { display => _($_), value => $_ } } keys %fields
        ];
    }
}

1;
