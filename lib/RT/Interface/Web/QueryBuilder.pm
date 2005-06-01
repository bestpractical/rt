# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
package RT::Interface::Web::QueryBuilder;

use strict;
use warnings;

sub TreeToQueryAndOptionListAndQueues {
    my $tree           = shift;
    my $selected_nodes = shift;
    
    my $Query = '';
    my $queues = {};
    my $optionlist = [];

    my $i = 0;

    $tree->traverse_pre_post(
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

                if ( $clause->{Key} eq "Queue" ) {
                    $queues->{ $clause->{Value} } = 1;
                }
            }

            my $selected = '';
            if ( grep { $_ == $node } @$selected_nodes ) {
                $selected = "SELECTED";
            }

            unless ($node->getParent->getParent->isRoot) {
        #        used to check !ref( $parent->getNodeValue() ) )
                if ( $node->getIndex() == 0 ) {
                    $str = '( ' . $str;
                }
            }
            
            $Query .= " " . $str . " ";

            push @$optionlist, {
                TEXT     => $str,
                INDEX    => $i,
                SELECTED => $selected,
                DEPTH    => $node->getDepth() - 1,
            };

            $i++;
        }, sub {
            # This is called after recursing to the node's children.
            my $node = shift;
            
            return if $node->isRoot or $node->getParent->isRoot or $node->getParent->getParent->isRoot;
            
            # Only do this for the rightmost child.
            return unless $node->getIndex == $node->getParent->getChildCount - 1;
            
            $Query .= ' )';
            $optionlist->[-1]{TEXT} .= ' )';
        }
    );

    my $should_be_query = join ' ', map { $_->{TEXT} } @$optionlist;

#   So, $should_be_query *ought* to be the same as $Query but calculated in a much
#   simpler way, but this has not been tested enough to make sure, so I won't commit it. 
#   my $sbq_tmp = $should_be_query;
#   my $q_tmp = $Query;
#   $sbq_tmp =~ tr/ //d; $q_tmp =~ tr/ //d;
#   $RT::Logger->crit("query check: " . ($q_tmp eq $sbq_tmp ? 'yay' : 'nay') );

    return $optionlist, $Query, $queues;
}


eval "require RT::Interface::Web::QueryBuilder_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web/QueryBuilder_Vendor.pm});
eval "require RT::Interface::Web::QueryBuilder_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Web/QueryBuilder_Local.pm});

1;
