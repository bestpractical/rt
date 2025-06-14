# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Interface::Web::QueryBuilder::Tree;

use strict;
use warnings;

use Tree::Simple qw/use_weak_refs/;
use base qw/Tree::Simple/;

=head1 NAME

  RT::Interface::Web::QueryBuilder::Tree - subclass of Tree::Simple used in Query Builder

=head1 DESCRIPTION

This class provides support functionality for the Query Builder (Search/Build.html).
It is a subclass of L<Tree::Simple>.

=head1 METHODS

=head2 TraversePrePost PREFUNC POSTFUNC

Traverses the tree depth-first.  Before processing the node's children,
calls PREFUNC with the node as its argument; after processing all of the
children, calls POSTFUNC with the node as its argument.

(Note that unlike Tree::Simple's C<traverse>, it actually calls its functions
on the root node passed to it.)

=cut

sub TraversePrePost {
   my ($self, $prefunc, $postfunc) = @_;

   # XXX: if pre or post action changes siblings (delete or adds)
   # we could have problems
   $prefunc->($self) if $prefunc;

   foreach my $child ($self->getAllChildren()) { 
           $child->TraversePrePost($prefunc, $postfunc);
   }
   
   $postfunc->($self) if $postfunc;
}

=head2 GetReferencedQueues

Returns a hash reference; each queue referenced with an '=' operation
will appear as a key whose value is 1.

=cut

sub GetReferencedQueues {
    my $self = shift;
    my %args = (
        CurrentUser => '',
        @_
    );

    my $queues = {};

    $self->traverse(
        sub {
            my $node = shift;

            return if $node->isRoot;
            return unless $node->isLeaf;

            my $clause = $node->getNodeValue();
            if ( $clause->{Key} =~ /^(?:Ticket)?Queue$/ ) {
                if ( $clause->{Op} eq '=' ) {
                    my $q = RT::Queue->new( $args{CurrentUser} || $HTML::Mason::Commands::session{CurrentUser} );
                    $q->Load( $clause->{Value} );
                    if ( $q->id ) {
                        # Skip ACL check
                        $queues->{ $q->id } ||= { map { $_ => $q->__Value($_) } qw/Name Lifecycle/ };
                    }
                }
                elsif ( $clause->{Op} =~ /^LIKE$/i ) {
                    my $qs = RT::Queues->new( $args{CurrentUser} || $HTML::Mason::Commands::session{CurrentUser} );
                    $qs->Limit( FIELD => 'Name', VALUE => $clause->{Value}, OPERATOR => 'LIKE', CASESENSITIVE => 0 );
                    while ( my $q = $qs->Next ) {
                        next unless $q->id;
                        # Skip ACL check
                        $queues->{ $q->id } ||= { map { $_ => $q->__Value($_) } qw/Name Lifecycle/ };
                    }
                }
            }
            elsif ( $clause->{Key} eq 'Lifecycle' ) {
                if ( $clause->{Op} eq '=' ) {
                    my $qs = RT::Queues->new( $args{CurrentUser} || $HTML::Mason::Commands::session{CurrentUser} );
                    $qs->Limit( FIELD => 'Lifecycle', VALUE => $clause->{Value} );
                    while ( my $q = $qs->Next ) {
                        next unless $q->id;
                        # Skip ACL check
                        $queues->{ $q->id } ||= { map { $_ => $q->__Value($_) } qw/Name Lifecycle/ };
                    }
                }
            }
            return;
        }
    );

    return $queues;
}

=head2 GetReferencedCatalogs

Returns a hash reference; each catalog referenced with an '=' operation
will appear as a key whose value is 1.

=cut

sub GetReferencedCatalogs {
    my $self = shift;
    my %args = (
        CurrentUser => '',
        @_,
    );

    my $catalogs = {};

    $self->traverse(
        sub {
            my $node = shift;

            return if $node->isRoot;
            return unless $node->isLeaf;

            my $clause = $node->getNodeValue();
            return unless $clause->{ Key } eq 'Catalog';
            return unless $clause->{ Op } eq '=';

            my $catalog = RT::Catalog->new( $args{CurrentUser} || $HTML::Mason::Commands::session{CurrentUser} );
            $catalog->Load( $clause->{Value} );
            if ( $catalog->Id ) {
                # Skip ACL check
                $catalogs->{ $catalog->Id } ||= { map { $_ => $catalog->__Value($_) } qw/Name Lifecycle/ };
            }
        }
    );

    return $catalogs;
}

=head2 GetQueryAndOptionList SELECTED_NODES

Given an array reference of tree nodes that have been selected by the user,
traverses the tree and returns the equivalent SQL query and a list of hashes
representing the "clauses" select option list.  Each has contains the keys
TEXT, INDEX, SELECTED, and DEPTH.  TEXT is the displayed text of the option
(including parentheses, not including indentation); INDEX is the 0-based
index of the option in the list (also used as its CGI parameter); SELECTED
is either 'SELECTED' or '', depending on whether the node corresponding
to the select option was in the SELECTED_NODES list; and DEPTH is the
level of indentation for the option.

