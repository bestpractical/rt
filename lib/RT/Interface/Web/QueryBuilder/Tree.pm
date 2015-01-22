# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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

=head2 traverse PREFUNC POSTFUNC

Override's L<Tree::Simple/traverse>, to call its functions on the root
node passed to it.

=cut

sub traverse {
   my ($self, $prefunc, $postfunc) = @_;

   $prefunc->($self) if $prefunc;
   $_->traverse( $prefunc, $postfunc ) for $self->getAllChildren();
   $postfunc->($self) if $postfunc;
}

=head2 GetReferencedQueues [C<CurrentUser> => I<USER>]

Returns a hash reference; the keys are the ids of each queue which
results may appear in, and the values are the respective queue objects.

In array context, returns a true/false value as a second return value,
which is if any explicit queue limits were found.

=cut

sub GetReferencedQueues {
    my $self = shift;
    my %args = (
        CurrentUser => undef,
        @_,
    );

    my $q_refs = $self->clone;
    $q_refs->traverse(
        sub {
            my $node = shift;
            my $clause = $node->getNodeValue();
            return unless $node->isLeaf and ref $clause;
            if ($clause->{Key} eq "Queue") {
                return;
            } elsif ($clause->{Key} =~ /^QueueCF\.(.*)$/) {
                # Check we can find the CF; if we can't, we fall through
                # to the below and trim out the node.
                my $subkey = $1;
                $subkey =~ s/^\{(.*?)\}$/$1/;

                my $cf;
                if ( $subkey =~ /\D/ ) {
                    my $cfs = RT::CustomFields->new( $args{CurrentUser} );
                    $cfs->Limit( FIELD => 'Name', VALUE => $subkey, CASESENSITIVE => 0 );
                    $cfs->LimitToLookupType(RT::Queue->CustomFieldLookupType);
                    $cf = $cfs->First;
                } else {
                    $cf = RT::CustomField->new( $args{CurrentUser} );
                    $cf->Load($subkey);
                }
                if ($cf and $cf->id) {
                    $clause->{CF} = $cf;
                    return;
                }
            }

            # This is a leaf node not dealing with queues, or a Queue CF
            # we couldn't find; remove it
            if ($node->isRoot) {
                $node->setNodeValue(0);
            } else {
                $node->getParent->removeChild($node);
            }
        },
        sub {
            my $node = shift;
            my $clause = $node->getNodeValue();
            return unless $node->isLeaf and not ref $clause;

            # This is a AND/OR node with no children
            if ($node->isRoot) {
                $node->setNodeValue(0);
            } else {
                $node->getParent->removeChild($node);
            }
        }
    );
    my $limits = 0;
    my $queues = RT::Queues->new( $args{CurrentUser} );
    $q_refs->traverse(
        sub {
            my $node = shift;
            if ($node->isLeaf) {
                my $clause = $node->getNodeValue();
                return unless $clause;
                if ($clause->{Key} eq "Queue") {
                    $queues->Limit(
                        FIELD    => ($clause->{RawValue} =~ /\D/ ? "Name" : "id"),
                        CASESENSITIVE => ($clause->{RawValue} =~ /\D/ ? 0 : 1),
                        OPERATOR => $clause->{Op},
                        VALUE    => $clause->{RawValue},
                        ENTRYAGGREGATOR => (
                            $node->isRoot ? "OR" :
                            $node->getParent->getNodeValue),
                        SUBCLAUSE => "referenced",
                    );
                } else {
                    $queues->LimitCustomField(
                        CUSTOMFIELD => $clause->{CF},
                        OPERATOR    => $clause->{Op},
                        VALUE       => $clause->{RawValue},
                        ENTRYAGGREGATOR => (
                            $node->isRoot ? "OR" :
                            $node->getParent->getNodeValue),
                        SUBCLAUSE => "referenced",
                    );
                }
                $limits++;
            } else {
                $queues->_OpenParen("referenced");
            }
        },
        sub {
            my $node = shift;
            return if $node->isLeaf;
            $queues->_CloseParen("referenced");
        }
    );
    $queues->UnLimit unless $limits;

    my %queues;
    while (my $q = $queues->Next) {
        $queues{$q->id} = $q;
    }

    return wantarray ? (\%queues, $limits) : \%queues;
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

    $self->traverse(
        undef,
        sub {
            my $node = shift;
            return unless $node->isLeaf;

            # We're only looking for aggregators (AND/OR)
            return if ref $node->getNodeValue;

            return if $node->isRoot;

            # OK, this is a childless aggregator.  Remove self.
            $node->getParent->removeChild($node);
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

    $self->traverse( sub {
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
            $str .= $clause->{Key};
            $str .= " ". $clause->{Op};
            $str .= " ". $clause->{Value};

        }
        $str =~ s/^\s+|\s+$//;

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
        @_
    );
    my $string = $args{'Query'};

    my @results;

    my %field = %{ RT::Tickets->new( $args{'CurrentUser'} )->FIELDS };
    my %lcfield = map { ( lc($_) => $_ ) } keys %field;

    my $node =  $self;

    my %callback;
    $callback{'OpenParen'} = sub {
        $node = __PACKAGE__->new( 'AND', $node );
    };
    $callback{'CloseParen'} = sub { $node = $node->getParent };
    $callback{'EntryAggregator'} = sub { $node->setNodeValue( $_[0] ) };
    $callback{'Condition'} = sub {
        my ($key, $op, $value) = @_;
        my $rawvalue = $value;

        my ($main_key) = split /[.]/, $key;

        my $class;
        if ( exists $lcfield{ lc $main_key } ) {
            $key =~ s/^[^.]+/ $lcfield{ lc $main_key } /e;
            ($main_key) = split /[.]/, $key;  # make the case right
            $class = $field{ $main_key }->[0];
        }
        unless( $class ) {
            push @results, [ $args{'CurrentUser'}->loc("Unknown field: [_1]", $key), -1 ]
        }

        if ( lc $op eq 'is' || lc $op eq 'is not' ) {
            $value = 'NULL'; # just fix possible mistakes here
        } elsif ( $value !~ /^[+-]?[0-9]+$/ ) {
            $value =~ s/(['\\])/\\$1/g;
            $value = "'$value'";
        }

        if ($key =~ s/(['\\])/\\$1/g or $key =~ /[^{}\w\.]/) {
            $key = "'$key'";
        }

        my $clause = { Key => $key, Op => $op, Value => $value, RawValue => $rawvalue };
        $node->addChild( __PACKAGE__->new( $clause ) );
    };
    $callback{'Error'} = sub { push @results, @_ };

    require RT::SQL;
    RT::SQL::Parse($string, \%callback);
    return @results;
}

RT::Base->_ImportOverlays();

1;
