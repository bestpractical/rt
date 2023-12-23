# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Asset;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Record';
with (
    'RT::REST2::Resource::Record::Readable',
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } },
    'RT::REST2::Resource::Record::Deletable',
    'RT::REST2::Resource::Record::Writable'
        => { -alias => { create_record => '_create_record' } },
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/asset/?$},
        block => sub { { record_class => 'RT::Asset' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/asset/(\d+)/?$},
        block => sub { { record_class => 'RT::Asset', record_id => shift->pos(1) } },
    )
}

sub create_record {
    my $self = shift;
    my $data = shift;

    return (\400, "Invalid Catalog") if !$data->{Catalog};

    my $catalog = RT::Catalog->new($self->record->CurrentUser);
    $catalog->Load($data->{Catalog});

    return (\403, $self->record->loc("Permission Denied"))
        unless $catalog->Id and !$catalog->__Value('Disabled') and $catalog->CurrentUserHasRight('CreateAsset');

    return $self->_create_record($data);
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('ShowAsset');
}

sub lifecycle_hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $asset = $self->record;
    my @links;

    # lifecycle actions
    my $lifecycle = $asset->LifecycleObj;
    my $current = $asset->Status;

    for my $info ( $lifecycle->Actions($current) ) {
        my $next = $info->{'to'};
        next unless $lifecycle->IsTransition( $current => $next );

        my $check = $lifecycle->CheckRight( $current => $next );
        next unless $asset->CurrentUserHasRight($check);

        my $url = $self_link->{_url};

        push @links, {
            %$info,
            label => $self->current_user->loc($info->{'label'} || ucfirst($next)),
            ref   => 'lifecycle',
            _url  => $url,
        };
    }

    return @links;
}

sub hypermedia_links {
    my $self = shift;
    my $self_link = $self->_self_link;
    my $links = $self->_default_hypermedia_links(@_);
    my $asset = $self->record;

    push @$links, $self->_transaction_history_link;
    push @$links, $self->lifecycle_hypermedia_links;

    return $links;
}

__PACKAGE__->meta->make_immutable;

1;