=cut 

sub GetQueryAndOptionList {
    my $self           = shift;
    my $selected_nodes = shift;

    my $list = $self->__LinearizeTree;
    foreach my $e( @$list ) {
        $e->{'DEPTH'}    = $e->{'NODE'}->getDepth;
        $e->{'SELECTED'} = (grep $_ == $e->{'NODE'}, @$selected_nodes)? qq[ selected="selected"] : '';
    }

    return (join ' ', map $_->{'TEXT'}, @$list), $list;
}

=head2 PruneChildLessAggregators

If tree manipulation has left it in a state where there are ANDs, ORs,
or parenthesizations with no children, get rid of them.

=cut

sub PruneChildlessAggregators {
    my $self = shift;

    $self->TraversePrePost(
        undef,
        sub {
            my $node = shift;
            return unless $node->isLeaf;

            # We're only looking for aggregators (AND/OR)
            return if ref $node->getNodeValue;

            return if $node->isRoot;

            # OK, this is a childless aggregator.  Remove self.
            $node->getParent->removeChild($node);
            $node->DESTROY;
        }
    );
}

=head2 GetDisplayedNodes

This function returns a list of the nodes of the tree in depth-first
order which correspond to options in the "clauses" multi-select box.
In fact, it's all of them but the root and its child.

=cut

sub GetDisplayedNodes {
    return map $_->{NODE}, @{ (shift)->__LinearizeTree };
}


