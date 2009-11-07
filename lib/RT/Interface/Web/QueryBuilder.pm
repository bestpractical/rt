package RT::Interface::Web::QueryBuilder;
use warnings;
use strict;

sub setup_query {

    my $saved_search = {};
    my $query = { map { $_ => Jifty->web->request->argument($_) } qw(query format order_by order rows_per_page) };
    my @actions = RT::Interface::Web::QueryBuilder->load_saved_search( Jifty->web->request->arguments(), $query, $saved_search );

    if ( Jifty->web->request->argument('new_query') ) {

        # Wipe all data-carrying variables clear if we want a new
        # search, or we're deleting an old one..
        $query = {};
        $saved_search = { id => 'new' };

        # ..then wipe the sessionand the search results.
        Jifty->web->session->remove('CurrentSearchHash');
        Jifty->web->session->get('tickets')->clean_slate if defined Jifty->web->session->get('tickets');
    }

    RT::Interface::Web::QueryBuilder->set_query_defaults($query);
    return ( $saved_search, $query, \@actions );
}


sub set_query_defaults {
    my $self  = shift;
    my $query = shift;

    # Attempt to load what we can from the session and preferences, set defaults

    my $current = Jifty->web->session->get('CurrentSearchHash');
    my $prefs   = Jifty->web->current_user->user_object->preferences("SearchDisplay") || {};
    my $default = { query => '', format => '', order_by => 'id', order => 'ASC', rows_per_page => 50 };

    for my $param (qw(query format order_by order rows_per_page)) {
        $query->{$param} = $current->{$param} unless defined $query->{$param};
        $query->{$param} = $prefs->{$param}   unless defined $query->{$param};
        $query->{$param} = $default->{$param} unless defined $query->{$param};
    }

    for my $param (qw(order order_by)) {
        $query->{$param} = join( '|', @{ $query->{$param} } ) if ( ref $query->{$param} eq "ARRAY" );
    }

    $query->{'format'} = RT::Interface::Web->scrub_html( $query->{'format'} ) if ( $query->{'format'} );
}

