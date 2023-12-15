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

package RT::Report::Tickets;

use base qw/RT::Report RT::Tickets/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;
use 5.010;

=head1 NAME

RT::Report::Tickets - Ticket search charts

=head1 DESCRIPTION

This is the backend class for ticket search charts.

=head1 METHOD

=cut

__PACKAGE__->RegisterCustomFieldJoin(@$_) for
    [ "RT::Transaction" => sub { $_[0]->JoinTransactions } ],
    [ "RT::Queue"       => sub {
            # XXX: Could avoid join and use main.Queue with some refactoring?
            return $_[0]->{_sql_aliases}{queues} ||= $_[0]->Join(
                ALIAS1 => 'main',
                FIELD1 => 'Queue',
                TABLE2 => 'Queues',
                FIELD2 => 'id',
            );
        }
    ];

our @GROUPINGS = (
    Status => 'Enum',                   #loc_left_pair

    Queue  => 'Queue',                  #loc_left_pair

    InitialPriority => 'Priority',          #loc_left_pair
    FinalPriority   => 'Priority',          #loc_left_pair
    Priority        => 'Priority',          #loc_left_pair

    Owner         => 'User',            #loc_left_pair
    Creator       => 'User',            #loc_left_pair
    LastUpdatedBy => 'User',            #loc_left_pair

    Requestor     => 'Watcher',         #loc_left_pair
    Cc            => 'Watcher',         #loc_left_pair
    AdminCc       => 'Watcher',         #loc_left_pair
    Watcher       => 'Watcher',         #loc_left_pair
    CustomRole    => 'Watcher',

    Created       => 'Date',            #loc_left_pair
    Starts        => 'Date',            #loc_left_pair
    Started       => 'Date',            #loc_left_pair
    Resolved      => 'Date',            #loc_left_pair
    Due           => 'Date',            #loc_left_pair
    Told          => 'Date',            #loc_left_pair
    LastUpdated   => 'Date',            #loc_left_pair

    CF            => 'CustomField',     #loc_left_pair

    SLA           => 'Enum',            #loc_left_pair
);

# loc'able strings below generated with (s/loq/loc/):
#   perl -MRT=-init -MRT::Report::Tickets -E 'say qq{\# loq("$_->[0]")} while $_ = splice @RT::Report::Tickets::STATISTICS, 0, 2'
#
# loc("Ticket count")
# loc("Summary of time worked")
# loc("Total time worked")
# loc("Average time worked")
# loc("Minimum time worked")
# loc("Maximum time worked")
# loc("Summary of time estimated")
# loc("Total time estimated")
# loc("Average time estimated")
# loc("Minimum time estimated")
# loc("Maximum time estimated")
# loc("Summary of time left")
# loc("Total time left")
# loc("Average time left")
# loc("Minimum time left")
# loc("Maximum time left")
# loc("Summary of Created to Started")
# loc("Total Created to Started")
# loc("Average Created to Started")
# loc("Minimum Created to Started")
# loc("Maximum Created to Started")
# loc("Summary of Created to Resolved")
# loc("Total Created to Resolved")
# loc("Average Created to Resolved")
# loc("Minimum Created to Resolved")
# loc("Maximum Created to Resolved")
# loc("Summary of Created to LastUpdated")
# loc("Total Created to LastUpdated")
# loc("Average Created to LastUpdated")
# loc("Minimum Created to LastUpdated")
# loc("Maximum Created to LastUpdated")
# loc("Summary of Starts to Started")
# loc("Total Starts to Started")
# loc("Average Starts to Started")
# loc("Minimum Starts to Started")
# loc("Maximum Starts to Started")
# loc("Summary of Due to Resolved")
# loc("Total Due to Resolved")
# loc("Average Due to Resolved")
# loc("Minimum Due to Resolved")
# loc("Maximum Due to Resolved")
# loc("Summary of Started to Resolved")
# loc("Total Started to Resolved")
# loc("Average Started to Resolved")
# loc("Minimum Started to Resolved")
# loc("Maximum Started to Resolved")

our @STATISTICS = (
    COUNT => ['Ticket count', 'Count', 'id'],
);

