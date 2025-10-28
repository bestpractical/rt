# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

=head1 NAME

RT::Search::Kanban - Utility functions for Kanban boards

=head1 DESCRIPTION

This class is a collection of utility functions for working with Kanban boards.

=cut

package RT::Search::Kanban;

use warnings;
use strict;

=head2 GetKanbanColumns

Returns an ordered list of columns (statuses) to display on the Kanban board.
Takes a Tickets collection and optional parameters.

=cut

sub GetKanbanColumns {
    my %args = (
        Tickets => undef,
        Field   => 'Status',
        @_
    );

    my $tickets = $args{Tickets};
    return () unless $tickets;

    # For Status field, use the queue's lifecycle
    # Note: Kanban is only shown for single-queue searches, so we can safely
    # get the lifecycle from the first ticket's queue
    if ( $args{Field} eq 'Status' ) {
        my $lifecycle;

        if ( my $first = $tickets->First ) {
            $lifecycle = $first->QueueObj->LifecycleObj;
            $tickets->GotoFirstItem;
        }

        $lifecycle ||= RT::Lifecycle->Load( Name => 'default' );

        if ( $lifecycle ) {
            my @statuses = $lifecycle->Valid;
            # Filter out any potential references
            return grep { defined $_ && !ref($_) } @statuses;
        }
    }

    # For Priority field, return all configured priority values if PriorityAsString is enabled
    if ( $args{Field} eq 'Priority' ) {
        my $priority_config = RT->Config->Get('PriorityAsString');
        if ( $priority_config && ref($priority_config) eq 'HASH' ) {
            # Return priority values in order (sorted by their numeric key)
            my @priorities = map { $priority_config->{$_} } sort { $a <=> $b } keys %$priority_config;
            # Filter out any potential references
            return grep { defined $_ && !ref($_) } @priorities;
        }
    }

    # For Owner field, return all valid owners (users with OwnTicket right)
    # but respect the DropdownMenuLimit to avoid performance issues
    if ( $args{Field} eq 'Owner' ) {
        my $queue;
        if ( my $first = $tickets->First ) {
            $queue = $first->QueueObj;
            $tickets->GotoFirstItem;
        }

        if ( $queue && $queue->id ) {
            my $Users = RT::Users->new( $tickets->CurrentUser );
            $Users->LimitToPrivileged;
            my $isSU = $tickets->CurrentUser->HasRight( Right => 'SuperUser', Object => $RT::System );
            $Users->WhoHaveRight(
                Right               => 'OwnTicket',
                Object              => $queue,
                IncludeSystemRights => 1,
                IncludeSuperusers   => $isSU
            );

            my $dropdown_limit = RT->Config->Get('DropdownMenuLimit') || 50;
            my @owners;
            while ( my $User = $Users->Next ) {
                my $name = $User->Name;
                push @owners, $name if defined $name && !ref($name);
                last if @owners >= $dropdown_limit;
            }

            # If we found valid owners and didn't hit the limit, return them
            if ( @owners && @owners < $dropdown_limit ) {
                # Filter out any potential references and sort
                return sort grep { defined $_ && !ref($_) } @owners;
            }
            # Otherwise fall through to show only owners found in tickets
        }
    }

    # For Select type custom fields, return all possible values
    if ( $args{Field} =~ /^CF\.\{(.+)\}$/ || $args{Field} =~ /^CustomField\.\{(.+)\}$/ ) {
        my $cf_name = $1;
        my $cf = RT::CustomField->new( $tickets->CurrentUser );

        # Try to load by name first
        $cf->LoadByName( Name => $cf_name );

        # If that didn't work, try loading by ID
        unless ( $cf->id ) {
            $cf->Load( $cf_name );
        }

        if ( $cf->id && $cf->Type eq 'Select' ) {
            my @values = map { $_->Name } @{ $cf->Values->ItemsArrayRef || [] };
            # Filter out any potential references
            return grep { defined $_ && !ref($_) } @values;
        }
        # Otherwise fall through to show only values found in tickets
    }

    my %seen;
    my @columns;

    while ( my $ticket = $tickets->Next ) {
        my $value;
        if ( $args{Field} =~ /^CF\.\{(.+)\}$/ || $args{Field} =~ /^CustomField\.\{(.+)\}$/ ) {
            my $cf_name = $1;
            $value = $ticket->FirstCustomFieldValue($cf_name) || '';
        } elsif ( $ticket->can($args{Field}) ) {
            my $method = $args{Field};
            $value = $ticket->$method() || '';

            if ( ref($value) ) {
                if ( $value->can('Name') ) {
                    $value = $value->Name || '';
                } elsif ( $value->can('id') ) {
                    $value = $value->id || '';
                } else {
                    # If it's still a reference and we can't convert it, skip it
                    $value = '';
                }
            }
        } else {
            $value = '';
        }

        # Only add if it's not a reference
        unless ( $seen{$value}++ || ref($value) ) {
            push @columns, $value;
        }
    }

    $tickets->GotoFirstItem;
    return @columns;
}

=head2 GroupTicketsByField

Groups tickets by a specified field and returns a hash reference
with field values as keys and arrays of tickets as values.

=cut

