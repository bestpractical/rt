# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Search;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable',
    'RT::REST2::Resource::Record::Hypermedia' =>
    { -alias => { _self_link => '_default_self_link', hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/search/?$},
        block => sub { { record_class => 'RT::Attribute' } },
        ),
        Path::Dispatcher::Rule::Regex->new(
            regex => qr{^/search/(.+)/?$},
            block => sub {
                my ($match, $req) = @_;
                my $desc = $match->pos(1);
                my $record = _load_search($req, $desc);

                return { record_class => 'RT::Attribute', record_id => $record ? $record->Id : 0 };
            },
        );
}

sub _self_link {
    my $self   = shift;
    my $result = $self->_default_self_link(@_);

    $result->{type} = 'search';
    $result->{_url} =~ s!/attribute/!/search/!;
    return $result;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links;
    my $record = $self->record;
    if ( my $content = $record->Content ) {
        if ( ( $content->{SearchType} || 'Ticket' ) eq 'Ticket' ) {
            my $id = $record->Id;
            push @$links,
                {   _url => RT::REST2->base_uri . "/tickets?search=$id",
                    type => 'results',
                    ref  => 'tickets',
                };
        }
    }
    return $links;
}

sub base_uri { join '/', RT::REST2->base_uri, 'search' }

sub resource_exists {
    my $self   = shift;
    my $record = $self->record;
    return $record->Id && $record->Name =~ /^(?:SavedSearch$|Search -)/;
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->resource_exists;
    my $search = RT::SavedSearch->new( $self->current_user );
    return $search->LoadById( $self->record->Id ) ? 0 : 1;
}

sub _load_search {
    my $req = shift;
    my $id  = shift;

    if ( $id =~ /\D/ ) {

        my $attrs = RT::Attributes->new( $req->env->{"rt.current_user"} );

        $attrs->Limit( FIELD => 'Name',        VALUE => 'SavedSearch' );
        $attrs->Limit( FIELD => 'Name',        VALUE => 'Search -', OPERATOR => 'STARTSWITH' );
        $attrs->Limit( FIELD => 'Description', VALUE => $id );

        my @searches;
        while ( my $attr = $attrs->Next ) {
            my $search = RT::SavedSearch->new( $req->env->{"rt.current_user"} );
            if ( $search->LoadById( $attr->Id ) ) {
                push @searches, $search;
            }
        }

        my $record_id;
        if (@searches) {
            if ( @searches > 1 ) {
                RT->Logger->warning("Found multiple searches with description $id");
            }
            return $searches[0];
        }
    }
    else {
        my $search = RT::SavedSearch->new( $req->env->{"rt.current_user"} );
        if ( $search->LoadById($id) ) {
            return $search;
        }
    }
    return;
}

__PACKAGE__->meta->make_immutable;

1;
