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

package RT::Record::AddAndSort;
use base 'RT::Record';

=head1 NAME

RT::Record::AddAndSort - base class for records that can be added and sorted

=head1 DESCRIPTION

Base class for L<RT::ObjectCustomField> and L<RT::ObjectScrip> that unifies
application of L<RT::CustomField>s and L<RT::Scrip>s to various objects. Also,
deals with order of the records.

=head1 METHODS

=head2 Meta information

=head3 CollectionClass

Returns class representing collection for this record class. Basicly adds 's'
at the end. Should be overriden if default doesn't work.

For example returns L<RT::ObjectCustomFields> when called on L<RT::ObjectCustomField>.

=cut

sub CollectionClass {
    return (ref($_[0]) || $_[0]).'s';
}

=head3 TargetField

Returns name of the field in the table where id of object we add is stored.
By default deletes everything up to '::Object' from class name.
This method allows to use friendlier argument names and methods.

For example returns 'Scrip' for L<RT::ObjectScrip>.

=cut

sub TargetField {
    my $class = ref($_[0]) || $_[0];
    $class =~ s/.*::Object// or return undef;
    return $class;
}

=head3 ObjectCollectionClass

Takes an object under L</TargetField> name and should return class
name representing collection the object can be added to.

Must be overriden by sub classes.


See L<RT::ObjectScrip/ObjectCollectionClass> and L<RT::ObjectCustomField/CollectionClass>.

=cut

sub ObjectCollectionClass { die "should be subclassed" }

=head2 Manipulation

=head3 Create

Takes 'ObjectId' with id of an object we can be added to, object we can
add to under L</TargetField> name, Disabled and SortOrder.

This method doesn't create duplicates. If record already exists then it's not created, but
loaded instead. Note that nothing is updated if record exist.

If SortOrder is not defined then it's calculated to place new record last. If it's
provided then it's caller's duty to make sure it is correct value.

Example:

    my $ocf = RT::ObjectCustomField->new( RT->SystemUser );
    my ($id, $msg) = $ocf->Create( CustomField => 1, ObjectId => 0 );

See L</Add> which has more error checks. Also, L<RT::Scrip> and L<RT::CustomField>
have more appropriate methods that B<should be> prefered over calling this directly.

=cut

sub Create {
    my $self = shift;
    my %args = (
        ObjectId    => 0,
        SortOrder   => undef,
        @_
    );

    my $tfield = $self->TargetField;

    my $target = $self->TargetObj( $args{ $tfield } );
    unless ( $target->id ) {
        $RT::Logger->error("Couldn't load ". ref($target) ." '$args{$tfield}'");
        return 0;
    }

    my $exist = $self->new($self->CurrentUser);
    $exist->LoadByCols( ObjectId => $args{'ObjectId'}, $tfield => $target->id );
    if ( $exist->id ) {
        $self->Load( $exist->id );
        return $self->id;
    }

    unless ( defined $args{'SortOrder'} ) {
        $args{'SortOrder'} = $self->NextSortOrder(
            %args,
            $tfield  => $target,
        );
    }

    return $self->SUPER::Create(
        %args,
        $tfield   => $target->id,
    );
}

=head3 Add

Helper method that wraps L</Create> and does more checks to make sure
result is consistent. Doesn't allow adding a record to an object if the
record is already global. Removes record from particular objects when
asked to add the record globally.

=cut

sub Add {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;

    my $tid = $args{ $field };
    $tid = $tid->id if ref $tid;
    $tid ||= $self->TargetObj->id;

    my $oid = $args{'ObjectId'};
    $oid = $oid->id if ref $oid;
    $oid ||= 0;

    if ( $self->IsAdded( $tid => $oid ) ) {
        return ( 0, $self->loc("Is already added to the object") );
    }

    if ( $oid ) {
        # adding locally
        return (0, $self->loc("Couldn't add as it's global already") )
            if $self->IsAdded( $tid => 0 );
    }
    else {
        $self->DeleteAll( $field => $tid );
    }

    return $self->Create(
        %args, $field => $tid, ObjectId => $oid,
    );
}

sub IsAdded {
    my $self = shift;
    my ($tid, $oid) = @_;
    my $record = $self->new( $self->CurrentUser );
    $record->LoadByCols( $self->TargetField => $tid, ObjectId => $oid );
    return $record->id;
}

=head3 AddedTo

Returns collection with objects target of this record is added to.
Class of the collection depends on L</ObjectCollectionClass>.
See all L</NotAddedTo>.

For example returns L<RT::Queues> collection if the target is L<RT::Scrip>.

Returns empty collection if target is added globally.

=cut

sub AddedTo {
    my $self = shift;

    my ($res, $alias) = $self->_AddedTo( @_ );
    return $res unless $res;

    $res->Limit(
        ALIAS     => $alias,
        FIELD     => 'id',
        OPERATOR  => 'IS NOT',
        VALUE     => 'NULL',
    );

    return $res;
}

=head3 NotAddedTo

