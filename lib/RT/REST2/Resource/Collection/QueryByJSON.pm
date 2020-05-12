# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Collection::QueryByJSON;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

use JSON ();

with (
    'RT::REST2::Resource::Collection::ProcessPOSTasGET',
    'RT::REST2::Resource::Role::RequestBodyIsJSON'
         => { type => 'ARRAY' },
);

requires 'collection';

has 'query' => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    required    => 1,
    lazy_build  => 1,
);

sub _build_query {
    my $self = shift;
    my $content = $self->request->method eq 'GET'
                ? $self->request->param('query')
                : $self->request->content;
    return $content ? JSON::decode_json($content) : [];
}

sub allowed_methods {
    [ 'GET', 'POST' ]
}

sub searchable_fields {
    $_[0]->collection->RecordClass->ReadableAttributes
}

sub limit_collection {
    my $self        = shift;
    my $collection  = $self->collection;
    my $query       = $self->query;
    my @fields      = $self->searchable_fields;
    my %searchable  = map {; $_ => 1 } @fields;

    $collection->{'find_disabled_rows'} = 1
        if $self->request->param('find_disabled_rows');

    for my $limit (@$query) {
        next unless $limit->{field}
                and $searchable{$limit->{field}}
                and defined $limit->{value};

        $collection->Limit(
            FIELD       => $limit->{field},
            VALUE       => $limit->{value},
            ( $limit->{operator}
                ? (OPERATOR => $limit->{operator})
                : () ),
            CASESENSITIVE => ($limit->{case_sensitive} || 0),
            ( $limit->{entry_aggregator}
                ? (ENTRYAGGREGATOR => $limit->{entry_aggregator})
                : () ),
        );
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

1;
