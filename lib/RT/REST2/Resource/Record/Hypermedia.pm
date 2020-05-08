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

package RT::REST2::Resource::Record::Hypermedia;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use RT::REST2::Util qw(expand_uid expand_uri custom_fields_for);
use JSON qw(to_json);

sub hypermedia_links {
    my $self = shift;
    return [ $self->_self_link, $self->_rtlink_links, $self->_customfield_links, $self->_customrole_links ];
}

sub _self_link {
    my $self = shift;
    my $record = $self->record;

    my $class = blessed($record);
    $class =~ s/^RT:://;
    $class = lc $class;
    my $id = $record->id;

    return {
        ref     => 'self',
        type    => $class,
        id      => $id,
        _url    => RT::REST2->base_uri . "/$class/$id",
    };
}

sub _transaction_history_link {
    my $self = shift;
    my $self_link = $self->_self_link;
    return {
        ref     => 'history',
        _url    => $self_link->{_url} . '/history',
    };
}

my %link_refs = (
    DependsOn => 'depends-on',
    DependedOnBy => 'depended-on-by',
    MemberOf => 'parent',
    Members => 'child',
    RefersTo => 'refers-to',
    ReferredToBy => 'referred-to-by',
);

sub _rtlink_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    for my $relation (keys %link_refs) {
        my $ref = $link_refs{$relation};
        my $mode = $RT::Link::TYPEMAP{$relation}{Mode};
        my $type = $RT::Link::TYPEMAP{$relation}{Type};
        my $method = $mode . "Obj";

        my $links = $record->$relation;

        while (my $link = $links->Next) {
            my $entry;
            if ( $link->LocalTarget and $link->LocalBase ){
                # Internal links
                $entry = expand_uid($link->$method->UID);
            }
            else {
                # Links to external URLs
                $entry = expand_uri($link->$mode);
            }
            push @links, {
                %$entry,
                ref => $ref,
            };
        }
    }

    return @links;
}

sub _customfield_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    if (my $cfs = custom_fields_for($record)) {
        while (my $cf = $cfs->Next) {
            my $entry = expand_uid($cf->UID);
            push @links, {
                %$entry,
                ref => 'customfield',
                name => $cf->Name,
            };
        }
    }

    return @links;
}

sub _customrole_links {
    my $self = shift;
    my $record = $self->record;
    my @links;

    return unless $record->DOES('RT::Record::Role::Roles');

    for my $role ($record->Roles(UserDefined => 1)) {
        if ($role =~ /^RT::CustomRole-(\d+)$/) {
            my $cr = RT::CustomRole->new($record->CurrentUser);
            $cr->Load($1);
            if ($cr->Id) {
                my $entry = expand_uid($cr->UID);
                push @links, {
                    %$entry,
                    group_type => $cr->GroupType,
                    ref => 'customrole',
                };
            }
        }
    }

    return @links;
}

1;

