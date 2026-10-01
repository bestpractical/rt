# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2026 Best Practical Solutions, LLC
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

=head1 NAME

  RT::Links - A collection of Link objects

=head1 SYNOPSIS

  use RT::Links;
  my $links = RT::Links->new($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS



=cut


package RT::Links;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use RT::Link;

sub Table { 'Links'}


use RT::URI;

sub Limit  {
    my $self = shift;
    my %args = ( ENTRYAGGREGATOR => 'AND',
                 OPERATOR => '=',
                 @_);

    # If we're limiting by target, order by base
    # (Order by the thing that's changing)

    if ( ($args{'FIELD'} eq 'Target') or
         ($args{'FIELD'} eq 'LocalTarget') ) {
        $self->OrderByCols(
            { ALIAS => 'main', FIELD => 'LocalBase', ORDER => 'ASC' },
            { ALIAS => 'main', FIELD => 'Base', ORDER => 'ASC' },
        );
    }
    elsif ( ($args{'FIELD'} eq 'Base') or
            ($args{'FIELD'} eq 'LocalBase') ) {
        $self->OrderByCols(
            { ALIAS => 'main', FIELD => 'LocalTarget', ORDER => 'ASC' },
            { ALIAS => 'main', FIELD => 'Target', ORDER => 'ASC' },
        );
    }


    $self->SUPER::Limit(%args);
}


=head2 LimitRefersTo URI

find all things that refer to URI

=cut

sub LimitRefersTo {
    my $self = shift;
    my $URI = shift;

    $self->Limit(FIELD => 'Type', VALUE => 'RefersTo');
    $self->Limit(FIELD => 'Target', VALUE => $URI);
}


=head2 LimitReferredToBy URI

find all things that URI refers to

=cut

sub LimitReferredToBy {
    my $self = shift;
    my $URI = shift;

    $self->Limit(FIELD => 'Type', VALUE => 'RefersTo');
    $self->Limit(FIELD => 'Base', VALUE => $URI);
}

# }}}

sub AddRecord {
    my $self = shift;
    my $record = shift;
    return unless $self->IsValidLink($record);

    push @{$self->{'items'}}, $record;
}

=head2 IsValidLink

if linked to a local ticket and is deleted, then the link is invalid.

=cut

sub IsValidLink {
    my $self = shift;
    my $link = shift;

    return unless $link && ref $link && $link->Target && $link->Base;

    # Skip links to local objects thast are deleted
    return
      if $link->TargetURI->IsLocal
          && ( UNIVERSAL::isa( $link->TargetObj, "RT::Ticket" )
              && $link->TargetObj->__Value('status') eq "deleted"
              || UNIVERSAL::isa( $link->BaseObj, "RT::Ticket" )
              && $link->BaseObj->__Value('status') eq "deleted" );

    return 1;
}

=head2 DefaultLinkType PARAMHASH

Returns the relationship first selected when a user adds a link: one of
DependsOn, DependedOnBy, MemberOf, Members, RefersTo or ReferredToBy, as
seen from the object being linked from.

    my $type = RT::Links->DefaultLinkType(
        CurrentUser => $current_user,
        Default     => $page_layout_default,
    );

Takes C<CurrentUser>, required, and C<Default>, the optional default from
the Links widget's page layout. The user's C<LinksDefaultType> preference
comes first, then C<Default>, then the C<$LinksDefaultType> setting.

=cut

sub DefaultLinkType {
    my $self = shift;
    my %args = (
        CurrentUser => undef,
        Default     => undef,
        @_,
    );

    # RT->Config->Get can't give that order: with no preference set it returns $LinksDefaultType,
    # which looks the same as a preference set to that value. Read the stored preference directly
    # so an unset preference falls through to the page layout.
    my $prefs = $args{CurrentUser} ? ( $args{CurrentUser}->UserObj->Preferences( RT->System ) || {} ) : {};
    my ($type) = grep { defined && length } $prefs->{LinksDefaultType}, $args{Default},
        RT->Config->Get('LinksDefaultType');
    return $type;
}

=head2 SortByActivityType RECORDS

Takes a list of linked records, such as tickets or assets. Returns two
array references, not one sorted list: the active records first, then the
inactive ones, each keeping the order given.

    my ( $active, $inactive ) = RT::Links->SortByActivityType(@records);
    my @active_first = ( @$active, @$inactive );

A record is inactive when its lifecycle lists its status as inactive; a
record without a lifecycle counts as active. It doesn't need an RT::Links
object, so call it on the class as above.

=cut

sub SortByActivityType {
    my $self    = shift;
    my @records = @_;

    # Inactive statuses vary by lifecycle, so ask each record's own lifecycle rather than
    # matching one list of statuses (or an ORDER BY Status) across all records.
    my ( @active, @inactive );
    for my $record (@records) {
        my $lifecycle = $record->can('LifecycleObj') ? $record->LifecycleObj : undef;
        if ( $lifecycle && $lifecycle->IsInactive( $record->Status ) ) {
            push @inactive, $record;
        }
        else {
            push @active, $record;
        }
    }
    return ( \@active, \@inactive );
}

=head2 FilterLinkListing PARAMHASH

Takes the linked records of one class and returns a collection of them,
filtered and ordered the way a links listing such as the Links widget
shows them. Returns undef for a class with no collection, or with no ids.

    my $tickets = RT::Links->FilterLinkListing(
        CurrentUser      => $current_user,
        Class            => 'RT::Ticket',
        Ids              => \@ticket_ids,
        RelationshipType => 'ReferredToBy',
    );

=over

=item CurrentUser

Required. The collection is searched as this user, so records the user
can't see are left out.

=item Class

The record class, one of RT::Ticket, RT::Transaction, RT::Asset,
RT::Article, RT::User or RT::Group.

=item Ids

An array reference of record ids.

=item RelationshipType

The relationship the records were found through, as named by the method
that lists them, such as DependsOn or ReferredToBy. A ReferredToBy
listing leaves out reminders, which refer to the ticket they belong to.

=back

The search's own defaults also apply: tickets don't include deleted
tickets, for example. Disabled articles are left out. Users and groups are
ordered by name, and everything else by id, with active tickets and
assets ahead of inactive ones.

=cut

sub FilterLinkListing {
    my $self = shift;
    my %args = (
        CurrentUser      => undef,
        Class            => '',
        Ids              => [],
        RelationshipType => '',
        @_,
    );

    my %collection_class = (
        'RT::Ticket'      => 'RT::Tickets',
        'RT::Transaction' => 'RT::Transactions',
        'RT::Asset'       => 'RT::Assets',
        'RT::Article'     => 'RT::Articles',
        'RT::User'        => 'RT::Users',
        'RT::Group'       => 'RT::Groups',
    );

    my $cclass = $collection_class{ $args{Class} };
    return undef unless $cclass && @{ $args{Ids} };

    my $collection = $cclass->new( $args{CurrentUser} );
    $collection->Limit(
        FIELD           => 'id',
        OPERATOR        => '=',
        VALUE           => $_,
        ENTRYAGGREGATOR => 'OR',
    ) for @{ $args{Ids} };

    if ( $args{Class} eq 'RT::Ticket' && $args{RelationshipType} eq 'ReferredToBy' ) {
        $collection->Limit( FIELD => 'Type', OPERATOR => '!=', VALUE => 'reminder' );
    }
    if ( $args{Class} eq 'RT::Article' ) {
        $collection->Limit( FIELD => 'Disabled', OPERATOR => '=', VALUE => 0 );
    }

    # Users and groups read better alphabetically (also their collection default).
    if ( $args{Class} eq 'RT::User' || $args{Class} eq 'RT::Group' ) {
        $collection->OrderBy( FIELD => 'Name', ORDER => 'ASC' );
    }
    else {
        $collection->OrderBy( FIELD => 'id', ORDER => 'ASC' );
    }

    # Active first, so a listing capped to a few rows can't hide an active link behind inactive
    # ones. Order in SQL: a re-sort in Perl wouldn't last, as CollectionList re-runs the search.
    if ( $args{Class} eq 'RT::Ticket' || $args{Class} eq 'RT::Asset' ) {
        my ( $active, $inactive ) = $self->SortByActivityType( @{ $collection->ItemsArrayRef || [] } );
        if ( @$active && @$inactive ) {
            $collection->OrderByCols(
                {   ALIAS    => '',
                    FIELD    => 'id',
                    FUNCTION => 'CASE WHEN main.id IN (' . join( ',', map { int $_->id } @$inactive ) . ') THEN 1 ELSE 0 END',
                    ORDER    => 'ASC',
                },
                { FIELD => 'id', ORDER => 'ASC' },
            );
        }
    }

    return $collection;
}

=head2 LinkListingCount PARAMHASH

Returns how many links of an object a links listing shows: the records
L</FilterLinkListing> keeps, plus links to URLs. Use it to tell whether a
listing has anything to show at all, before any cap on rows or default
filter is applied.

    my $total = RT::Links->LinkListingCount(
        CurrentUser => $current_user,
        Object      => $ticket,
    );

Takes C<CurrentUser> and C<Object>, required, and C<Types>, an optional
array reference of relationship methods to count. It defaults to all of
DependsOn, DependedOnBy, MemberOf, Members, RefersTo and ReferredToBy.

=cut

sub LinkListingCount {
    my $self = shift;
    my %args = (
        CurrentUser => undef,
        Object      => undef,
        Types       => [qw(DependsOn DependedOnBy MemberOf Members RefersTo ReferredToBy)],
        @_,
    );
    my $object = $args{Object};
    return 0 unless $object;

    my $total = 0;
    for my $type ( @{ $args{Types} } ) {
        next unless $RT::Link::TYPEMAP{$type} && $object->can($type);
        my $mode = $RT::Link::TYPEMAP{$type}{Mode};

        my %ids;
        my $links = $object->$type;
        $links->GotoFirstItem;
        while ( my $link = $links->Next ) {
            my ( $class, $id ) = RT::URI->ParseObjectURI( $link->$mode );
            if ($class) {
                push @{ $ids{$class} ||= [] }, $id;
            }
            else {
                $total++;
            }
        }

        for my $class ( sort keys %ids ) {
            my $collection = $self->FilterLinkListing(
                CurrentUser      => $args{CurrentUser},
                Class            => $class,
                Ids              => $ids{$class},
                RelationshipType => $type,
            );
            $total += $collection->Count if $collection;
        }
    }
    return $total;
}

RT::Base->_ImportOverlays();

1;
