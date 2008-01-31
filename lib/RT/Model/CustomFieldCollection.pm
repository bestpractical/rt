# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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

=head1 name

  RT::Model::CustomFieldCollection - a collection of RT CustomField objects

=head1 SYNOPSIS

  use RT::Model::CustomFieldCollection;

=head1 description

=head1 METHODS



=cut

use warnings;
use strict;

package RT::Model::CustomFieldCollection;
use base qw/RT::SearchBuilder/;
use Jifty::DBI::Collection::Unique;

sub ocf_alias {
    my $self = shift;
    unless ( $self->{_sql_ocfalias} ) {

        $self->{'_sql_ocfalias'} = $self->new_alias('ObjectCustomFields');
        $self->join(
            alias1  => 'main',
            column1 => 'id',
            alias2  => $self->ocf_alias,
            column2 => 'custom_field'
        );
    }
    return ( $self->{_sql_ocfalias} );
}

# {{{ sub limit_ToGlobalOrQueue

=head2 limit_ToGlobalOrQueue QUEUEID

Limits the set of custom fields found to global custom fields or those tied to the queue with ID QUEUEID 

=cut

sub limit_to_global_or_queue {
    my $self  = shift;
    my $queue = shift;
    $self->limit_to_global_or_object_id($queue);
    $self->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
}

# }}}

# {{{ sub limit_ToQueue

=head2 limit_ToQueue QUEUEID

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub limit_to_queue {
    my $self  = shift;
    my $queue = shift;

    $self->limit(
        alias            => $self->ocf_alias,
        entry_aggregator => 'OR',
        column           => 'object_id',
        value            => "$queue"
    ) if defined $queue;
    $self->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
}

# }}}

# {{{ sub limit_ToGlobal

=head2 limit_ToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or limit_ToQueue

=cut

sub limit_to_global {
    my $self = shift;

    $self->limit(
        alias            => $self->ocf_alias,
        entry_aggregator => 'OR',
        column           => 'object_id',
        value            => 0
    );
    $self->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
}

# }}}

# {{{ sub _do_search

=head2 _do_search

A subclass of Jifty::DBI::_do_search that makes sure that 
 _disabled rows never get seen unless we're explicitly trying to see 
them.

=cut

sub _do_search {
    my $self = shift;

#unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless ( $self->{'find_disabled_rows'} ) {
        $self->limit_to_enabled();
    }

    return ( $self->SUPER::_do_search(@_) );

}

# }}}

# {{{ sub next

=head2 next

Returns the next custom field that this user can see.

=cut

sub next {
    my $self = shift;

    my $CF = $self->SUPER::next();
    if ( ( defined($CF) ) and ( ref($CF) ) ) {

        if ( $CF->current_user_has_right('SeeCustomField') ) {
            return ($CF);
        }

        #If the user doesn't have the right to show this queue
        else {
            return ( $self->next() );
        }
    }

    #if there never was any queue
    else {
        return (undef);
    }

}

# }}}

sub limit_to_lookup_type {
    my $self   = shift;
    my $lookup = shift;

    $self->limit( column => 'lookup_type', value => "$lookup" );
}

sub limit_to_child_type {
    my $self   = shift;
    my $lookup = shift;

    $self->limit( column => 'lookup_type', value => "$lookup" );
    $self->limit( column => 'lookup_type', ENDSWITH => "$lookup" );
}

sub limit_to_parent_type {
    my $self   = shift;
    my $lookup = shift;

    $self->limit( column => 'lookup_type', value => "$lookup" );
    $self->limit( column => 'lookup_type', starts_with => "$lookup" );
}

sub limit_to_global_or_object_id {
    my $self        = shift;
    my $global_only = 1;

    foreach my $id (@_) {
        $self->limit(
            alias            => $self->ocf_alias,
            column           => 'object_id',
            operator         => '=',
            value            => $id || 0,
            entry_aggregator => 'OR'
        );
        $global_only = 0 if $id;
    }

    $self->limit(
        alias            => $self->ocf_alias,
        column           => 'object_id',
        operator         => '=',
        value            => 0,
        entry_aggregator => 'OR'
    ) unless $global_only;

    $self->order_by(
        { alias => $self->ocf_alias, column => 'object_id', order => 'DESC' },
        { alias => $self->ocf_alias, column => 'sort_order' },
    );

# This doesn't work on postgres.
#$self->order_by( alias => $class_cfs , column => "sort_order", order => 'ASC');

}

1;