sub process_query {
    my $self     = shift;
    my $ARGS     = shift;
    my $tree     = shift;
    my $selected = shift;
    my $new      = shift || [];

    my @NewSelection = ();

    my @results;
    if ( $ARGS->{'up'} || $ARGS->{'down'} ) {
        if (@$selected) {
            foreach my $value (@$selected) {
                my $parent   = $value->getParent;
                my $index    = $value->getIndex;
                my $newindex = $index;
                $newindex++ if $ARGS->{'down'};
                $newindex-- if $ARGS->{'up'};
                if ( $newindex < 0 || $newindex >= $parent->getChildCount ) {
                    push( @results, [ _("error: can't move up"),   -1 ] ) if $ARGS->{'up'};
                    push( @results, [ _("error: can't move down"), -1 ] ) if $ARGS->{'down'};
                    next;
                }

                $parent->removeChild($index);
                $parent->insertChild( $newindex, $value );
            }
        } else {
            push( @results, [ _("error: nothing to move"), -1 ] );
        }
    } elsif ( $ARGS->{"left"} ) {
        if (@$selected) {
            foreach my $value (@$selected) {
                my $parent = $value->getParent;
                if ( $value->isRoot || $parent->isRoot ) {
                    push( @results, [ _("error: can't move left"), -1 ] );
                    next;
                }

                my $grandparent = $parent->getParent;
                if ( $grandparent->isRoot ) {
                    push( @results, [ _("error: can't move left"), -1 ] );
                    next;
                }

                my $index = $parent->getIndex;
                $parent->removeChild($value);
                $grandparent->insertChild( $index, $value );
                if ( $parent->isLeaf ) {
                    $grandparent->removeChild($parent);
                }
            }
        } else {
            push( @results, [ _("error: nothing to move"), -1 ] );
        }
    } elsif ( $ARGS->{"right"} ) {
        if (@$selected) {
            foreach my $value (@$selected) {
                my $parent = $value->getParent;
                my $index  = $value->getIndex;

                my $newparent;
                if ( $index > 0 ) {
                    my $sibling = $parent->getChild( $index - 1 );
                    $newparent = $sibling unless $sibling->isLeaf;
                }
                $newparent ||= RT::Interface::Web::QueryBuilder::Tree->new( $ARGS->{'and_or'} || 'AND', $parent );

                $parent->removeChild($value);
                $newparent->addChild($value);
            }
        } else {
            push( @results, [ _("error: nothing to move"), -1 ] );
        }
    } elsif ( $ARGS->{"delete_clause"} ) {
        if (@$selected) {
            my (@top);
            my %Selected = map { $_ => 1 } @$selected;
            foreach my $node (@$selected) {
                my $tmp = $node->getParent;
                while ( !$Selected{$tmp} && !$tmp->isRoot ) {
                    $tmp = $tmp->getParent;
                }
                next if $Selected{$tmp};
                push @top, $node;
            }

            my %seen;
            my @non_siblings_top = grep !$seen{ $_->getParent }++, @top;

            foreach (@$new) {
                my $add = $_->clone;
                foreach my $sel (@non_siblings_top) {
                    my $newindex = $sel->getIndex + 1;
                    $sel->insertSibling( $newindex, $add );
                }
                $add->getParent->setNodeValue( $ARGS->{'and_or'} );
                push @NewSelection, $add;
            }
            @$new = ();

            while ( my $node = shift @top ) {
                my $parent = $node->getParent;
                $parent->removeChild($node);
                $node->DESTROY;
            }
            @$selected = ();
        } else {
            push( @results, [ _("error: nothing to delete"), -1 ] );
        }
    } elsif ( $ARGS->{"toggle"} ) {
        if (@$selected) {
            my %seen;
            my @unique_nodes = grep !$seen{ $_ + 0 }++, map ref $_->getNodeValue ? $_->getParent : $_, @$selected;

            foreach my $node (@unique_nodes) {
                if ( $node->getNodeValue eq 'AND' ) {
                    $node->setNodeValue('OR');
                } else {
                    $node->setNodeValue('AND');
                }
            }
        } else {
            push( @results, [ _("error: nothing to toggle"), -1 ] );
        }
    }

    if ( @$new && @$selected ) {
        my %seen;
        my @non_siblings_selected = grep !$seen{ $_->getParent }++, @$selected;

        foreach (@$new) {
            my $add = $_->clone;
            foreach my $sel (@non_siblings_selected) {
                my $newindex = $sel->getIndex + 1;
                $sel->insertSibling( $newindex, $add );
            }
            $add->getParent->setNodeValue( $ARGS->{'and_or'} );
            push @NewSelection, $add;
        }
        @$selected = ();
    } elsif (@$new) {
        foreach (@$new) {
            my $add = $_->clone;
            $tree->addChild($add);
            push @NewSelection, $add;
        }
        $tree->setNodeValue( $ARGS->{'and_or'} );
    }
    $_->DESTROY foreach @$new;

    push @$selected, @NewSelection;

    $tree->prune_childless_aggregators;

    return @results;
}

sub process_query_additions {
    my $self     = shift;
    my $cgi_args = shift;
    my @new_values;
    foreach my $arg ( keys %$cgi_args ) {

        #  Try to find if we're adding a clause
        next
            unless $arg =~ m/^value_of_(\w+|'CF.{.*?}')$/
                && (ref $cgi_args->{$arg} eq "ARRAY"
                    ? grep $_ ne '', @{ $cgi_args->{$arg} }
                    : $cgi_args->{$arg} ne ''
                );

        my $field = $1;

        #figure out if it's a grouping
        my $keyword  = $cgi_args->{ $field . "_field" } || $field;
        my $op_name  = $field . "_op";
        my $op_value = 'value_of_' . $field;

        # we may have many keys/values to iterate over, because there
        # may be more than one CF with the same name.
        my @ops    = ref $cgi_args->{$op_value} ? @{ $cgi_args->{$op_name} }  : $cgi_args->{$op_name};
        my @values = ref $cgi_args->{$op_value} ? @{ $cgi_args->{$op_value} } : $cgi_args->{$op_value};

        Jifty->log->debug("Bad Parameters passed into Query Builder") unless @ops == @values;

        for ( my $i = 0; $i < @ops; $i++ ) {
            my ( $op, $value ) = ( $ops[$i], $values[$i] );
            next if !defined $value || $value eq '';

            if ( $value eq 'NULL' && $op eq '=' ) {
                $op = "IS";
            } elsif ( $value eq 'NULL' && $op eq '!=' ) {
                $op = "IS NOT";
            } else {
                $value =~ s/'/\\'/g;
                $value = "'$value'" unless $value =~ /^\d+$/;
            }

            push @new_values,
                RT::Interface::Web::QueryBuilder::Tree->new(
                {   Key   => $keyword,
                    Op    => $op,
                    Value => $value
                }
                );
        }
    }
    return @new_values;
}

