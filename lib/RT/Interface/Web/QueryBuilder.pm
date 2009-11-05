package RT::Interface::Web::QueryBuilder;
use warnings;
use strict;

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
        my ( $container, $id ) = _parse_saved_search( $ARGS->{'saved_search_load'} );
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
        my ( $container, $id ) = _parse_saved_search( $saved_search->{'id'} );
        if ( $container && $container->id ) {

            # We have the object the entry is an attribute on; delete the entry...
            $container->attributes->delete_entry( name => 'saved_search', id => $id );
        }
        $saved_search->{'id'}          = 'new';
        $saved_search->{'object'}      = undef;
        $saved_search->{'description'} = undef;
        push @results, _("Deleted saved search");
    } elsif ( $ARGS->{'saved_search_copy'} ) {
        my ( $container, $id ) = _parse_saved_search( $ARGS->{'saved_search_id'} );
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
        my ( $container, $id ) = _parse_saved_search( $ARGS->{'saved_search_id'} );
        $saved_search->{'object'} = $container->attributes->with_id($id);
        $saved_search->{'description'} ||= $saved_search->{'object'}->description;
    }

    return @results;
}


sub save_search {
    my $self          = shift;
    my $ARGS          = shift;
    my $query         = shift;
    my $saved_search  = shift;
    my $search_fields = shift || [qw( query format order_by order rows_per_page)];

    return unless $ARGS->{'saved_search_save'} || $ARGS->{'saved_search_copy'};

    my @results;
    my $obj  = $saved_search->{'object'};
    my $id   = $saved_search->{'id'};
    my $desc = $saved_search->{'description'};

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


1;
