package RT::Interface::Web::QueryBuilder;
use warnings;
use strict;

sub process_query {
	my $self = shift;
	my $ARGS = shift;
	my $tree = shift;
	my $selected = shift;
	my $new = shift || [];

my @NewSelection = ();

my @results;
if ( $ARGS->{'up'} || $ARGS->{'down'} ) {
    if (@$selected) {
        foreach my $value (@$selected) {
            my $parent = $value->getParent;
            my $index = $value->getIndex;
            my $newindex = $index;
            $newindex++ if $ARGS->{'down'};
            $newindex-- if $ARGS->{'up'};
            if ( $newindex < 0 || $newindex >= $parent->getChildCount ) {
                push( @results, [ _("error: can't move up"), -1 ] ) if $ARGS->{'up'};
                push( @results, [ _("error: can't move down"), -1 ] ) if $ARGS->{'down'};
                next;
            }

            $parent->removeChild( $index );
            $parent->insertChild( $newindex, $value );
        }
    }
    else {
        push( @results, [ _("error: nothing to move"), -1 ] );
    }
}
elsif ( $ARGS->{"left"} ) {
    if (@$selected) {
        foreach my $value (@$selected) {
            my $parent = $value->getParent;
            if( $value->isRoot || $parent->isRoot ) {
                push( @results, [ _("error: can't move left"), -1 ] );
                next;
            }

            my $grandparent = $parent->getParent;
            if( $grandparent->isRoot ) {
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
    }
    else {
        push( @results, [ _("error: nothing to move"), -1 ] );
    }
}
elsif ( $ARGS->{"right"} ) {
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
    }
    else {
        push( @results, [ _("error: nothing to move"), -1 ] );
    }
}
elsif ( $ARGS->{"delete_clause"} ) {
    if (@$selected) {
        my (@top);
        my %Selected = map { $_ => 1 } @$selected;
        foreach my $node ( @$selected ) {
            my $tmp = $node->getParent;
            while ( !$Selected{ $tmp } && !$tmp->isRoot ) {
                $tmp = $tmp->getParent;
            }
            next if $Selected{ $tmp };
            push @top, $node;
        }

        my %seen;
        my @non_siblings_top = grep !$seen{ $_->getParent }++, @top;

        foreach ( @$new ) {
            my $add = $_->clone;
            foreach my $sel( @non_siblings_top ) {
                my $newindex = $sel->getIndex + 1;
                $sel->insertSibling( $newindex, $add );
            }
            $add->getParent->setNodeValue( $ARGS->{'and_or'} );
            push @NewSelection, $add;
        }
        @$new = ();
    
        while( my $node = shift @top ) {
            my $parent = $node->getParent;
            $parent->removeChild($node);
            $node->DESTROY;
        }
        @$selected = ();
    }
    else {
        push( @results, [ _("error: nothing to delete"), -1 ] );
    }
}
elsif ( $ARGS->{"toggle"} ) {
    if (@$selected) {
        my %seen;
        my @unique_nodes = grep !$seen{ $_ + 0 }++,
            map ref $_->getNodeValue? $_->getParent: $_,
            @$selected;

        foreach my $node ( @unique_nodes ) {
            if ( $node->getNodeValue eq 'AND' ) {
                $node->setNodeValue('OR');
            }
            else {
                $node->setNodeValue('AND');
            }
        }
    }
    else {
        push( @results, [ _("error: nothing to toggle"), -1 ] );
    }
}

if ( @$new && @$selected ) {
    my %seen;
    my @non_siblings_selected = grep !$seen{ $_->getParent }++, @$selected;

    foreach ( @$new ) {
        my $add = $_->clone;
        foreach my $sel( @non_siblings_selected ) {
            my $newindex = $sel->getIndex + 1;
            $sel->insertSibling( $newindex, $add );
        }
        $add->getParent->setNodeValue( $ARGS->{'and_or'} );
        push @NewSelection, $add;
    }
    @$selected = ();
}
elsif ( @$new ) {
    foreach ( @$new ) {
        my $add = $_->clone;
        $tree->addChild( $add );
        push @NewSelection, $add;
    }
    $tree->setNodeValue( $ARGS->{'and_or'} );
}
$_->DESTROY foreach @$new;

push @$selected, @NewSelection;

$tree->prune_childless_aggregators;

return @results;
}
1;
