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

package RT::Shredder::Plugin::Assets;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

=head1 NAME

RT::Shredder::Plugin::Assets - search plugin for wiping Assets.

=head1 ARGUMENTS

=head2 query - query string

Search Assets with query string.
Examples:
  Catalog = 'my catalog' AND ( Status = 'deleted' OR Status = 'recyled' )
  LastUpdated < '2013-12-31 23:59:59'

B<Hint:> You can construct query with the query builder in RT's web
interface and then open advanced page and copy query string.

=head2 with_linked - boolean

Deletes all Assets that are linked to Assets that match L<query>.

=head2 apply_query_to_linked - boolean

Delete linked Assets only if those too match L<query>.

See also L<with_linked>.

=cut

sub SupportArgs { return $_[0]->SUPER::SupportArgs, qw(query with_linked apply_query_to_linked) }

# used to genrate checkboxes instead of text fields in the web interface
sub ArgIsBoolean {
    my ( $self, $arg ) = @_;
    my %boolean_atts = map { $_ => 1 } qw( with_linked apply_query_to_linked );
    return $boolean_atts{$arg};
}

sub TestArgs {
    my $self = shift;
    my %args = @_;
    my $queue;
    if ( $args{'query'} ) {
        my $objs = RT::Assets->new( RT->SystemUser );
        $objs->{'allow_deleted_search'} = 1;
        my ( $status, $msg ) = $objs->FromSQL( $args{'query'} );
        return ( 0, "Bad query argument, error: $msg" ) unless $status;
        $self->{'opt'}{'objects'} = $objs;
    }
    $args{'with_linked'} = 1 if $args{'apply_query_to_linked'};

    return $self->SUPER::TestArgs(%args);
}

sub Run {
    my $self = shift;
    my $objs = $self->{'opt'}{'objects'}
        or return ( 1, undef );

    $objs->OrderByCols( { FIELD => 'id', ORDER => 'ASC' } );
    unless ( $self->{'opt'}{'with_linked'} ) {
        if ( $self->{'opt'}{'limit'} ) {
            $objs->RowsPerPage( $self->{'opt'}{'limit'} );
        }
        return ( 1, $objs );
    }

    my ( @top, @linked, %seen );
    $self->FetchNext( $objs, 1 );
    while ( my $obj = $self->FetchNext($objs) ) {
        next if $seen{ $obj->id }++;
        push @linked, $self->GetLinked( Object => $obj, Seen => \%seen );
        push @top,    $obj;
        last
            if $self->{'opt'}{'limit'}
            && @top >= $self->{'opt'}{'limit'};
    }
    return ( 1, @top, @linked );
}

sub GetLinked {
    my $self  = shift;
    my %arg   = @_;
    my @res   = ();
    my $query = "Linked = 'asset:" . $arg{'Object'}->id . "'";
    if ( $self->{'opt'}{'apply_query_to_linked'} ) {
        $query .= " AND ( " . $self->{'opt'}{'query'} . " )";
    }
    my $objs = RT::Assets->new( RT->SystemUser );
    $objs->{'allow_deleted_search'} = 1;
    $objs->FromSQL($query);
    $self->FetchNext( $objs, 1 );
    while ( my $linked_obj = $self->FetchNext($objs) ) {
        next if $arg{'Seen'}->{ $linked_obj->id }++;
        push @res, $self->GetLinked( %arg, Object => $linked_obj );
        push @res, $linked_obj;
    }
    return @res;
}

RT::Base->_ImportOverlays();

1;