sub load_saved_search {
    my $self          = shift;
    my $ARGS          = shift;
    my $query         = shift;
    my $saved_search  = shift;
    my $search_fields = shift || [qw( query format order_by order rows_per_page)];

    $saved_search->{'id'}          = $ARGS->{'saved_search_id'}          || 'new';
    $saved_search->{'description'} = $ARGS->{'saved_search_description'} || undef;
    $saved_search->{'Privacy'}     = $ARGS->{'saved_search_owner'}       || undef;

    my @results;

    if ( $ARGS->{'saved_search_revert'} ) {
        $ARGS->{'saved_search_load'} = $saved_search->{'id'};
    }

    if ( $ARGS->{'saved_search_load'} ) {
        my ( $container, $id ) = RT::Interface::Web::QueryBuilder::_parse_saved_search( $ARGS->{'saved_search_load'} );
        my $search = $container->attributes->with_id($id);

        $saved_search->{'id'}          = $ARGS->{'saved_search_load'};
        $saved_search->{'object'}      = $search;
        $saved_search->{'description'} = $search->description;
        $query->{$_} = $search->sub_value($_) foreach @$search_fields;

        if ( $ARGS->{'saved_search_revert'} ) {
            push @results, _( 'Loaded original "%1" saved search', $saved_search->{'description'} );
        } else {
            push @results, _( 'Loaded saved search "%1"', $saved_search->{'description'} );
        }
    } elsif ( $ARGS->{'saved_search_delete'} ) {

        # We set $SearchId to 'new' above already, so peek into the %ARGS
        my ( $container, $id ) = RT::Interface::Web::QueryBuilder::_parse_saved_search( $saved_search->{'id'} );
        if ( $container && $container->id ) {

            # We have the object the entry is an attribute on; delete the entry...
            $container->attributes->delete_entry( name => 'saved_search', id => $id );
        }
        $saved_search->{'id'}          = 'new';
        $saved_search->{'object'}      = undef;
        $saved_search->{'description'} = undef;
        push @results, _("Deleted saved search");
    } elsif ( $ARGS->{'saved_search_copy'} ) {
        my ( $container, $id ) = RT::Interface::Web::QueryBuilder::_parse_saved_search( $ARGS->{'saved_search_id'} );
        $saved_search->{'object'} = $container->attributes->withid($id);
        if (   $ARGS->{'saved_search_description'}
            && $ARGS->{'saved_search_description'} ne $saved_search->{'object'}->description )
        {
            $saved_search->{'description'} = $ARGS->{'saved_search_description'};
        } else {
            $saved_search->{'description'} = _( "%1 copy", $saved_search->{'object'}->description );
        }
        $saved_search->{'id'}     = 'new';
        $saved_search->{'object'} = undef;
    }

    if (   $saved_search->{'id'}
        && $saved_search->{'id'} ne 'new'
        && !$saved_search->{'object'} )
    {
        my ( $container, $id ) = RT::Interface::Web::QueryBuilder::_parse_saved_search( $ARGS->{'saved_search_id'} );
        $saved_search->{'object'} = $container->attributes->with_id($id);
        $saved_search->{'description'} ||= $saved_search->{'object'}->description;
    }
    return @results;
}

