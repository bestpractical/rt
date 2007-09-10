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

sub Groupings {
    my $self = shift;
    my %args = (@_);
    my @fields = qw(
        Owner
        Status
        Queue
        DueDaily
        DueMonthly
        DueAnnually
        ResolvedDaily
        ResolvedMonthly
        ResolvedAnnually
        CreatedDaily
        CreatedMonthly
        CreatedAnnually
        LastUpdatedDaily
        LastUpdatedMonthly
        LastUpdatedAnnually
        StartedDaily
        StartedMonthly
        StartedAnnually
        StartsDaily
        StartsMonthly
        StartsAnnually
    );

    @fields = map {$_, $_} @fields;

    my $queues = $args{'Queues'};
    if ( !$queues && $args{'Query'} ) {
        require RT::Interface::Web::QueryBuilder::Tree;
        my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
        $tree->ParseSQL( Query => $args{'Query'}, CurrentUser => $self->current_user );
        $queues = $tree->GetReferencedQueues;
    }

    if ( $queues ) {
        my $CustomFields = RT::Model::CustomFieldCollection->new( $self->current_user );
        foreach my $id (keys %$queues) {
            my $queue = RT::Model::Queue->new( $self->current_user );
            $queue->load($id);
            unless ($queue->id) {
                # XXX TODO: This ancient code dates from a former developer
                # we have no idea what it means or why cfqueues are so encoded.
                $id =~ s/^.'*(.*).'*$/$1/;
                $queue->load($id);
            }
            $CustomFields->LimitToQueue($queue->id);
        }
        $CustomFields->LimitToGlobal;
        while ( my $CustomField = $CustomFields->next ) {
            push @fields, "Custom field '". $CustomField->Name ."'", "CF.{". $CustomField->id ."}";
        }
    }
    return @fields;
}

sub Label {
    my $self = shift;
    my $field = shift;
    if ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) {
        my $cf = $1;
        return $self->current_user->loc( "Custom field '[_1]'", $cf ) if $cf =~ /\D/;
        my $obj = RT::Model::CustomField->new( $self->current_user );
        $obj->load( $cf );
        return $self->current_user->loc( "Custom field '[_1]'", $obj->Name );
    }
    return $self->current_user->loc($field);
}

sub GroupBy {
    my $self = shift;
    my %args = ref $_[0]? %{ $_[0] }: (@_);

    $self->{'_group_by_field'} = $args{'column'};
    %args = $self->_FieldToFunction( %args );

    $self->SUPER::GroupBy( \%args );
}

sub Column {
    my $self = shift;
    my %args = (@_);

    if ( $args{'column'} && !$args{'FUNCTION'} ) {
        %args = $self->_FieldToFunction( %args );
    }

    return $self->SUPER::Column( %args );
}

=head2 _do_search

Subclass _do_search from our parent so we can go through and add in empty 
columns if it makes sense 

=cut

sub _do_search {
    my $self = shift;
    $self->SUPER::_do_search( @_ );
    $self->AddEmptyRows;
}

=head2 _FieldToFunction column

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _FieldToFunction {
    my $self = shift;
    my %args = (@_);

    my $field = $args{'column'};

    if ($field =~ /^(.*)(Daily|Monthly|Annually)$/) {
        my ($field, $grouping) = ($1, $2);
        if ( $grouping =~ /Daily/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,10)";
        }
        elsif ( $grouping =~ /Monthly/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,7)";
        }
        elsif ( $grouping =~ /Annually/ ) {
            $args{'FUNCTION'} = "SUBSTR($field,1,4)";
        }
    } elsif ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) { #XXX: use CFDecipher method
        my $cf_name = $1;
        my $cf = RT::Model::CustomField->new( $self->current_user );
        $cf->load($cf_name);
        unless ( $cf->id ) {
            $RT::Logger->error("Couldn't load CustomField #$cf_name");
        } else {
            my ($ticket_cf_alias, $cf_alias) = $self->_CustomFieldjoin($cf->id, $cf->id, $cf_name);
            @args{qw(alias column)} = ($ticket_cf_alias, 'Content');
        }
    }
    return %args;
}


# Override the add_record from DBI::SearchBuilder::Unique. id isn't id here
# wedon't want to disambiguate all the items with a count of 1.
sub add_record {
    my $self = shift;
    my $record = shift;
    push @{$self->{'items'}}, $record;
    $self->{'rows'}++;
}

1;



# Gotta skip over RT::Model::TicketCollection->next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub new_item {
    my $self = shift;
    return RT::Report::Tickets::Entry->new($RT::SystemUser); # $self->current_user);
}


=head2 AddEmptyRows

If we're grouping on a criterion we know how to add zero-value rows
for, do that.

=cut

sub AddEmptyRows {
    my $self = shift;
    if ( $self->{'_group_by_field'} eq 'Status' ) {
        my %has = map { $_->__value('Status') => 1 } @{ $self->items_array_ref || [] };

        foreach my $status ( grep !$has{$_}, RT::Model::Queue->new($self->current_user)->StatusArray ) {

            my $record = $self->new_item;
            $record->load_from_hash( {
                id     => 0,
                status => $status
            } );
            $self->add_record($record);
        }
    }
}

1;