Returns collection with objects target of this record is not added to.
Class of the collection depends on L</ObjectCollectionClass>.
See all L</AddedTo>.

Returns empty collection if target is added globally.

=cut

sub NotAddedTo {
    my $self = shift;

    my ($res, $alias) = $self->_AddedTo( @_ );
    return $res unless $res;

    $res->Limit(
        ALIAS     => $alias,
        FIELD     => 'id',
        OPERATOR  => 'IS',
        VALUE     => 'NULL',
    );

    return $res;
}

sub _AddedTo {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;
    my $target = $args{ $field } || $self->TargetObj;

    my ($class) = $self->ObjectCollectionClass( $field => $target );
    return undef unless $class;

    my $res = $class->new( $self->CurrentUser );

    # If target added to a Group, only display user-defined groups
    $res->LimitToUserDefinedGroups if $class eq 'RT::Groups';

    $res->OrderBy( FIELD => 'Name' );
    my $alias = $res->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => $self->Table,
        FIELD2 => 'ObjectId',
    );
    $res->Limit(
        LEFTJOIN => $alias,
        ALIAS    => $alias,
        FIELD    => $field,
        VALUE    => $target->id,
    );
    return ($res, $alias);
}

=head3 Delete

Deletes this record.

=cut

sub Delete {
    my $self = shift;

    return $self->SUPER::Delete if $self->IsSortOrderShared;

    # Move everything below us up
    my $siblings = $self->Neighbors;
    $siblings->Limit( FIELD => 'SortOrder', OPERATOR => '>=', VALUE => $self->SortOrder );
    $siblings->OrderBy( FIELD => 'SortOrder', ORDER => 'ASC' );
    foreach my $record ( @{ $siblings->ItemsArrayRef } ) {
        $record->SetSortOrder($record->SortOrder - 1);
    }

    return $self->SUPER::Delete;
}

=head3 DeleteAll

Helper method to delete all applications for one target (Scrip, CustomField, ...).
Target can be provided in arguments. If it's not then L</TargetObj> is used.

    $object_scrip->DeleteAll;

    $object_scrip->DeleteAll( Scrip => $scrip );

=cut

sub DeleteAll {
    my $self = shift;
    my %args = (@_);

    my $field = $self->TargetField;

    my $id = $args{ $field };
    $id = $id->id if ref $id;
    $id ||= $self->TargetObj->id;

    my $list = $self->CollectionClass->new( $self->CurrentUser );
    $list->Limit( FIELD => $field, VALUE => $id );
    $_->Delete foreach @{ $list->ItemsArrayRef };
}

=head3 MoveUp

Moves record up.

=cut

sub MoveUp { return shift->Move( Up => @_ ) }

=head3 MoveDown

Moves record down.

=cut

sub MoveDown { return shift->Move( Down => @_ ) }

=head3 Move

Takes 'up' or 'down'. One method that implements L</MoveUp> and L</MoveDown>.

=cut

sub Move {
    my $self = shift;
    my $dir = lc(shift || 'up');

    my %meta;
    if ( $dir eq 'down' ) {
        %meta = qw(
            next_op    >
            next_order ASC
            prev_op    <=
            diff       +1
        );
    } else {
        %meta = qw(
            next_op    <
            next_order DESC
            prev_op    >=
            diff       -1
        );
    }

    my $siblings = $self->Siblings;
    $siblings->Limit( FIELD => 'SortOrder', OPERATOR => $meta{'next_op'}, VALUE => $self->SortOrder );
    $siblings->OrderBy( FIELD => 'SortOrder', ORDER => $meta{'next_order'} );

    my @next = ($siblings->Next, $siblings->Next);
    unless ($next[0]) {
        return $dir eq 'down'
            ? (0, "Can not move down. It's already at the bottom")
            : (0, "Can not move up. It's already at the top")
        ;
    }

    my ($new_sort_order, $move);

    unless ( $self->ObjectId ) {
        # moving global, it can not share sort order, so just move it
        # on place of next global and move everything in between one number

        $new_sort_order = $next[0]->SortOrder;
        $move = $self->Neighbors;
        $move->Limit(
            FIELD => 'SortOrder', OPERATOR => $meta{'next_op'}, VALUE => $self->SortOrder,
        );
        $move->Limit(
            FIELD => 'SortOrder', OPERATOR => $meta{'prev_op'}, VALUE => $next[0]->SortOrder,
            ENTRYAGGREGATOR => 'AND',
        );
    }
    elsif ( $next[0]->ObjectId == $self->ObjectId ) {
        # moving two locals, just swap them, they should follow 'so = so+/-1' rule
        $new_sort_order = $next[0]->SortOrder;
        $move = $next[0];
    }
    else {
        # moving local behind global
        unless ( $self->IsSortOrderShared ) {
            # not shared SO allows us to swap
            $new_sort_order = $next[0]->SortOrder;
            $move = $next[0];
        }
        elsif ( $next[1] ) {
            # more records there and shared SO, we have to move everything
            $new_sort_order = $next[0]->SortOrder;
            $move = $self->Neighbors;
            $move->Limit(
                FIELD => 'SortOrder', OPERATOR => $meta{prev_op}, VALUE => $next[0]->SortOrder,
            );
        }
        else {
            # shared SO and place after is free, so just jump
            $new_sort_order = $next[0]->SortOrder + $meta{'diff'};
        }
    }

    if ( $move ) {
        foreach my $record ( $move->isa('RT::Record')? ($move) : @{ $move->ItemsArrayRef } ) {
            my ($status, $msg) = $record->SetSortOrder(
                $record->SortOrder - $meta{'diff'}
            );
            return (0, "Couldn't move: $msg") unless $status;
        }
    }

    my ($status, $msg) = $self->SetSortOrder( $new_sort_order );
    unless ( $status ) {
        return (0, "Couldn't move: $msg");
    }

    return (1,"Moved");
}

