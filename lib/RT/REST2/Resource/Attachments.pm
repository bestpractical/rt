# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Attachments;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'RT::REST2::Resource::Collection';
with 'RT::REST2::Resource::Collection::QueryByJSON';

sub dispatch_rules {
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/attachments/?$},
        block => sub { { collection_class => 'RT::Attachments' } },
    ),
    Path::Dispatcher::Rule::Regex->new(
        regex => qr{^/transaction/(\d+)/attachments/?$},
        block => sub {
            my ($match, $req) = @_;
            my $txn = RT::Transaction->new($req->env->{"rt.current_user"});
            $txn->Load($match->pos(1));
            return { collection => $txn->Attachments };
        },
    )
}

around 'limit_collection' => sub {
    my $orig = shift;
    my $self = shift;

    if (my $ticket_criteria = $self->_query_field('TicketId')) {
        my $collection = $self->collection;
        my $tx_alias = $collection->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'TransactionId',
            TABLE2 => 'Transactions',
            FIELD2 => 'id',
        );

        $collection->Limit(
            ALIAS    => $tx_alias,
            FIELD    => 'ObjectType',
            OPERATOR => '=',
            VALUE    => 'RT::Ticket'
        );

        $collection->Limit(
            ALIAS    => $tx_alias,
            FIELD    => 'ObjectId',
            OPERATOR => $ticket_criteria->{operator} // '=',
            VALUE    => $ticket_criteria->{value},
        );
    }

    return $self->$orig;
};

sub _query_field {
    my ($self, $field) = @_;
    foreach my $condition( @{$self->query} ) {
        if ($condition->{field} eq $field) {
            return $condition;
        }
    }
    return undef;
}


__PACKAGE__->meta->make_immutable;

1;