sub __LinearizeTree {
    my $self = shift;

    my ($list, $i) = ([], 0);

    $self->TraversePrePost( sub {
        my $node = shift;
        return if $node->isRoot;

        my $str = '';
        if( $node->getIndex > 0 ) {
            $str .= " ". $node->getParent->getNodeValue ." ";
        }

        unless( $node->isLeaf ) {
            $str .= '( ';
        } else {

            my $clause = $node->getNodeValue;
            my $key = $clause->{Key};
            $key .= "." . $clause->{Subkey} if defined $clause->{Subkey};
            if ($key =~ s/(['\\])/\\$1/g or $key =~ /[^{}\w\.]/) {
                $key = "'$key'";
            }
            my $value = $clause->{Value};
            my $op = $clause->{Op};
            if ( $value =~ /^NULL$/i && $op =~ /^(!?)=$/  ) {
                $op = $1 ? 'IS NOT' : 'IS';
            }

            if ( $op =~ /^IS( NOT)?$/i ) {
                $value = 'NULL';
            } elsif ( $clause->{QuoteValue} ) {
                $value =~ s/(['\\])/\\$1/g;
                $value = "'$value'";
            }

            $str .= $key ." ". $op . " " . $value;
        }
        $str =~ s/^\s+//;
        $str =~ s/\s+$//;

        push @$list, {
            NODE     => $node,
            TEXT     => $str,
            INDEX    => $i,
        };

        $i++;
    }, sub {
        my $node = shift;
        return if $node->isRoot;
        return if $node->isLeaf;
        $list->[-1]->{'TEXT'} .= ' )';
    });

    return $list;
}

sub ParseSQL {
    my $self = shift;
    my %args = (
        Query => '',
        CurrentUser => '', #XXX: Hack
        Class => 'RT::Tickets',
        @_
    );
    my $string = $args{'Query'};

    my @results;

    my %field = %{ $args{Class}->new( $args{'CurrentUser'} )->FIELDS };
    my %lcfield = map { ( lc($_) => $_ ) } keys %field;

    my $node =  $self;

    my %callback;
    $callback{'OpenParen'} = sub {
        $node = __PACKAGE__->new( 'AND', $node );
    };
    $callback{'CloseParen'} = sub { $node = $node->getParent };
    $callback{'EntryAggregator'} = sub { $node->setNodeValue( $_[0] ) };
    $callback{'Condition'} = sub {
        my ($key, $op, $value, $value_is_quoted) = @_;

        if (  !$value_is_quoted
            && $key   !~ /(?:CustomField|CF)\./
            && $value =~ /(?:CustomField|CF)\./
            && RT->Config->Get('DatabaseType') eq 'Pg' )
        {

            # E.g. LastUpdated > CF.{Beta Date}
            #
            # Pg 9 tries to cast all ObjectCustomFieldValues to datetime,
            # which could fail since not all custom fields are of DateTime
            # type. To get around this issue, here we switch the key/value
            # pair to compare as text instead.

            my ($major_version) = $RT::Handle->dbh->selectrow_array("SHOW server_version") =~ /^(\d+)/;
            if ( $major_version < 10 ) {
                my %reverse = (
                    '>'  => '<',
                    '>=' => '<=',
                    '<'  => '>',
                    '<=' => '>=',
                    '='  => '=',
                );
                if ( $reverse{$op} ) {
                    RT->Logger->debug("Switching $key/$value to compare using text");
                    ( $key, $value ) = ( $value, $key );
                    $op = $reverse{$op};
                }
            }
        }

        my ($main_key, $subkey) = split /[.]/, $key, 2;

        unless( $lcfield{ lc $main_key} ) {
            push @results, [ $args{'CurrentUser'}->loc("Unknown field: [_1]", $key), -1 ]
        }
        $main_key = $lcfield{ lc $main_key };

        if ( $op =~ /^SHALLOW\s+/i && ($main_key !~ /(?:Requestor|Owner|AdminCc|Cc|CustomRole)/) ) {
            push @results, [ $args{'CurrentUser'}->loc("Unsupported operator: [_1]", $op), -1 ];
        }

        # Hardcode value for IS / IS NOT
        $value = 'NULL' if $op =~ /^IS( NOT)?$/i;

        my $clause = {
            Key           => $main_key,
            Subkey        => $subkey,
            Meta          => $field{$main_key},
            Op            => $op,
            Value         => $value,
            QuoteValue    => $value_is_quoted,
        };
        $node->addChild( __PACKAGE__->new( $clause ) );
    };
    $callback{'Error'} = sub { push @results, @_ };

    require RT::SQL;
    RT::SQL::Parse($string, \%callback);
    return @results;
}


=head2 Split Type => intersect|union, Fields => [FIELD1, FIELD2, ...]

E.g. to split "AND" Content terms: Type => 'insersect', Fields => ['Content']

  Status = "open" AND Content LIKE "foo" AND Content LIKE "bar"

will be split into 2 subqueries:

   Status = "open" AND Content LIKE "foo"
   Status = "open" AND Content LIKE "bar"

then they can be joined via "INTERSECT".

To split "OR" Content terms: Type => 'union', Fields => ['Content']

    Content LIKE "foo" OR Subject LIKE "foo"

will be split into 2 subqueries:

    Content LIKE "foo"
    Subject LIKE "foo"

then they can be joined via "UNION". Unlike the original version, the new SQL
can make use of fulltext indexes.

Note that queries like:

    Content LIKE "foo" AND Subject LIKE "foo"

will not be split as there are no benifits, unlike the C<OR> example above.

=cut

sub Split {
    my $self = shift;
    my %args = (
        Type   => undef,
        Fields => undef,
        @_,
    );

    if ( !$args{Type} ) {
        RT->Logger->warning("Missing Type, skipping");
        return $self;
    }

    if ( $args{Type} !~ /^(?:intersect|union)$/i ) {
        RT->Logger->warning("Unsupported type $args{Type}, should be 'intersect' or 'union', skipping");
        return $self;
    }

    if ( !$args{Fields} || @{ $args{Fields} } == 0 ) {
        RT->Logger->warning("Missing Fields, skipping");
        return $self;
    }

    my @items;

    my $relation = lc $args{Type} eq 'intersect' ? 'and' : 'or';

    $self->traverse(
        sub {
            my $node = shift;
            return unless $node->isLeaf;

            if ( grep { lc $node->getNodeValue->{Key} eq lc $_ } @{ $args{Fields} } ) {
                $node = $node->getParent;
                if ( lc( $node->getNodeValue // '' ) eq $relation ) {
                    my @children = $node->getAllChildren;

                    my @splits;
                    my @others;
                    for my $child (@children) {
                        if ( $child->isLeaf && grep { lc $child->getNodeValue->{Key} eq lc $_ } @{ $args{Fields} } )
                        {
                            push @splits, $child;
                        }
                        else {
                            push @others, $child;
                        }
                    }

                    # Split others from split fields only if it's "OR" like "Content LIKE 'foo' OR Subject LIKE 'foo'"
                    return unless @splits > 1 || ( $relation eq 'or' && @splits + @others > 1 );

                    my $parent = $node->getParent;

                    my @list;

                    if ( $relation eq 'and' ) {
                        if ( @others ) {
                            for my $item ( @splits ) {
                                my $new = RT::Interface::Web::QueryBuilder::Tree->new( $relation, 'root');
                                $new->addChild($item);
                                $new->addChild($_->clone) for @others;
                                push @list, $new;
                            }
                        }
                        else {
                            @list = @splits;
                        }
                    }
                    else {
                        @list = @splits;
                        if (@others) {
                            my $others = RT::Interface::Web::QueryBuilder::Tree->new( $relation, 'root' );
                            $others->addChild( $_->clone ) for @others;
                            push @list, $others;
                        }
                    }

                    if ( $parent eq 'root' ) {
                        for my $item ( @list ) {
                            my $new = RT::Interface::Web::QueryBuilder::Tree->new( $relation, 'root');
                            $new->addChild($item->clone);
                            push @items, $new->clone->Split(%args);
                        }
                    }
                    else {
                        my $index = $node->getIndex;
                        $parent->removeChild($node);

                        for my $item ( @list ) {
                            $parent->insertChild( $index, $item );
                            push @items, $self->clone->Split(%args);
                            $parent->removeChild($item);
                        }
                    }

                    return 'ABORT';
                }
            }
        }
    );

    return @items ? @items : $self;
}



RT::Base->_ImportOverlays();

1;
