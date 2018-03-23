# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::SearchBuilder::AddAndSort;
use base 'RT::SearchBuilder';

=head1 NAME

RT::SearchBuilder::AddAndSort - base class for 'add and sort' collections

=head1 DESCRIPTION

Base class for collections where records can be added to objects with order.
See also L<RT::Record::AddAndSort>. Used by L<RT::ObjectScrips> and
L<RT::ObjectCustomFields>.

As it's about sorting then collection is sorted by SortOrder field.

=head1 METHODS

=cut

sub _Init {
    my $self = shift;

    # By default, order by SortOrder
    $self->OrderByCols(
         { ALIAS => 'main',
           FIELD => 'SortOrder',
           ORDER => 'ASC' },
         { ALIAS => 'main',
           FIELD => 'id',
           ORDER => 'ASC' },
    );

    return $self->SUPER::_Init(@_);
}

=head2 LimitToObjectId

Takes id of an object and limits collection.

=cut

sub LimitToObjectId {
    my $self = shift;
    my $id = shift || 0;
    $self->Limit( FIELD => 'ObjectId', VALUE => $id );
}

=head1 METHODS FOR TARGETS

Rather than implementing a base class for targets (L<RT::Scrip>,
L<RT::CustomField>) and its collections. This class provides
class methods to limit target collections.

=head2 LimitTargetToNotAdded

Takes a collection object and optional list of object ids. Limits the
collection to records not added to listed objects or if the list is
empty then any object. Use 0 (zero) to mean global.

=cut

sub LimitTargetToNotAdded {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToAdded($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS',
        VALUE    => 'NULL',
    );
    return $alias;
}

=head2 LimitTargetToAdded

L</LimitTargetToNotAdded> with reverse meaning. Takes the same
arguments.

=cut

sub LimitTargetToAdded {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToAdded($collection => @ids);

    $collection->Limit(
        ENTRYAGGREGATOR => 'AND',
        ALIAS    => $alias,
        FIELD    => 'id',
        OPERATOR => 'IS NOT',
        VALUE    => 'NULL',
    );
    return $alias;
}

=head2 JoinTargetToAdded

Joins collection to this table using left join, limits joined table
by ids if those are provided.

Returns alias of the joined table. Join is cached and re-used for
multiple calls.

=cut

sub JoinTargetToAdded {
    my $self = shift;
    my $collection = shift;
    my @ids = @_;

    my $alias = $self->JoinTargetToThis( $collection, New => 0, Left => 1 );
    return $alias unless @ids;

    # XXX: we need different EA in join clause, but DBIx::SB
    # doesn't support them, use IN (X) instead
    my $dbh = $self->_Handle->dbh;
    $collection->Limit(
        LEFTJOIN   => $alias,
        ALIAS      => $alias,
        FIELD      => 'ObjectId',
        OPERATOR   => 'IN',
        VALUE      => [ @ids ],
    );

    return $alias;
}

=head2 JoinTargetToThis

Joins target collection to this table using TargetField.

Takes New and Left arguments. Use New to avoid caching and re-using
this join. Use Left to create LEFT JOIN rather than inner.

=cut

sub JoinTargetToThis {
    my $self = shift;
    my $collection = shift;
    my %args = ( New => 0, Left => 0, Distinct => 0, @_ );

    my $table = $self->Table;
    my $key = "_sql_${table}_alias";

    return $collection->{ $key } if $collection->{ $key } && !$args{'New'};

    my $alias = $collection->Join(
        $args{'Left'} ? (TYPE => 'LEFT') : (),
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => $table,
        FIELD2 => $self->RecordClass->TargetField,
        DISTINCT => $args{Distinct},
    );
    return $alias if $args{'New'};
    return $collection->{ $key } = $alias;
}

RT::Base->_ImportOverlays();

1;
