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

package RT::REST2::Resource::Collection;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource';

use Scalar::Util qw( blessed );
use Web::Machine::FSM::States qw( is_status_code );
use Module::Runtime qw( require_module );
use RT::REST2::Util qw( expand_uid format_datetime error_as_json );
use POSIX qw( ceil );
use Encode;
our $PREVIEW_LIMIT = 200;

has 'collection_class' => (
    is  => 'ro',
    isa => 'ClassName',
);

has 'collection' => (
    is          => 'ro',
    isa         => 'RT::SearchBuilder',
    required    => 1,
    lazy_build  => 1,
);

sub _build_collection {
    my $self = shift;
    my $collection = $self->collection_class->new( $self->current_user );
    return $collection;
}

sub setup_paging {
    my $self = shift;
    my $per_page = $self->request->param('per_page') || 20;
    if    ( $per_page !~ /^\d+$/ ) { $per_page = 20 }
    elsif ( $per_page == 0 )       { $per_page = 20 }
    elsif ( $per_page > 100 )      { $per_page = 100 }
    $self->collection->RowsPerPage($per_page);

    my $page = $self->request->param('page') || 1;
    if    ( $page !~ /^\d+$/ ) { $page = 1 }
    elsif ( $page == 0 )       { $page = 1 }
    elsif ( $page > 1 && $self->collection->CurrentUserCanSeeAll ) {
        if ( my $pages = ceil( $self->collection->CountAll / $per_page ) ) {
            $page = $pages if $page > $pages;
        }
    }
    $self->collection->GotoPage($page - 1);
}

sub setup_ordering {
    my $self = shift;
    my @orderby_cols;
    my @orders = $self->request->param('order');
    foreach my $orderby ($self->request->param('orderby')) {
        $orderby = decode_utf8($orderby);
        my $order = shift @orders || 'ASC';
        $order = uc(decode_utf8($order));
        $order = 'ASC' unless $order eq 'DESC';
        push @orderby_cols, {FIELD => $orderby, ORDER => $order};
    }
    $self->collection->OrderByCols(@orderby_cols)
        if @orderby_cols;
}

sub limit_collection {
    my $self        = shift;
    my $collection  = $self->collection;
    $collection->{'find_disabled_rows'} = 1
        if $self->request->param('find_disabled_rows');

    if ( $self->can('limit_collection_from_json') ) {
        $self->limit_collection_from_json();
    }
    if ( $self->can('limit_collection_from_sql') ) {
        my ($ret, $msg) = $self->limit_collection_from_sql();
        return error_as_json( $self->response, $ret, $msg ) unless $ret;
    }

    my @orderby_cols;
    my @orders = $self->request->param('order');
    foreach my $orderby ($self->request->param('orderby')) {
        my $order = shift @orders || 'ASC';
        $order = uc($order);
        $order = 'ASC' unless $order eq 'DESC';
        push @orderby_cols, {FIELD => $orderby, ORDER => $order};
    }
    $self->collection->OrderByCols(@orderby_cols)
        if @orderby_cols;

    return 1;
}

sub search {
    my $self = shift;
    $self->setup_paging;
    $self->setup_ordering;
    return $self->limit_collection;
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my @results;
    my @fields = defined $self->request->param('fields') ? split(/,/, $self->request->param('fields')) : ();

    while (my $item = $collection->Next) {
        my $result = $self->serialize_record( $item->UID );

        # Allow selection of desired fields
        if ($result) {
            for my $field (@fields) {
                if ( $field eq '_hyperlinks' ) {
                    my $class = ref $item;
                    $class =~ s!^RT::!RT::REST2::Resource::!;
                    if ( RT::StaticUtil::RequireModule($class) ) {
                        my $object = $class->new(
                            record_class => ref $item,
                            record_id    => $item->id,
                            record       => $item,
                            request      => $self->request,
                            response     => Plack::Response->new,
                        );
                        if ( $object->can('hypermedia_links') ) {
                            $result->{$field} = $object->hypermedia_links;
                        }
                        else {
                            RT->Logger->warning("_hyperlinks is not supported by $class, skipping");
                        }
                    }
                    else {
                        RT->Logger->warning("Couldn't load $class, skipping _hyperlinks");
                    }
                }
                else {
                    my $field_result = $self->expand_field($item, $field);
                    $result->{$field} = $field_result if defined $field_result;
                }
            }
        }
        push @results, $result;
    }

    my $total = $collection->CountAll;
    my $pages = ceil( $total / $collection->RowsPerPage );

    my %results = (
        count       => scalar(@results)         + 0,
        total       => $collection->CurrentUserCanSeeAll ? $total : undef,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    );

    my $uri = $self->request->uri;
    my @query_form = $uri->query_form;
    # find page and if it is set, delete it and its value.
    for my $i (0..$#query_form) {
        if ($query_form[$i] eq 'page') {
            delete @query_form[$i, $i + 1];
            last;
        }
    }

    $results{pages} = defined $results{total} ? $pages : undef;
    if ( $results{pages} ) {
        if ($results{page} < $results{pages}) {
            $uri->query_form( @query_form, page => $results{page} + 1 );
            $results{next_page} = $uri->as_string;
        }

        if ( $results{page} > 1 ) {
            $uri->query_form( @query_form, page => $results{page} - 1 );
            $results{prev_page} = $uri->as_string;
        }
    }

    if ( (not exists $results{next_page}) && (not defined $results{total}) ) {
        # If total is undef, this collection checks ACLs in code so we can't
        # use the collection count directly. Try to peek ahead to see if there
        # are more records available so we can return next_page without giving
        # away specific counts.

        my $page = $results{page};

        # If current user can't find any records after checking about $PREVIEW_LIMIT
        # items, assuming no records left.
        for ( 1 .. ceil( $PREVIEW_LIMIT / $results{per_page} ) ) {
            $collection->NextPage();
            $page++;
            last if $page > $pages;

            while ( my $item = $collection->Next ) {

                # As soon as we get one record, we know it's the next page
                $uri->query_form( @query_form, page => $page );
                $results{next_page} = $uri->as_string;
                last;
            }
            last if $results{next_page};
        }

        $page = $results{page};
        $collection->GotoPage( $page - 1 );
        for ( 1 .. ceil( $PREVIEW_LIMIT / $results{per_page} ) ) {
            $collection->PrevPage();
            $page--;
            last if $page < 1;

            while ( my $item = $collection->Next ) {

                # As soon as we get one record, we know it's the prev page
                $uri->query_form( @query_form, page => $page );
                $results{prev_page} = $uri->as_string;
                last;
            }
            last if $results{prev_page};
        }
    }

    return \%results;
}

sub serialize_record {
    my $self   = shift;
    my $record = shift;
    return expand_uid($record);
}

# XXX TODO: Bulk update via DELETE/PUT on a collection resource?

sub charsets_provided { [ 'utf-8' ] }
sub default_charset   {   'utf-8'   }

sub content_types_provided { [
    { 'application/json' => 'to_json' },
] }

sub to_json {
    my $self = shift;
    my $status = $self->search;
    return $status if is_status_code($status);
    return \400 unless $status;
    return JSON::to_json($self->serialize, { pretty => 1 });
}

sub finish_request {
    my $self = shift;
    # Ensure the collection object is destroyed before the request finishes, for
    # any cleanup that may need to happen (i.e. TransactionBatch).
    $self->clear_collection;
    return $self->SUPER::finish_request(@_);
}

RT::Base->_ImportOverlays();

__PACKAGE__->meta->make_immutable;

1;