foreach my $field (qw(TimeWorked TimeEstimated TimeLeft)) {
    my $friendly = lc join ' ', split /(?<=[a-z])(?=[A-Z])/, $field;
    push @STATISTICS, (
        "ALL($field)" => ["Summary of $friendly",   'TimeAll',     $field ],
        "SUM($field)" => ["Total $friendly",   'Time', 'SUM', $field ],
        "AVG($field)" => ["Average $friendly", 'Time', 'AVG', $field ],
        "MIN($field)" => ["Minimum $friendly", 'Time', 'MIN', $field ],
        "MAX($field)" => ["Maximum $friendly", 'Time', 'MAX', $field ],
    );
}


foreach my $pair (
    'Created to Started',
    'Created to Resolved',
    'Created to LastUpdated',
    'Starts to Started',
    'Due to Resolved',
    'Started to Resolved',
) {
    my ($from, $to) = split / to /, $pair;
    push @STATISTICS, (
        "ALL($pair)" => ["Summary of $pair", 'DateTimeIntervalAll', $from, $to ],
        "SUM($pair)" => ["Total $pair", 'DateTimeInterval', 'SUM', $from, $to ],
        "AVG($pair)" => ["Average $pair", 'DateTimeInterval', 'AVG', $from, $to ],
        "MIN($pair)" => ["Minimum $pair", 'DateTimeInterval', 'MIN', $from, $to ],
        "MAX($pair)" => ["Maximum $pair", 'DateTimeInterval', 'MAX', $from, $to ],
    );
    push @GROUPINGS, $pair => 'Duration';

    my %extra_info = ( business_time => 1 );
    if ( keys %{RT->Config->Get('ServiceBusinessHours')} ) {
        my $business_pair = "$pair(Business Hours)";
        push @STATISTICS, (
            "ALL($business_pair)" => ["Summary of $business_pair", 'DateTimeIntervalAll', $from, $to, \%extra_info ],
            "SUM($business_pair)" => ["Total $business_pair", 'DateTimeInterval', 'SUM', $from, $to, \%extra_info ],
            "AVG($business_pair)" => ["Average $business_pair", 'DateTimeInterval', 'AVG', $from, $to, \%extra_info ],
            "MIN($business_pair)" => ["Minimum $business_pair", 'DateTimeInterval', 'MIN', $from, $to, \%extra_info ],
            "MAX($business_pair)" => ["Maximum $business_pair", 'DateTimeInterval', 'MAX', $from, $to, \%extra_info ],
        );
        push @GROUPINGS, $business_pair => 'DurationInBusinessHours';
    }
}

sub SetupGroupings {
    my $self = shift;
    my %args = (
        Query => undef,
        GroupBy => undef,
        Function => undef,
        @_
    );

    $self->FromSQL( $args{'Query'} ) if $args{'Query'};

    # Apply ACL checks
    $self->CurrentUserCanSee if RT->Config->Get('UseSQLForACLChecks');

    # See if our query is distinct
    if (not $self->{'joins_are_distinct'} and $self->_isJoined) {
        # If it isn't, we need to do this in two stages -- first, find
        # the distinct matching tickets (with no group by), then search
        # within the matching tickets grouped by what is wanted.
        $self->Columns( 'id' );
        if ( RT->Config->Get('UseSQLForACLChecks') ) {
            my $query = $self->BuildSelectQuery( PreferBind => 0 );
            $self->CleanSlate;
            $self->Limit( FIELD => 'Id', OPERATOR => 'IN', VALUE => "($query)", QUOTEVALUE => 0 );
        }
        else {
            # ACL is done in Next call
            my @match = (0);
            while ( my $row = $self->Next ) {
                push @match, $row->id;
            }

            # Replace the query with one that matches precisely those
            # tickets, with no joins.  We then mark it as having been ACL'd,
            # since it was by dint of being in the search results above
            $self->CleanSlate;
            while ( @match > 1000 ) {
                my @batch = splice( @match, 0, 1000 );
                $self->Limit( FIELD => 'Id', OPERATOR => 'IN', VALUE => \@batch );
            }
            $self->Limit( FIELD => 'Id', OPERATOR => 'IN', VALUE => \@match );
        }
        $self->{'_sql_current_user_can_see_applied'} = 1
    }

    my %res = $self->SUPER::SetupGroupings(%args);

    if ($args{Query}
        && ( grep( { $_->{INFO} =~ /Duration|CustomDateRange/ } map { $self->{column_info}{$_} } @{ $res{Groups} } )
            || grep( { $_->{TYPE} eq 'statistic' && ref $_->{INFO} && $_->{INFO}[1] =~ /CustomDateRange/ }
                values %{ $self->{column_info} } )
            || grep( { $_->{TYPE} eq 'statistic' && ref $_->{INFO} && ref $_->{INFO}[-1] && $_->{INFO}[-1]{business_time} }
                values %{ $self->{column_info} } ) )
       )
    {
        # Need to do the groupby/calculation at Perl level
        $self->{_query} = $args{'Query'};
    }
    else {
        delete $self->{_query};
    }

    return %res;
}

