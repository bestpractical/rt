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

package RT::REST2::Resource::Group;
use strict;
use warnings;

use Moose;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid);

extends 'RT::REST2::Resource::Record';
with 'RT::REST2::Resource::Record::Readable'
        => { -alias => { serialize => '_default_serialize' } },
    'RT::REST2::Resource::Record::DeletableByDisabling',
        => { -alias => { delete_resource => '_delete_resource' } },
    'RT::REST2::Resource::Record::Writable',
        => { -alias => { create_record => '_create_record' } },
    'RT::REST2::Resource::Record::Hypermedia'
        => { -alias => { hypermedia_links => '_default_hypermedia_links' } };

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/?$},
        block => sub { { record_class => 'RT::Group' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/group/(\d+)/?$},
        block => sub { { record_class => 'RT::Group', record_id => shift->pos(1) } },
    )
}

sub serialize {
    my $self = shift;
    my $data = $self->_default_serialize(@_);

    $data->{Members} = [
        map { expand_uid($_->MemberObj->Object->UID) }
        @{ $self->record->MembersObj->ItemsArrayRef }
    ];

    $data->{Disabled} = $self->record->PrincipalObj->Disabled;

    return $data;
}

sub hypermedia_links {
    my $self = shift;
    my $links = $self->_default_hypermedia_links(@_);
    push @$links, $self->_transaction_history_link;

    my $id = $self->record->id;
    push @$links,
      { ref  => 'members',
        _url => RT::REST2->base_uri . "/group/$id/members",
      };
    return $links;
}

sub create_record {
    my $self = shift;
    my $data = shift;

    return (\403, $self->record->loc("Permission Denied"))
        unless  $self->current_user->HasRight(
            Right   => "AdminGroup",
            Object  => RT->System,
        );

    return $self->_create_record($data);
}

sub delete_resource {
    my $self = shift;

    return (\403, $self->record->loc("Permission Denied"))
        unless $self->record->CurrentUserHasRight('AdminGroup');

    return $self->_delete_resource;
}

sub forbidden {
    my $self = shift;
    return 0 unless $self->record->id;
    return !$self->record->CurrentUserHasRight('SeeGroup');
}

__PACKAGE__->meta->make_immutable;

1;