sub GroupTicketsByField {
    my %args = (
        Tickets => undef,
        Field   => 'Status',
        @_
    );

    my $tickets = $args{Tickets};
    return {} unless $tickets;

    my %groups;

    while ( my $ticket = $tickets->Next ) {
        my $value;

        if ( $args{Field} =~ /^CF\.\{(.+)\}$/ || $args{Field} =~ /^CustomField\.\{(.+)\}$/ ) {
            # Custom field
            my $cf_name = $1;
            $value = $ticket->FirstCustomFieldValue($cf_name) || '';
        } elsif ( $args{Field} eq 'Priority' && RT->Config->Get('PriorityAsString') ) {
            # Use PriorityAsString if configured
            $value = $ticket->PriorityAsString || '';
        } elsif ( $ticket->can($args{Field}) ) {
            # Regular field
            my $method = $args{Field};
            $value = $ticket->$method() || '';
            # If it's an object, get its Name or id
            if ( ref($value) && $value->can('Name') ) {
                $value = $value->Name;
            } elsif ( ref($value) && $value->can('id') ) {
                $value = $value->id;
            }
        } else {
            $value = '';
        }

        push @{ $groups{$value} }, $ticket;
    }

    $tickets->GotoFirstItem;
    return \%groups;
}

=head2 GetKanbanField

Determines which field should be used for the Kanban board columns.
Checks for a saved preference, otherwise defaults to Status.

=cut

sub GetKanbanField {
    my %args = (
        SavedSearch => undef,
        @_
    );

    if ( $args{SavedSearch} && $args{SavedSearch}->can('GetOption') ) {
        my $saved_field = $args{SavedSearch}->GetOption('KanbanGroupBy');
        return $saved_field if $saved_field;
    }

    return 'Status';
}

=head2 GetKanbanSwimLane

Determines which field should be used for swimlanes (horizontal grouping).
Returns empty string if swimlanes are disabled.

=cut

sub GetKanbanSwimLane {
    my %args = (
        SavedSearch => undef,
        @_
    );

    if ( $args{SavedSearch} && $args{SavedSearch}->can('GetOption') ) {
        my $saved_field = $args{SavedSearch}->GetOption('KanbanSwimLane');
        return $saved_field if defined $saved_field;
    }

    return RT->Config->Get('DefaultKanbanSwimLane') || '';
}

=head2 GroupTicketsByTwoFields

Groups tickets by two fields for swimlane display. Returns a hash reference
with structure: { swimlane_value => { column_value => [@tickets] } }

=cut

sub GroupTicketsByTwoFields {
    my %args = (
        Tickets      => undef,
        ColumnField  => 'Status',
        SwimLaneField => '',
        @_
    );

    my $tickets = $args{Tickets};
    return {} unless $tickets;

    # If no swimlane field, fall back to single-level grouping
    unless ( $args{SwimLaneField} ) {
        return { '' => GroupTicketsByField(
            Tickets => $tickets,
            Field   => $args{ColumnField}
        ) };
    }

    my %groups;

    while ( my $ticket = $tickets->Next ) {
        # Get column value
        my $column_value;
        if ( $args{ColumnField} =~ /^CF\.\{(.+)\}$/ || $args{ColumnField} =~ /^CustomField\.\{(.+)\}$/ ) {
            my $cf_name = $1;
            $column_value = $ticket->FirstCustomFieldValue($cf_name) || '';
        } elsif ( $args{ColumnField} eq 'Priority' && RT->Config->Get('PriorityAsString') ) {
            $column_value = $ticket->PriorityAsString || '';
        } elsif ( $ticket->can($args{ColumnField}) ) {
            my $method = $args{ColumnField};
            $column_value = $ticket->$method() || '';
            if ( ref($column_value) && $column_value->can('Name') ) {
                $column_value = $column_value->Name;
            } elsif ( ref($column_value) && $column_value->can('id') ) {
                $column_value = $column_value->id;
            }
        } else {
            $column_value = '';
        }

        # Get swimlane value
        my $swimlane_value;
        if ( $args{SwimLaneField} =~ /^CF\.\{(.+)\}$/ || $args{SwimLaneField} =~ /^CustomField\.\{(.+)\}$/ ) {
            my $cf_name = $1;
            $swimlane_value = $ticket->FirstCustomFieldValue($cf_name) || '';
        } elsif ( $args{SwimLaneField} eq 'Priority' && RT->Config->Get('PriorityAsString') ) {
            $swimlane_value = $ticket->PriorityAsString || '';
        } elsif ( $ticket->can($args{SwimLaneField}) ) {
            my $method = $args{SwimLaneField};
            $swimlane_value = $ticket->$method() || '';
            if ( ref($swimlane_value) && $swimlane_value->can('Name') ) {
                $swimlane_value = $swimlane_value->Name;
            } elsif ( ref($swimlane_value) && $swimlane_value->can('id') ) {
                $swimlane_value = $swimlane_value->id;
            }
        } else {
            $swimlane_value = '';
        }

        push @{ $groups{$swimlane_value}{$column_value} }, $ticket;
    }

    $tickets->GotoFirstItem;
    return \%groups;
}

RT::Base->_ImportOverlays();

1;