=head2 _DoSearch

Subclass _DoSearch from our parent so we can go through and add in empty
columns if it makes sense.

Besides it, for cases where GroupBy/Calculation couldn't be implemented via
SQL, we have to implement it in Perl, like business hours, time duration,
custom date ranges, etc.

=cut

sub _DoSearch {
    my $self = shift;

    # When groupby/calculation can't be done at SQL level, do it at Perl level
    if ( $self->{_query} ) {
        my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->FromSQL( $self->{_query} );
        my @groups = grep { $_->{TYPE} eq 'grouping' } map { $self->ColumnInfo($_) } $self->ColumnsList;
        my %info;

        my %bh_class = map { $_ => 'business_hours_' . HTML::Mason::Commands::CSSClass( lc $_ ) }
            keys %{ RT->Config->Get('ServiceBusinessHours') || {} };

        while ( my $ticket = $tickets->Next ) {
            my $bh = $ticket->SLA ? RT->Config->Get('ServiceAgreements')->{Levels}{ $ticket->SLA }{BusinessHours} : '';

            my @keys;
            my @extra_keys;
            my %css_class;
            for my $group ( @groups ) {
                my $value;

                if ( $ticket->_Accessible($group->{KEY}, 'read' )) {
                    if ( $group->{SUBKEY} ) {
                        my $method = "$group->{KEY}Obj";
                        if ( my $obj = $ticket->$method ) {
                            if ( $group->{INFO} eq 'Date' ) {
                                if ( $obj->Unix > 0 ) {
                                    $value = $obj->Strftime( $self->_GroupingsMeta()->{Date}{StrftimeFormat}{ $group->{SUBKEY} },
                                        Timezone => 'user' );
                                }
                                else {
                                    $value = $self->loc('(no value)')
                                }
                            }
                            else {
                                $value = $obj->_Value($group->{SUBKEY});
                            }
                            $value //= $self->loc('(no value)');
                        }
                    }
                    $value //= $ticket->_Value( $group->{KEY} ) // $self->loc('(no value)');
                }
                elsif ( $group->{INFO} eq 'Watcher' ) {
                    my @values;
                    if ( $ticket->can($group->{KEY}) ) {
                        my $method = $group->{KEY};
                        push @values, map { $_->MemberId } @{$ticket->$method->MembersObj->ItemsArrayRef};
                    }
                    elsif ( $group->{KEY} eq 'Watcher' ) {
                        push @values, map { $_->MemberId } @{$ticket->$_->MembersObj->ItemsArrayRef} for /Requestor Cc AdminCc/;
                    }
                    else {
                        RT->Logger->error("Unsupported group by $group->{KEY}");
                        next;
                    }

                    @values = $self->loc('(no value)') unless @values;
                    $value = \@values;
                }
                elsif ( $group->{INFO} eq 'CustomField' ) {
                    my ($id) = $group->{SUBKEY} =~ /{(\d+)}/;
                    my $values = $ticket->CustomFieldValues($id);
                    if ( $values->Count ) {
                        $value = [ map { $_->Content } @{ $values->ItemsArrayRef } ];
                    }
                    else {
                        $value = $self->loc('(no value)');
                    }
                }
                elsif ( $group->{INFO} =~ /^Duration(InBusinessHours)?/ ) {
                    my $business_time = $1;

                    if ( $group->{FIELD} =~ /^(\w+) to (\w+)(\(Business Hours\))?$/ ) {
                        my $start        = $1;
                        my $end          = $2;
                        my $start_method = $start . 'Obj';
                        my $end_method   = $end . 'Obj';
                        if ( $ticket->$end_method->Unix > 0 && $ticket->$start_method->Unix > 0 ) {
                            my $seconds;

                            if ($business_time) {
                                $seconds = $ticket->CustomDateRange(
                                    '',
                                    {   value         => "$end - $start",
                                        business_time => 1,
                                        format        => sub { $_[0] },
                                    }
                                );
                            }
                            else {
                                $seconds = $ticket->$end_method->Unix - $ticket->$start_method->Unix;
                            }

                            if ( $group->{SUBKEY} eq 'Default' ) {
                                $value = RT::Date->new( $self->CurrentUser )->DurationAsString(
                                    $seconds,
                                    Show    => $group->{META}{Show},
                                    Short   => $group->{META}{Short},
                                    MaxUnit => $business_time ? 'hour' : 'year',
                                );
                            }
                            else {
                                $value = RT::Date->new( $self->CurrentUser )->DurationAsString(
                                    $seconds,
                                    Show    => $group->{META}{Show} // 3,
                                    Short   => $group->{META}{Short} // 1,
                                    MaxUnit => lc $group->{SUBKEY},
                                    MinUnit => lc $group->{SUBKEY},
                                    Unit    => lc $group->{SUBKEY},
                                );
                            }
                        }

                        if ( $business_time ) {
                            push @extra_keys, join ' => ', $group->{FIELD}, $bh_class{$bh} || 'business_hours_none';
                        }
                    }
                    else {
                        my %ranges = RT::Ticket->CustomDateRanges;
                        if ( my $spec = $ranges{$group->{FIELD}} ) {
                            if ( $group->{SUBKEY} eq 'Default' ) {
                                $value = $ticket->CustomDateRange( $group->{FIELD}, $spec );
                            }
                            else {
                                my $seconds = $ticket->CustomDateRange( $group->{FIELD},
                                    { ref $spec ? %$spec : ( value => $spec ), format => sub { $_[0] } } );

                                if ( defined $seconds ) {
                                    $value = RT::Date->new( $self->CurrentUser )->DurationAsString(
                                        $seconds,
                                        Show    => $group->{META}{Show} // 3,
                                        Short   => $group->{META}{Short} // 1,
                                        MaxUnit => lc $group->{SUBKEY},
                                        MinUnit => lc $group->{SUBKEY},
                                        Unit    => lc $group->{SUBKEY},
                                    );
                                }
                            }
                            if ( ref $spec && $spec->{business_time} ) {
                                # 1 means the corresponding one in SLA, which $bh already holds
                                $bh = $spec->{business_time} unless $spec->{business_time} eq '1';
                                push @extra_keys, join ' => ', $group->{FIELD}, $bh_class{$bh} || 'business_hours_none';
                            }
                        }
                    }

                    $value //= $self->loc('(no value)');
                }
                else {
                    RT->Logger->error("Unsupported group by $group->{KEY}");
                    next;
                }
                push @keys, $value;
            }
            push @keys, @extra_keys;

            # @keys could contain arrayrefs, so we need to expand it.
            # e.g. "open", [ "root", "foo" ], "General" )
            # will be expanded to:
            #   "open", "root", "General"
            #   "open", "foo", "General"

            my @all_keys;
            for my $key (@keys) {
                if ( ref $key eq 'ARRAY' ) {
                    if (@all_keys) {
                        my @new_all_keys;
                        for my $keys ( @all_keys ) {
                            push @new_all_keys, [ @$keys, $_ ] for @$key;
                        }
                        @all_keys = @new_all_keys;
                    }
                    else {
                        push @all_keys, [$_] for @$key;
                    }
                }
                else {
                    if (@all_keys) {
                        @all_keys = map { [ @$_, $key ] } @all_keys;
                    }
                    else {
                        push @all_keys, [$key];
                    }
                }
            }

            my @fields = grep { $_->{TYPE} eq 'statistic' }
                map { $self->ColumnInfo($_) } $self->ColumnsList;

            while ( my $field = shift @fields ) {
                for my $keys (@all_keys) {
                    my $key = join ';;;', @$keys;
                    if ( $field->{NAME} =~ /^id/ && $field->{FUNCTION} eq 'COUNT' ) {
                        $info{$key}{ $field->{NAME} }++;
                    }
                    elsif ( $field->{NAME} =~ /^postfunction/ ) {
                        if ( $field->{MAP} ) {
                            my ($meta_type) = $field->{INFO}[1] =~ /^(\w+)All$/;
                            for my $item ( values %{ $field->{MAP} } ) {
                                push @fields,
                                    {
                                    NAME  => $item->{NAME},
                                    FIELD => $item->{FIELD},
                                    INFO  => [
                                        '', $meta_type,
                                        $item->{FUNCTION} =~ /^(\w+)/ ? $1 : '',
                                        @{ $field->{INFO} }[ 2 .. $#{ $field->{INFO} } ],
                                    ],
                                    };
                            }
                        }
                    }
                    elsif ( $field->{INFO}[1] eq 'Time' ) {
                        if ( $field->{NAME} =~ /^(TimeWorked|TimeEstimated|TimeLeft)$/ ) {
                            my $method = $1;
                            my $type   = $field->{INFO}[2];
                            my $name   = lc $field->{NAME};

                            $info{$key}{$name}
                                = $self->_CalculateTime( $type, $ticket->$method * 60, $info{$key}{$name} ) || 0;
                        }
                        else {
                            RT->Logger->error("Unsupported field $field->{NAME}");
                        }
                    }
                    elsif ( $field->{INFO}[1] eq 'DateTimeInterval' ) {
                        my ( undef, undef, $type, $start, $end, $extra_info ) = @{ $field->{INFO} };
                        my $name = lc $field->{NAME};
                        $info{$key}{$name} ||= 0;

                        my $start_method = $start . 'Obj';
                        my $end_method   = $end . 'Obj';
                        next unless $ticket->$end_method->Unix > 0 && $ticket->$start_method->Unix > 0;

                        my $value;
                        if ($extra_info->{business_time}) {
                            $value = $ticket->CustomDateRange(
                                '',
                                {   value         => "$end - $start",
                                    business_time => $extra_info->{business_time},
                                    format        => sub { return $_[0] },
                                }
                            );
                        }
                        else {
                            $value = $ticket->$end_method->Unix - $ticket->$start_method->Unix;
                        }

                        $info{$key}{$name} = $self->_CalculateTime( $type, $value, $info{$key}{$name} );
                    }
                    elsif ( $field->{INFO}[1] eq 'CustomDateRange' ) {
                        my ( undef, undef, $type, $range_name ) = @{ $field->{INFO} };
                        my $name = lc $field->{NAME};
                        $info{$key}{$name} ||= 0;

                        my $value;
                        my %ranges = RT::Ticket->CustomDateRanges;
                        if ( my $spec = $ranges{$range_name} ) {
                            $value = $ticket->CustomDateRange(
                                $range_name,
                                {
                                    ref $spec eq 'HASH' ? %$spec : ( value => $spec ),
                                    format => sub { $_[0] },
                                }
                            );
                        }
                        $info{$key}{$name} = $self->_CalculateTime( $type, $value, $info{$key}{$name} );
                    }
                    else {
                        RT->Logger->error("Unsupported field $field->{INFO}[1]");
                    }
                }
            }

            for my $keys (@all_keys) {
                my $key = join ';;;', @$keys;
                push @{ $info{$key}{ids} }, $ticket->id;
            }
        }

        # Make generated results real SB results
        for my $key ( keys %info ) {
            my @keys = split /;;;/, $key;
            my $row;
            for my $group ( @groups ) {
                $row->{lc $group->{NAME}} = shift @keys;
            }
            for my $field ( keys %{ $info{$key} } ) {
                my $value = $info{$key}{$field};
                if ( ref $value eq 'HASH' && $value->{calculate} ) {
                    $row->{$field} = $value->{calculate}->($value);
                }
                else {
                    $row->{$field} = $info{$key}{$field};
                }
            }
            my $item = $self->NewItem();

            # Has extra css info
            for my $key (@keys) {
                if ( $key =~ /(.+) => (.+)/ ) {
                    $row->{_css_class}{$1} = $2;
                }
            }

            $item->LoadFromHash($row);
            $self->AddRecord($item);
        }
        $self->{must_redo_search} = 0;
        $self->{is_limited} = 1;
        $self->PostProcessRecords;

        return;
    }

    $self->SUPER::_DoSearch( @_ );
    $self->_PostSearch();
}

# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub new {
    my $self = shift;
    $self->_SetupCustomDateRanges;
    return $self->SUPER::new(@_);
}

RT::Base->_ImportOverlays();

1;