sub save_search {
    my $self          = shift;
    my $query         = shift;
    my $saved_search  = shift;
    my $search_fields = shift || [qw( query format order_by order rows_per_page)];

    my @results;
    my $obj     = $saved_search->{'object'};
    my $id      = $saved_search->{'id'};
    my $desc    = $saved_search->{'description'};
    my $privacy = $saved_search->{'Privacy'};

    my %params = map { $_ => $query->{$_} } @$search_fields;
    my ( $new_obj_type, $new_obj_id ) = split( /\-/, ( $privacy || '' ) );

    if ( $obj && $obj->id ) {

        # permission check
        if ( $obj->object->isa('RT::System') ) {
            unless ( Jifty->web->current_user->has_right( object => RT->system, right => 'SuperUser' ) ) {
                push @results, _("No permission to save system-wide searches");
                return @results;
            }
        }

        $obj->set_sub_values(%params);
        $obj->set_description($desc);

        my $obj_type = ref( $obj->object );

        # We need to get current obj_id now, because when we change obj_type to
        # RT::System, $obj->object->id returns 1, not the old one :(
        my $obj_id = $obj->object->id;

        if ( $new_obj_type && $new_obj_id ) {
            my ( $val, $msg );
            if ( $new_obj_type ne $obj_type ) {
                ( $val, $msg ) = $obj->set_objectType($new_obj_type);
                push @results, _( 'Unable to set privacy object: %1', $msg ) unless ($val);
            }
            if ( $new_obj_id != $obj_id ) {
                ( $val, $msg ) = $obj->set_objectid($new_obj_id);
                push @results, _( 'Unable to set privacy id: %1', $msg ) unless ($val);
            }
        } else {
            push @results, _('Unable to determine object type or id');
        }
        push @results, _( 'Updated saved search "%1"', $desc );
    } elsif ( $id eq 'new' ) {
        my $saved_search = RT::SavedSearch->new();
        my ( $status, $msg ) = $saved_search->save(
            privacy       => $privacy,
            name          => $desc,
            type          => $saved_search->{'type'},
            search_params => \%params,
        );

        if ($status) {
            $saved_search->{'object'} = Jifty->web->current_user->user_object->attributes->with_id( $saved_search->id );

            # Build new SearchId
            $saved_search->{'id'}
                = ref( Jifty->web->current_user->user_object ) . '-'
                . Jifty->web->current_user->user_object->id
                . '-SavedSearch-'
                . $saved_search->{'object'}->id;
        } else {
            push @results, _("Can't find a saved search to work with") . ': ' . _($msg);
        }
    } else {
        push @results, _("Can't save this search");
    }

    return @results;
}

=head2 _parse_saved_search ( $arg );

Given a serialization string for saved search, and returns the
container object and the search id.

=cut

sub _parse_saved_search {
    my $spec = shift;
    return unless $spec;
    if ( $spec !~ /^(.*?)-(\d+)-SavedSearch-(\d+)$/ ) {
        return;
    }
    my $obj_type  = $1;
    my $obj_id    = $2;
    my $search_id = $3;

    return ( _load_container_object( $obj_type, $obj_id ), $search_id );
}

=head2 _load_container_object ( $type, $id );

Instantiate container object for saving searches.

=cut

sub _load_container_object {
    my ( $obj_type, $obj_id ) = @_;
    return RT::SavedSearch->new()->_load_privacy_object( $obj_type, $obj_id );
}

