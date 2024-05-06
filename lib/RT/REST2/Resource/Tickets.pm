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

package RT::REST2::Resource::Tickets;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::ProcessPOSTasGET',
    'RT::REST2::Resource::Collection::Search';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/tickets/?$},
        block => sub { { collection_class => 'RT::Tickets' } },
    )
}

use Encode qw( decode_utf8 );
use RT::REST2::Util qw( error_as_json expand_uid );
use RT::Search::Simple;

has 'query' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    lazy_build  => 1,
);

sub _build_query {
    my $self  = shift;
    my $query = decode_utf8($self->request->param('query') || "");

    if ($self->request->param('simple') and $query) {
        # XXX TODO: Note that "normal" ModifyQuery callback isn't invoked
        # XXX TODO: Special-casing of "#NNN" isn't used
        my $search = RT::Search::Simple->new(
            Argument    => $query,
            TicketsObj  => $self->collection,
        );
        $query = $search->QueryToSQL;
    }
    return $query;
}

sub allowed_methods {
    [ 'GET', 'HEAD', 'POST' ]
}

override 'limit_collection' => sub {
    my $self = shift;
    my ($ok, $msg) = $self->collection->FromSQL( $self->query );
    return error_as_json( $self->response, 0, $msg ) unless $ok;
    super();
    return 1;
};

sub expand_field {
    my $self         = shift;
    my $item         = shift;
    my $field        = shift;
    my $param_prefix = shift;
    if ( $field =~ /^(Requestor|AdminCc|Cc)/ ) {
        my $role    = $1;
        my $members = [];
        if ( my $group = $item->RoleGroup($role) ) {
            my $gms = $group->MembersObj;
            while ( my $gm = $gms->Next ) {
                push @$members, $self->_expand_object( $gm->MemberObj->Object, $field, $param_prefix );
            }
        }
        return $members;
    }
    return $self->SUPER::expand_field( $item, $field, $param_prefix );
}

__PACKAGE__->meta->make_immutable;

1;