=head2 Accessors, instrospection and traversing.

=head3 TargetObj

Returns target object of this record. Returns L<RT::Scrip> object for
L<RT::ObjectScrip>.

=cut

sub TargetObj {
    my $self = shift;
    my $id   = shift;

    my $method = $self->TargetField .'Obj';
    return $self->$method( $id );
}

=head3 NextSortOrder

Returns next available SortOrder value in the L<neighborhood|/Neighbors>.
Pass arguments to L</Neighbors> and can take optional ObjectId argument,
calls ObjectId if it's not provided.

=cut

sub NextSortOrder {
    my $self = shift;
    my %args = (@_);

    my $oid = $args{'ObjectId'};
    $oid = $self->ObjectId unless defined $oid;
    $oid ||= 0;

    my $neighbors = $self->Neighbors( %args );
    if ( $oid ) {
        $neighbors->LimitToObjectId( $oid );
        $neighbors->LimitToObjectId( 0 );
    } elsif ( !$neighbors->_isLimited ) {
        $neighbors->UnLimit;
    }
    $neighbors->OrderBy( FIELD => 'SortOrder', ORDER => 'DESC' );
    return 0 unless my $first = $neighbors->First;
    return $first->SortOrder + 1;
}

=head3 IsSortOrderShared

Returns true if this record shares SortOrder value with a L<neighbor|/Neighbors>.

=cut

sub IsSortOrderShared {
    my $self = shift;
    return 0 unless $self->ObjectId;

    my $neighbors = $self->Neighbors;
    $neighbors->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->id );
    $neighbors->Limit( FIELD => 'SortOrder', VALUE => $self->SortOrder );
    return $neighbors->Count;
}

=head2 Neighbors and Siblings

These two methods should only be understood by developers who wants
to implement new classes of records that can be added to other records
and sorted.

Main purpose is to maintain SortOrder values.

Let's take a look at custom fields. A custom field can be created for tickets,
queues, transactions, users... Custom fields created for tickets can
be added globally or to particular set of queues. Custom fields for
tickets are neighbors. Neighbor custom fields added to the same objects
are siblings. Custom fields added globally are sibling to all neighbors.

For scrips Stage defines neighborhood.

Let's look at the three scrips in create stage S1, S2 and S3, queues Q1 and Q2 and
G for global.

    S1@Q1, S3@Q2 0
    S2@G         1
    S1@Q2        2

Above table says that S2 is added globally, S1 is added to Q1 and executed
before S2 in this queue, also S1 is added to Q1, but exectued after S2 in this
queue, S3 is only added to Q2 and executed before S2 and S1.

Siblings are scrips added to an object including globally added or only
globally added. In our example there are three different collection
of siblings: (S2) - global, (S1, S2) for Q1, (S3, S2, S1) for Q2.

Sort order can be shared between neighbors, but can not be shared between siblings.

Here is what happens with sort order if we move S1@Q2 one position up:

           S3@Q2 0
    S1@Q1, S1@Q2 1
    S2@G         2

One position more:

           S1@Q2 0
    S1@Q1, S3@Q2 1
    S2@G         2

Hopefuly it's enough to understand how it works.

Targets from different neighborhood can not be sorted against each other.

=head3 Neighbors

Returns collection of records of this class with all
neighbors. By default all possible targets are neighbors.

Takes the same arguments as L</Create> method. If arguments are not passed
then uses the current record.

See L</Neighbors and Siblings> for detailed description.

See L<RT::ObjectCustomField/Neighbors> for example.

=cut

sub Neighbors {
    my $self = shift;
    return $self->CollectionClass->new( $self->CurrentUser );
}

=head3 Siblings

Returns collection of records of this class with siblings.

Takes the same arguments as L</Neighbors>. Siblings is subset of L</Neighbors>.

=cut

sub Siblings {
    my $self = shift;
    my %args = @_;

    my $oid = $args{'ObjectId'};
    $oid = $self->ObjectId unless defined $oid;
    $oid ||= 0;

    my $res = $self->Neighbors( %args );
    $res->LimitToObjectId( $oid );
    $res->LimitToObjectId( 0 ) if $oid;
    return $res;
}

RT::Base->_ImportOverlays();

1;
