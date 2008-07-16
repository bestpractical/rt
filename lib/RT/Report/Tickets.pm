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
package RT::Report::Tickets;

use base qw/RT::Model::TicketCollection/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;

sub groupings {
    my $self   = shift;
    my %args   = (@_);
    my @fields = qw(
        owner
        status
      Requestor
      Cc
      AdminCc
      Watcher
      Creator
      LastUpdatedBy
        queue
        DueDaily
        DueMonthly
        DueAnnually
        ResolvedDaily
        ResolvedMonthly
        ResolvedAnnually
        CreatedDaily
        CreatedMonthly
        CreatedAnnually
        last_updatedDaily
        last_updatedMonthly
        last_updatedAnnually
        StartedDaily
        StartedMonthly
        StartedAnnually
        startsDaily
        startsMonthly
        startsAnnually
    );

    @fields = map { $_, $_ } @fields;

    my $queues = $args{'Queues'};
    if ( !$queues && $args{'query'} ) {
        require RT::Interface::Web::QueryBuilder::Tree;
        my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
        $tree->parse_sql( query => $args{'query'} );
        $queues = $tree->get_referenced_queues;
    }

    if ($queues) {
        my $CustomFields = RT::Model::CustomFieldCollection->new;
        foreach my $id ( keys %$queues ) {
            my $queue = RT::Model::Queue->new;
            $queue->load($id);
            unless ( $queue->id ) {

                # XXX TODO: This ancient code dates from a former developer
                # we have no idea what it means or why cfqueues are so encoded.
                $id =~ s/^.'*(.*).'*$/$1/;
                $queue->load($id);
            }
            $CustomFields->limit_to_queue( $queue->id );
        }
        $CustomFields->limit_to_global;
        while ( my $CustomField = $CustomFields->next ) {
            push @fields, "Custom field '" . $CustomField->name . "'", "CF.{" . $CustomField->id . "}";
        }
    }
    return @fields;
}

sub label {
    my $self  = shift;
    my $field = shift;
    if ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) {
        my $cf = $1;
        return _( "Custom field '%1'", $cf ) if $cf =~ /\D/;
        my $obj = RT::Model::CustomField->new;
        $obj->load($cf);
        return _( "Custom field '%1'", $obj->name );
    }
    return _($field);
}

sub group_by {
    my $self = shift;
    my %args = ref $_[0] ? %{ $_[0] } : (@_);

    $self->{'_group_by_field'} = $args{'column'};
    %args = $self->_field_to_function(%args);

    $self->SUPER::group_by( \%args );
}

sub column {
    my $self = shift;
    my %args = (@_);

    if ( $args{'column'} && !$args{'function'} ) {
        %args = $self->_field_to_function(%args);
    }

    return $self->SUPER::column(%args);
}

=head2 _do_search

Subclass _do_search from our parent so we can go through and add in empty 
columns if it makes sense 

=cut

sub _do_search {
    my $self = shift;
    $self->SUPER::_do_search(@_);
    $self->add_empty_rows;
}

=head2 _field_to_function column

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _field_to_function {
    my $self = shift;
    my %args = (@_);

    my $field = $args{'column'};

    if ( $field =~ /^(.*)(Daily|Monthly|Annually)$/ ) {
        my ( $field, $grouping ) = ( $1, $2 );
        if ( $grouping =~ /Daily/ ) {
            $args{'function'} = "SUBSTR($field,1,10)";
        } elsif ( $grouping =~ /Monthly/ ) {
            $args{'function'} = "SUBSTR($field,1,7)";
        } elsif ( $grouping =~ /Annually/ ) {
            $args{'function'} = "SUBSTR($field,1,4)";
        }
    } elsif ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) {    #XXX: use CFDecipher method
        my $cf_name = $1;
        my $cf      = RT::Model::CustomField->new;
        $cf->load($cf_name);
        unless ( $cf->id ) {
            Jifty->log->error("Couldn't load CustomField #$cf_name");
        } else {
            my ( $ticket_cf_alias, $cf_alias ) = $self->_custom_field_join( $cf->id, $cf->id, $cf_name );
            @args{qw(alias column)} = ( $ticket_cf_alias, 'content' );
        }
    }
    elsif ( $field =~ /^(?:Watcher|(Requestor|Cc|AdminCc))$/ ) {
        my $type = $1;
        my ( $g_alias, $gm_alias, $u_alias ) = $self->_watcherjoin($type);
        @args{qw(alias column)} = ( $u_alias, 'name' );
    }
    return %args;
}

# Override the add_record from DBI::SearchBuilder::Unique. id isn't id here
# wedon't want to disambiguate all the items with a count of 1.
sub add_record {
    my $self   = shift;
    my $record = shift;
    push @{ $self->{'items'} }, $record;
    $self->{'rows'}++;
}

1;

# Gotta skip over RT::Model::TicketCollection->next, since it does all sorts of crazy magic we
# don't want.
sub next {
    my $self = shift;
    $self->RT::SearchBuilder::next(@_);

}

sub new_item {
    my $self = shift;
    return RT::Report::Tickets::Entry->new( current_user => RT->system_user );    # $self->current_user);
}

=head2 add_empty_rows

If we're grouping on a criterion we know how to add zero-value rows
for, do that.

=cut

sub add_empty_rows {
    my $self = shift;
    if ( $self->{'_group_by_field'} eq 'status' ) {
        my %has = map { $_->__value('status') => 1 } @{ $self->items_array_ref || [] };

        foreach my $status ( grep !$has{$_}, RT::Model::Queue->new->status_array ) {

            my $record = $self->new_item;
            $record->load_from_hash(
                {   id     => 0,
                    status => $status
                }
            );
            $self->add_record($record);
        }
    }
}

1;