sub build_format_string {
    my $self = shift;
    my %args = (
        format                  => undef,
        queues                  => undef,
        face                    => undef,
        size                    => undef,
        link                    => undef,
        title                   => undef,
        add_col                 => undef,
        remove_col              => undef,
        col_up                  => undef,
        col_down                => undef,
        select_display_columns  => undef,
        current_display_columns => undef,
        @_
    );

    $args{format} = RT->config->get('default_search_result_format') unless $args{format};

    # All the things we can display in the format string by default
    my @fields = qw(
        id queue_name subject
        status extended_status update_status
        type owner_name requestors cc admin_cc created_by last_updated_by
        priority initial_priority final_priority
        time_worked time_left time_estimated
        starts      starts_relative
        started     started_relative
        created     created_relative
        last_updated last_updated_relative
        told        told_relative
        due         due_relative
        resolved    resolved_relative
        refers_to    referred_to_by
        depends_on   depended_on_by
        member_of    members
        parents     children
        Bookmark
        NEWLINE     Bookmark
        );    # loc_qw

    my $CustomFields = RT::Model::CustomFieldCollection->new();
    foreach my $id ( keys %{ $args{queues} } ) {

        # Gotta load up the $queue object, since queues get stored by name now. my $id
        my $queue = RT::Model::Queue->new();
        $queue->load($id);
        unless ( $queue->id ) {

            # XXX TODO: This ancient code dates from a former developer
            # we have no idea what it means or why queues are so encoded.
            $id =~ s/^.'*(.*).'*$/$1/;
            $queue->load($id);
        }
        $CustomFields->limit_to_queue( $queue->id );
    }
    $CustomFields->limit_to_global;

    while ( my $CustomField = $CustomFields->next ) {
        push @fields, "custom_field.{" . $CustomField->name . "}";
    }

    my (@seen);

    my @format = split( /,\s*/, $args{format} );
    foreach my $field (@format) {
        my %column = ();
        $field =~ s/'(.*)'/$1/;
        my ( $prefix, $suffix );
        if ( $field =~ m/(.*)__(.*)__(.*)/ ) {
            $prefix = $1;
            $suffix = $3;
            $field  = $2;
        }
        $field = "<blank>" if !$field;
        $column{Prefix} = $prefix;
        $column{Suffix} = $suffix;
        $field =~ s/\s*(.*)\s*/$1/;
        $column{Column} = $field;
        push @seen, \%column;
    }

    if ( $args{remove_col} ) {

        # we do this regex match to avoid a non-numeric warning
        my ($index) = $args{current_display_columns} =~ /^(\d+)/;

        my $column = $seen[$index];
        if ($index) {
            delete $seen[$index];
            my @temp = @seen;
            @seen = ();
            foreach my $element (@temp) {
                next unless $element;
                push @seen, $element;
            }
        }
    } elsif ( $args{add_col} ) {
        if ( defined $args{select_display_columns} ) {
            my $selected = $args{select_display_columns};
            my @columns;
            if ( ref($selected) eq 'ARRAY' ) {
                @columns = @$selected;
            } else {
                push @columns, $selected;
            }
            foreach my $col (@columns) {
                my %column = ();
                $column{Column} = $col;

                if ( $args{face} eq "Bold" ) {
                    $column{Prefix} .= "<b>";
                    $column{Suffix} .= "</b>";
                }
                if ( $args{face} eq "Italic" ) {
                    $column{Prefix} .= "<i>";
                    $column{Suffix} .= "</i>";
                }
                if ( $args{size} ) {
                    $column{Prefix} .= "<" . Jifty->web->escape( $args{size} ) . ">";
                    $column{Suffix} .= "</" . Jifty->web->escape( $args{size} ) . ">";
                }
                if ( $args{link} eq "Display" ) {
                    $column{Prefix} .= q{<a HREF="__WebPath__/Ticket/Display.html?id=__id__">};
                    $column{Suffix} .= "</a>";
                } elsif ( $args{link} eq "Take" ) {
                    $column{Prefix} .= q{<a HREF="__WebPath__/Ticket/Display.html?Action=Take&id=__id__">};
                    $column{Suffix} .= "</a>";
                }

                if ( $args{title} ) {
                    $column{Suffix} .= "/TITLE:" . Jifty->web->escape( $args{title} );
                }
                push @seen, \%column;
            }
        }
    } elsif ( $args{col_up} ) {
        my $index = $args{current_display_columns};
        if ( defined $index && ( $index - 1 ) >= 0 ) {
            my $column = $seen[$index];
            $seen[$index]                  = $seen[ $index - 1 ];
            $seen[ $index - 1 ]            = $column;
            $args{current_display_columns} = $index - 1;
        }
    } elsif ( $args{col_down} ) {
        my $index = $args{current_display_columns};
        if ( defined $index && ( $index + 1 ) < scalar @seen ) {
            my $column = $seen[$index];
            $seen[$index]                  = $seen[ $index + 1 ];
            $seen[ $index + 1 ]            = $column;
            $args{current_display_columns} = $index + 1;
        }
    }

    my @format_string;
    foreach my $field (@seen) {
        next unless $field;
        my $row = "'";
        $row .= $field->{'Prefix'} if defined $field->{'Prefix'};
        $row .= "__" . (
              $field->{'Column'} =~ m/\(/
            ? $field->{'Column'}    # func, don't escape
            : Jifty->web->escape( $field->{'Column'} )
            )
            . "__"
            unless ( $field->{'Column'} eq "<blank>" );
        $row .= $field->{'Suffix'} if defined $field->{'Suffix'};
        $row .= "'";
        push( @format_string, $row );
    }

    return ( join( ",\n", @format_string ), \@fields, \@seen );

}

1;
