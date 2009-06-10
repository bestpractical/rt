# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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

   $prefunc->($self);
   
   foreach my $child ($self->getAllChildren()) { 
           $child->TraversePrePost($prefunc, $postfunc);
   }
   
   $postfunc->($self);
}

=head2 GetReferencedQueues

Returns a hash reference with keys each queue name referenced in a clause in
the key (even if it's "Queue != 'Foo'"), and values all 1.

=cut

sub GetReferencedQueues {
    my $self = shift;

    my $queues = {};

    $self->traverse(
        sub {
            my $node = shift;

            return if $node->isRoot;

            my $clause = $node->getNodeValue();
         
            if ( ref($clause) and $clause->{Key} eq 'Queue' ) {
                $queues->{ $clause->{Value} } = 1;
            };
        }
    );

    return $queues;
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

    my $optionlist = [];

    my $i = 0;

    $self->TraversePrePost(
        sub { # This is called before recursing to the node's children.
            my $node = shift;

            return if $node->isRoot or $node->getParent->isRoot;

            my $clause = $node->getNodeValue();
            my $str = ' ';
            my $aggregator_context = $node->getParent()->getNodeValue();
            $str = $aggregator_context . " " if $node->getIndex() > 0;

            if ( ref($clause) ) { # ie, it's a leaf              
                $str .=
                  $clause->{Key} . " " . $clause->{Op} . " " . $clause->{Value};
            }

            unless ($node->getParent->getParent->isRoot) {
        #        used to check !ref( $parent->getNodeValue() ) )
                if ( $node->getIndex() == 0 ) {
                    $str = '( ' . $str;
                }
            }

            push @$optionlist, {
                TEXT     => $str,
                INDEX    => $i,
                SELECTED => (grep { $_ == $node } @$selected_nodes) ? 'SELECTED' : '',
                DEPTH    => $node->getDepth() - 1,
            };

            $i++;
        }, sub {
            # This is called after recursing to the node's children.
            my $node = shift;

            return if $node->isRoot or $node->getParent->isRoot or $node->getParent->getParent->isRoot;

            # Only do this for the rightmost child.
            return unless $node->getIndex == $node->getParent->getChildCount - 1;

            $optionlist->[-1]{TEXT} .= ' )';
        }
    );

    return (join ' ', map { $_->{TEXT} } @$optionlist), $optionlist;
}

=head2 PruneChildLessAggregators

If tree manipulation has left it in a state where there are ANDs, ORs,
or parenthesizations with no children, get rid of them.

=cut

sub PruneChildlessAggregators {
    my $self = shift;

    $self->TraversePrePost(
        sub {
        },
        sub {
            my $node = shift;

            return if $node->isRoot or $node->getParent->isRoot;
            
            # We're only looking for aggregators (AND/OR)
            return if ref $node->getNodeValue;
            
            return if $node->getChildCount != 0;
            
            # OK, this is a childless aggregator.  Remove self.
            
            $node->getParent->removeChild($node);
            
            # Deal with circular refs
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
    my $self = shift;
    my @lines;

    $self->traverse(sub {
        my $node = shift;

        push @lines, $node unless $node->isRoot or $node->getParent->isRoot;
    });

    return @lines;
}


eval "require RT::Interface::Web::QueryBuilder::Tree_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web/QueryBuilder/Tree_Vendor.pm});
eval "require RT::Interface::Web::QueryBuilder::Tree_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web/QueryBuilder/Tree_Local.pm});

1;
