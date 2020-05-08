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

package RT::REST2::Resource::CustomFieldValues;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

has 'customfield' => (
    is  => 'ro',
    isa => 'RT::CustomField',
);

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/customfield/(\d+)/values/?$},
        block => sub {
            my ($match, $req) = @_;
            my $cf_id = $match->pos(1);
            my $cf = RT::CustomField->new($req->env->{"rt.current_user"});
            $cf->Load($cf_id);
            my $values = $cf->Values;
            return { customfield => $cf, collection => $values }
        },
    )
}

sub forbidden {
    my $self = shift;
    my $method = $self->request->method;
    if ($method eq 'GET') {
        return !$self->customfield->CurrentUserHasRight('SeeCustomField');
    } else {
        return !($self->customfield->CurrentUserHasRight('AdminCustomField') ||$self->customfield->CurrentUserHasRight('AdminCustomFieldValues'));
    }
}

sub serialize {
    my $self = shift;
    my $collection = $self->collection;
    my $cf = $self->customfield;
    my @results;

    while (my $item = $collection->Next) {
        my $result = {
            type => 'customfieldvalue',
            id   => $item->id,
            name   => $item->Name,
            _url => RT::REST2->base_uri . "/customfield/" . $cf->id . '/value/' . $item->id,
        };
        push @results, $result;
    }
    return {
        count       => scalar(@results)         + 0,
        total       => $collection->CountAll    + 0,
        per_page    => $collection->RowsPerPage + 0,
        page        => ($collection->FirstRow / $collection->RowsPerPage) + 1,
        items       => \@results,
    };
}

__PACKAGE__->meta->make_immutable;

1;
