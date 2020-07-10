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

package RT::Report::Tickets;

use base qw/RT::Tickets/;
use RT::Report::Tickets::Entry;

use strict;
use warnings;
use 5.010;
use Scalar::Util qw(weaken);

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
our %GROUPINGS;

our %GROUPINGS_META = (
    Queue => {
        Display => sub {
            my $self = shift;
            my %args = (@_);

            my $queue = RT::Queue->new( $self->CurrentUser );
            $queue->Load( $args{'VALUE'} );
            return $queue->Name;
        },
        Localize => 1,
    },
    Priority => {
        Sort => 'numeric raw',
    },
    User => {
        SubFields => [grep RT::User->_Accessible($_, "public"), qw(
            Name RealName NickName
            EmailAddress
            Organization
            Lang City Country Timezone
        )],
        Function => 'GenerateUserFunction',
    },
    Watcher => {
        SubFields => [grep RT::User->_Accessible($_, "public"), qw(
            Name RealName NickName
            EmailAddress
            Organization
            Lang City Country Timezone
        )],
        Function => 'GenerateWatcherFunction',
    },
    Date => {
        SubFields => [qw(
            Time
            Hourly Hour
            Date Daily
            DayOfWeek Day DayOfMonth DayOfYear
            Month Monthly
            Year Annually
            WeekOfYear
        )],  # loc_qw
        StrftimeFormat => {
            Time       => '%T',
            Hourly     => '%Y-%m-%d %H',
            Hour       => '%H',
            Date       => '%F',
            Daily      => '%F',
            DayOfWeek  => '%w',
            Day        => '%F',
            DayOfMonth => '%d',
            DayOfYear  => '%j',
            Month      => '%m',
            Monthly    => '%Y-%m',
            Year       => '%Y',
            Annually   => '%Y',
            WeekOfYear => '%W',
        },
        Function => 'GenerateDateFunction',
        Display => sub {
            my $self = shift;
            my %args = (@_);

            my $raw = $args{'VALUE'};
            return $raw unless defined $raw;

            if ( $args{'SUBKEY'} eq 'DayOfWeek' ) {
                return $self->loc($RT::Date::DAYS_OF_WEEK[ int $raw ]);
            }
            elsif ( $args{'SUBKEY'} eq 'Month' ) {
                return $self->loc($RT::Date::MONTHS[ int($raw) - 1 ]);
            }
            return $raw;
        },
        Sort => 'raw',
    },
    CustomField => {
        SubFields => sub {
            my $self = shift;
            my $args = shift;


            my $queues = $args->{'Queues'};
            if ( !$queues && $args->{'Query'} ) {
                require RT::Interface::Web::QueryBuilder::Tree;
                my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
                $tree->ParseSQL( Query => $args->{'Query'}, CurrentUser => $self->CurrentUser );
                $queues = $args->{'Queues'} = $tree->GetReferencedQueues( CurrentUser => $self->CurrentUser );
            }
            return () unless $queues;

            my @res;

            my $CustomFields = RT::CustomFields->new( $self->CurrentUser );
            foreach my $id (keys %$queues) {
                my $queue = RT::Queue->new( $self->CurrentUser );
                $queue->Load($id);
                next unless $queue->id;

                $CustomFields->LimitToQueue($queue->id);
            }
            $CustomFields->LimitToGlobal;
            while ( my $CustomField = $CustomFields->Next ) {
                push @res, ["Custom field", $CustomField->Name], "CF.{". $CustomField->id ."}";
            }
            return @res;
        },
        Function => 'GenerateCustomFieldFunction',
        Label => sub {
            my $self = shift;
            my %args = (@_);

            my ($cf) = ( $args{'SUBKEY'} =~ /^\{(.*)\}$/ );
            if ( $cf =~ /^\d+$/ ) {
                my $obj = RT::CustomField->new( $self->CurrentUser );
                $obj->Load( $cf );
                $cf = $obj->Name;
            }

            return 'Custom field [_1]', $cf;
        },
    },
    Enum => {
        Localize => 1,
    },
    Duration => {
        SubFields => [ qw/Default Hour Day Week Month Year/ ],
        Localize => 1,
        Short    => 0,
        Show     => 1,
        Sort     => 'duration',
    },
    DurationInBusinessHours => {
        SubFields => [ qw/Default Hour/ ],
        Localize => 1,
        Short    => 0,
        Show     => 1,
        Sort     => 'duration',
    },
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

our %STATISTICS;

our %STATISTICS_META = (
    Count => {
        Function => sub {
            my $self = shift;
            my $field = shift || 'id';

            return (
                FUNCTION => 'COUNT',
                FIELD    => 'id'
            );
        },
    },
    Simple => {
        Function => sub {
            my $self = shift;
            my ($function, $field) = @_;
            return (FUNCTION => $function, FIELD => $field);
        },
    },
    Time => {
        Function => sub {
            my $self = shift;
            my ($function, $field) = @_;
            return (FUNCTION => "$function(?)*60", FIELD => $field);
        },
        Display => 'DurationAsString',
    },
    TimeAll => {
        SubValues => sub { return ('Minimum', 'Average', 'Maximum', 'Total') },
        Function => sub {
            my $self = shift;
            my $field = shift;
            return (
                Minimum => { FUNCTION => "MIN(?)*60", FIELD => $field },
                Average => { FUNCTION => "AVG(?)*60", FIELD => $field },
                Maximum => { FUNCTION => "MAX(?)*60", FIELD => $field },
                Total   => { FUNCTION => "SUM(?)*60", FIELD => $field },
            );
        },
        Display => 'DurationAsString',
    },
    DateTimeInterval => {
        Function => sub {
            my $self = shift;
            my ($function, $from, $to) = @_;

            my $interval = $self->_Handle->DateTimeIntervalFunction(
                From => { FUNCTION => $self->NotSetDateToNullFunction( FIELD => $from ) },
                To   => { FUNCTION => $self->NotSetDateToNullFunction( FIELD => $to ) },
            );

            return (FUNCTION => "$function($interval)");
        },
        Display => 'DurationAsString',
    },
    DateTimeIntervalAll => {
        SubValues => sub { return ('Minimum', 'Average', 'Maximum', 'Total') },
        Function => sub {
            my $self = shift;
            my ($from, $to) = @_;

            my $interval = $self->_Handle->DateTimeIntervalFunction(
                From => { FUNCTION => $self->NotSetDateToNullFunction( FIELD => $from ) },
                To   => { FUNCTION => $self->NotSetDateToNullFunction( FIELD => $to ) },
            );

            return (
                Minimum => { FUNCTION => "MIN($interval)" },
                Average => { FUNCTION => "AVG($interval)" },
                Maximum => { FUNCTION => "MAX($interval)" },
                Total   => { FUNCTION => "SUM($interval)" },
            );
        },
        Display => 'DurationAsString',
    },
    CustomDateRange => {
        Display => 'DurationAsString',
        Function => sub {}, # Placeholder to use the same DateTimeInterval handling
    },
    CustomDateRangeAll => {
        SubValues => sub { return ('Minimum', 'Average', 'Maximum', 'Total') },
        Function => sub {
            my $self = shift;

            # To use the same DateTimeIntervalAll handling, not real SQL
            return (
                Minimum => { FUNCTION => "MIN" },
                Average => { FUNCTION => "AVG" },
                Maximum => { FUNCTION => "MAX" },
                Total   => { FUNCTION => "SUM" },
            );
        },
        Display => 'DurationAsString',
    },
);

sub Groupings {
    my $self = shift;
    my %args = (@_);

    my @fields;

    my @tmp = @GROUPINGS;
    while ( my ($field, $type) = splice @tmp, 0, 2 ) {
        my $meta = $GROUPINGS_META{ $type } || {};
        unless ( $meta->{'SubFields'} ) {
            push @fields, [$field, $field], $field;
        }
        elsif ( ref( $meta->{'SubFields'} ) eq 'ARRAY' ) {
            push @fields, map { ([$field, $_], "$field.$_") } @{ $meta->{'SubFields'} };
        }
        elsif ( my $code = $self->FindImplementationCode( $meta->{'SubFields'} ) ) {
            push @fields, $code->( $self, \%args );
        }
        else {
            $RT::Logger->error(
                "$type has unsupported SubFields."
                ." Not an array, a method name or a code reference"
            );
        }
    }
    return @fields;
}

sub IsValidGrouping {
    my $self = shift;
    my %args = (@_);
    return 0 unless $args{'GroupBy'};

    my ($key, $subkey) = split /\./, $args{'GroupBy'}, 2;

    %GROUPINGS = @GROUPINGS unless keys %GROUPINGS;
    my $type = $GROUPINGS{$key};
    return 0 unless $type;
    return 1 unless $subkey;

    my $meta = $GROUPINGS_META{ $type } || {};
    unless ( $meta->{'SubFields'} ) {
        return 0;
    }
    elsif ( ref( $meta->{'SubFields'} ) eq 'ARRAY' ) {
        return 1 if grep $_ eq $subkey, @{ $meta->{'SubFields'} };
    }
    elsif ( my $code = $self->FindImplementationCode( $meta->{'SubFields'}, 'silent' ) ) {
        return 1 if grep $_ eq "$key.$subkey", $code->( $self, \%args );
    }
    return 0;
}

sub Statistics {
    my $self = shift;
    return map { ref($_)? $_->[0] : $_ } @STATISTICS;
}

sub Label {
    my $self = shift;
    my $column = shift;

    my $info = $self->ColumnInfo( $column );
    unless ( $info ) {
        $RT::Logger->error("Unknown column '$column'");
        return $self->CurrentUser->loc('(Incorrect data)');
    }

    if ( $info->{'META'}{'Label'} ) {
        my $code = $self->FindImplementationCode( $info->{'META'}{'Label'} );
        return $self->CurrentUser->loc( $code->( $self, %$info ) )
            if $code;
    }

    my $res = '';
    if ( $info->{'TYPE'} eq 'statistic' ) {
        $res = $info->{'INFO'}[0];
    }
    else {
        $res = join ' ', grep defined && length, @{ $info }{'KEY', 'SUBKEY'};
    }
    return $self->CurrentUser->loc( $res );
}

sub ColumnInfo {
    my $self = shift;
    my $column = shift;

    return $self->{'column_info'}{$column};
}

sub ColumnsList {
    my $self = shift;
    return sort { $self->{'column_info'}{$a}{'POSITION'} <=> $self->{'column_info'}{$b}{'POSITION'} }
        keys %{ $self->{'column_info'} || {} };
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
        my @match = (0);
        $self->Columns( 'id' );
        while (my $row = $self->Next) {
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
        $self->{'_sql_current_user_can_see_applied'} = 1
    }


    %GROUPINGS = @GROUPINGS unless keys %GROUPINGS;

    my $i = 0;

    my @group_by = grep defined && length,
        ref( $args{'GroupBy'} )? @{ $args{'GroupBy'} } : ($args{'GroupBy'});
    @group_by = ('Status') unless @group_by;

    foreach my $e ( splice @group_by ) {
        unless ($self->IsValidGrouping( Query => $args{Query}, GroupBy => $e )) {
            RT->Logger->error("'$e' is not a valid grouping for reports; skipping");
            next;
        }
        my ($key, $subkey) = split /\./, $e, 2;
        $e = { $self->_FieldToFunction( KEY => $key, SUBKEY => $subkey ) };
        $e->{'TYPE'} = 'grouping';
        $e->{'INFO'} = $GROUPINGS{ $key };
        $e->{'META'} = $GROUPINGS_META{ $e->{'INFO'} };
        $e->{'POSITION'} = $i++;
        push @group_by, $e;
    }
    $self->GroupBy( map { {
        ALIAS    => $_->{'ALIAS'},
        FIELD    => $_->{'FIELD'},
        FUNCTION => $_->{'FUNCTION'},
    } } @group_by );

    my %res = (Groups => [], Functions => []);
    my %column_info;

    foreach my $group_by ( @group_by ) {
        $group_by->{'NAME'} = $self->Column( %$group_by );
        $column_info{ $group_by->{'NAME'} } = $group_by;
        push @{ $res{'Groups'} }, $group_by->{'NAME'};
    }

    %STATISTICS = @STATISTICS unless keys %STATISTICS;

    my @function = grep defined && length,
        ref( $args{'Function'} )? @{ $args{'Function'} } : ($args{'Function'});
    push @function, 'COUNT' unless @function;
    foreach my $e ( @function ) {
        $e = {
            TYPE => 'statistic',
            KEY  => $e,
            INFO => $STATISTICS{ $e },
            META => $STATISTICS_META{ $STATISTICS{ $e }[1] },
            POSITION => $i++,
        };
        unless ( $e->{'INFO'} && $e->{'META'} ) {
            $RT::Logger->error("'". $e->{'KEY'} ."' is not valid statistic for report");
            $e->{'FUNCTION'} = 'NULL';
            $e->{'NAME'} = $self->Column( FUNCTION => 'NULL' );
        }
        elsif ( $e->{'META'}{'Function'} ) {
            my $code = $self->FindImplementationCode( $e->{'META'}{'Function'} );
            unless ( $code ) {
                $e->{'FUNCTION'} = 'NULL';
                $e->{'NAME'} = $self->Column( FUNCTION => 'NULL' );
            }
            elsif ( $e->{'META'}{'SubValues'} ) {
                my %tmp = $code->( $self, @{ $e->{INFO} }[2 .. $#{$e->{INFO}}] );
                $e->{'NAME'} = 'postfunction'. $self->{'postfunctions'}++;
                while ( my ($k, $v) = each %tmp ) {
                    $e->{'MAP'}{ $k }{'NAME'} = $self->Column( %$v );
                    @{ $e->{'MAP'}{ $k } }{'FUNCTION', 'ALIAS', 'FIELD'} =
                        @{ $v }{'FUNCTION', 'ALIAS', 'FIELD'};
                }
            }
            else {
                my %tmp = $code->( $self, @{ $e->{INFO} }[2 .. $#{$e->{INFO}}] );
                $e->{'NAME'} = $self->Column( %tmp );
                @{ $e }{'FUNCTION', 'ALIAS', 'FIELD'} = @tmp{'FUNCTION', 'ALIAS', 'FIELD'};
            }
        }
        elsif ( $e->{'META'}{'Calculate'} ) {
            $e->{'NAME'} = 'postfunction'. $self->{'postfunctions'}++;
        }
        push @{ $res{'Functions'} }, $e->{'NAME'};
        $column_info{ $e->{'NAME'} } = $e;
    }

    $self->{'column_info'} = \%column_info;

    if ($args{Query}
        && ( grep( { $_->{INFO} =~ /Duration|CustomDateRange/ } map { $column_info{$_} } @{ $res{Groups} } )
            || grep( { $_->{TYPE} eq 'statistic' && ref $_->{INFO} && $_->{INFO}[1] =~ /CustomDateRange/ }
                values %column_info )
            || grep( { $_->{TYPE} eq 'statistic' && ref $_->{INFO} && ref $_->{INFO}[-1] && $_->{INFO}[-1]{business_time} }
                values %column_info ) )
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
columns if it makes sense 

=cut

sub _DoSearch {
    my $self = shift;

    # When groupby/calculation can't be done at SQL level, do it at Perl level
    if ( $self->{_query} ) {
        my $tickets = RT::Tickets->new( $self->CurrentUser );
        $tickets->FromSQL( $self->{_query} );
        my @groups = grep { $_->{TYPE} eq 'grouping' } map { $self->ColumnInfo($_) } $self->ColumnsList;
        my %info;
        while ( my $ticket = $tickets->Next ) {
            my @keys;
            my $max = 1;
            for my $group ( @groups ) {
                my $value;

                if ( $ticket->_Accessible($group->{KEY}, 'read' )) {
                    if ( $group->{SUBKEY} ) {
                        my $method = "$group->{KEY}Obj";
                        if ( my $obj = $ticket->$method ) {
                            if ( $group->{INFO} eq 'Date' ) {
                                if ( $obj->Unix > 0 ) {
                                    $value = $obj->Strftime( $GROUPINGS_META{Date}{StrftimeFormat}{ $group->{SUBKEY} },
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
                        push @values, @{$ticket->$method->UserMembersObj->ItemsArrayRef};
                    }
                    elsif ( $group->{KEY} eq 'Watcher' ) {
                        push @values, @{$ticket->$_->UserMembersObj->ItemsArrayRef} for /Requestor Cc AdminCc/;
                    }
                    else {
                        RT->Logger->error("Unsupported group by $group->{KEY}");
                        next;
                    }

                    @values = map { $_->_Value( $group->{SUBKEY} || 'Name' ) } @values;
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
                                    business_time => 1,
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
            $item->LoadFromHash($row);
            $self->AddRecord($item);
        }
        $self->{must_redo_search} = 0;
        $self->{is_limited} = 1;
        $self->PostProcessRecords;

        return;
    }

    $self->SUPER::_DoSearch( @_ );
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call AddEmptyRows"
        );
    }
    else {
        $self->PostProcessRecords;
    }
}

=head2 _FieldToFunction FIELD

Returns a tuple of the field or a database function to allow grouping on that 
field.

=cut

sub _FieldToFunction {
    my $self = shift;
    my %args = (@_);

    $args{'FIELD'} ||= $args{'KEY'};

    my $meta = $GROUPINGS_META{ $GROUPINGS{ $args{'KEY'} } };
    return ('FUNCTION' => 'NULL') unless $meta;

    return %args unless $meta->{'Function'};

    my $code = $self->FindImplementationCode( $meta->{'Function'} );
    return ('FUNCTION' => 'NULL') unless $code;

    return $code->( $self, %args );
}


# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    my $res = RT::Report::Tickets::Entry->new($self->CurrentUser);
    $res->{'report'} = $self;
    weaken $res->{'report'};
    return $res;
}

# This is necessary since normally NewItem (above) is used to intuit the
# correct class.  However, since we're abusing a subclass, it's incorrect.
sub _RoleGroupClass { "RT::Ticket" }
sub _SingularClass { "RT::Report::Tickets::Entry" }

sub SortEntries {
    my $self = shift;

    $self->_DoSearch if $self->{'must_redo_search'};
    return unless $self->{'items'} && @{ $self->{'items'} };

    my @groups =
        grep $_->{'TYPE'} eq 'grouping',
        map $self->ColumnInfo($_),
        $self->ColumnsList;
    return unless @groups;

    my @SORT_OPS;
    my $by_multiple = sub ($$) {
        for my $f ( @SORT_OPS ) {
            my $r = $f->($_[0], $_[1]);
            return $r if $r;
        }
    };
    my @data = map [$_], @{ $self->{'items'} };

    for ( my $i = 0; $i < @groups; $i++ ) {
        my $group_by = $groups[$i];
        my $idx = $i+1;

        my $order = $group_by->{'META'}{Sort} || 'label';
        my $method = $order =~ /label$/ ? 'LabelValue' : 'RawValue';

        unless ($order =~ /^numeric/) {
            # Traverse the values being used for labels.
            # If they all look like numbers or undef, flag for a numeric sort.
            my $looks_like_number = 1;
            foreach my $item (@data){
                my $label = $item->[0]->$method($group_by->{'NAME'});

                $looks_like_number = 0
                    unless (not defined $label)
                    or Scalar::Util::looks_like_number( $label );
            }
            $order = "numeric $order" if $looks_like_number;
        }

        if ( $order eq 'label' ) {
            push @SORT_OPS, sub { $_[0][$idx] cmp $_[1][$idx] };
            $method = 'LabelValue';
        }
        elsif ( $order eq 'numeric label' ) {
            my $nv = $self->loc("(no value)");
            # Sort the (no value) elements first, by comparing for them
            # first, and falling back to a numeric sort on all other
            # values.
            push @SORT_OPS, sub {
                (($_[0][$idx] ne $nv) <=> ($_[1][$idx] ne $nv))
             || ( $_[0][$idx]         <=>  $_[1][$idx]        ) };
            $method = 'LabelValue';
        }
        elsif ( $order eq 'raw' ) {
            push @SORT_OPS, sub { ($_[0][$idx]//'') cmp ($_[1][$idx]//'') };
            $method = 'RawValue';
        }
        elsif ( $order eq 'numeric raw' ) {
            push @SORT_OPS, sub { $_[0][$idx] <=> $_[1][$idx] };
            $method = 'RawValue';
        }
        elsif ( $order eq 'duration' ) {
            push @SORT_OPS, sub { $_[0][$idx] <=> $_[1][$idx] };
            $method = 'DurationValue';
        } else {
            $RT::Logger->error("Unknown sorting function '$order'");
            next;
        }
        $_->[$idx] = $_->[0]->$method( $group_by->{'NAME'} ) for @data;
    }
    $self->{'items'} = [
        map $_->[0],
        sort $by_multiple @data
    ];
}

sub PostProcessRecords {
    my $self = shift;

    my $info = $self->{'column_info'};
    foreach my $column ( values %$info ) {
        next unless $column->{'TYPE'} eq 'statistic';
        if ( $column->{'META'}{'Calculate'} ) {
            $self->CalculatePostFunction( $column );
        }
        elsif ( $column->{'META'}{'SubValues'} ) {
            $self->MapSubValues( $column );
        }
    }
}

sub CalculatePostFunction {
    my $self = shift;
    my $info = shift;

    my $code = $self->FindImplementationCode( $info->{'META'}{'Calculate'} );
    unless ( $code ) {
        # TODO: fill in undefs
        return;
    }

    my $column = $info->{'NAME'};

    my $base_query = $self->Query;
    foreach my $item ( @{ $self->{'items'} } ) {
        $item->{'values'}{ lc $column } = $code->(
            $self,
            Query => join(
                ' AND ', map "($_)", grep defined && length, $base_query, $item->Query,
            ),
        );
        $item->{'fetched'}{ lc $column } = 1;
    }
}

sub MapSubValues {
    my $self = shift;
    my $info = shift;

    my $to = $info->{'NAME'};
    my $map = $info->{'MAP'};

    foreach my $item ( @{ $self->{'items'} } ) {
        my $dst = $item->{'values'}{ lc $to } = { };
        while (my ($k, $v) = each %{ $map } ) {
            $dst->{ $k } = delete $item->{'values'}{ lc $v->{'NAME'} };
            # This mirrors the logic in RT::Record::__Value When that
            # ceases tp use the UTF-8 flag as a character/byte
            # distinction from the database, this can as well.
            utf8::decode( $dst->{ $k } )
                if defined $dst->{ $k }
               and not utf8::is_utf8( $dst->{ $k } );
            delete $item->{'fetched'}{ lc $v->{'NAME'} };
        }
        $item->{'fetched'}{ lc $to } = 1;
    }
}

sub GenerateDateFunction {
    my $self = shift;
    my %args = @_;

    my $tz;
    if ( RT->Config->Get('ChartsTimezonesInDB') ) {
        my $to = $self->CurrentUser->UserObj->Timezone
            || RT->Config->Get('Timezone');
        $tz = { From => 'UTC', To => $to }
            if $to && lc $to ne 'utc';
    }

    $args{'FUNCTION'} = $RT::Handle->DateTimeFunction(
        Type     => $args{'SUBKEY'},
        Field    => $self->NotSetDateToNullFunction,
        Timezone => $tz,
    );
    return %args;
}

sub GenerateCustomFieldFunction {
    my $self = shift;
    my %args = @_;

    my ($name) = ( $args{'SUBKEY'} =~ /^\{(.*)\}$/ );
    my $cf = RT::CustomField->new( $self->CurrentUser );
    $cf->Load($name);
    unless ( $cf->id ) {
        $RT::Logger->error("Couldn't load CustomField #$name");
        @args{qw(FUNCTION FIELD)} = ('NULL', undef);
    } else {
        my ($ticket_cf_alias, $cf_alias) = $self->_CustomFieldJoin($cf->id, $cf);
        @args{qw(ALIAS FIELD)} = ($ticket_cf_alias, 'Content');
    }
    return %args;
}

sub GenerateUserFunction {
    my $self = shift;
    my %args = @_;

    my $column = $args{'SUBKEY'} || 'Name';
    my $u_alias = $self->{"_sql_report_$args{FIELD}_users_$column"}
        ||= $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => $args{'FIELD'},
            TABLE2 => 'Users',
            FIELD2 => 'id',
        );
    @args{qw(ALIAS FIELD)} = ($u_alias, $column);
    return %args;
}

sub GenerateWatcherFunction {
    my $self = shift;
    my %args = @_;

    my $type = $args{'FIELD'};
    $type = '' if $type eq 'Watcher';

    my $column = $args{'SUBKEY'} || 'Name';

    my $u_alias = $self->{"_sql_report_watcher_users_alias_$type"};
    unless ( $u_alias ) {
        my ($g_alias, $gm_alias);
        ($g_alias, $gm_alias, $u_alias) = $self->_WatcherJoin( Name => $type );
        $self->{"_sql_report_watcher_users_alias_$type"} = $u_alias;
    }
    @args{qw(ALIAS FIELD)} = ($u_alias, $column);

    return %args;
}

sub DurationAsString {
    my $self = shift;
    my %args = @_;
    my $v = $args{'VALUE'};
    my $max_unit = $args{INFO} && ref $args{INFO}[-1] && $args{INFO}[-1]{business_time} ? 'hour' : 'year';

    unless ( ref $v ) {
        return $self->loc("(no value)") unless defined $v && length $v;
        return RT::Date->new( $self->CurrentUser )->DurationAsString(
            $v, Show => 3, Short => 1, MaxUnit => $max_unit,
        );
    }

    my $date = RT::Date->new( $self->CurrentUser );
    my %res = %$v;
    foreach my $e ( values %res ) {
        $e = $date->DurationAsString( $e, Short => 1, Show => 3, MaxUnit => $max_unit )
            if defined $e && length $e;
        $e = $self->loc("(no value)") unless defined $e && length $e;
    }
    return \%res;
}

sub LabelValueCode {
    my $self = shift;
    my $name = shift;

    my $display = $self->ColumnInfo( $name )->{'META'}{'Display'};
    return undef unless $display;
    return $self->FindImplementationCode( $display );
}


sub FindImplementationCode {
    my $self = shift;
    my $value = shift;
    my $silent = shift;

    my $code;
    unless ( $value ) {
        $RT::Logger->error("Value is not defined. Should be method name or code reference")
            unless $silent;
        return undef;
    }
    elsif ( !ref $value ) {
        $code = $self->can( $value );
        unless ( $code ) {
            $RT::Logger->error("No method $value in ". (ref $self || $self) ." class" )
                unless $silent;
            return undef;
        }
    }
    elsif ( ref( $value ) eq 'CODE' ) {
        $code = $value;
    }
    else {
        $RT::Logger->error("$value is not method name or code reference")
            unless $silent;
        return undef;
    }
    return $code;
}

sub Serialize {
    my $self = shift;

    my %clone = %$self;
# current user, handle and column_info
    delete @clone{'user', 'DBIxHandle', 'column_info'};
    $clone{'items'} = [ map $_->{'values'}, @{ $clone{'items'} || [] } ];
    $clone{'column_info'} = {};
    while ( my ($k, $v) = each %{ $self->{'column_info'} } ) {
        $clone{'column_info'}{$k} = { %$v };
        delete $clone{'column_info'}{$k}{'META'};
    }
    return \%clone;
}

sub Deserialize {
    my $self = shift;
    my $data = shift;

    $self->CleanSlate;
    %$self = (%$self, %$data);

    $self->{'items'} = [
        map { my $r = $self->NewItem; $r->LoadFromHash( $_ ); $r }
        @{ $self->{'items'} }
    ];
    foreach my $e ( values %{ $self->{column_info} } ) {
        $e->{'META'} = $e->{'TYPE'} eq 'grouping'
            ? $GROUPINGS_META{ $e->{'INFO'} }
            : $STATISTICS_META{ $e->{'INFO'}[1] }
    }
}


sub FormatTable {
    my $self = shift;
    my %columns = @_;

    my (@head, @body, @footer);

    @head = ({ cells => []});
    foreach my $column ( @{ $columns{'Groups'} } ) {
        push @{ $head[0]{'cells'} }, { type => 'head', value => $self->Label( $column ) };
    }

    my $i = 0;
    while ( my $entry = $self->Next ) {
        $body[ $i ] = { even => ($i+1)%2, cells => [] };
        $i++;
    }
    @footer = ({ even => ++$i%2, cells => []});

    my $g = 0;
    foreach my $column ( @{ $columns{'Groups'} } ) {
        $i = 0;
        my $last;
        while ( my $entry = $self->Next ) {
            my $value = $entry->LabelValue( $column );
            if ( !$last || $last->{'value'} ne $value ) {
                push @{ $body[ $i++ ]{'cells'} }, $last = { type => 'label', value => $value };
                $last->{even} = $g++ % 2
                    unless $column eq $columns{'Groups'}[-1];
            }
            else {
                $i++;
                $last->{rowspan} = ($last->{rowspan}||1) + 1;
            }
        }
    }
    push @{ $footer[0]{'cells'} }, {
        type => 'label',
        value => $self->loc('Total'),
        colspan => scalar @{ $columns{'Groups'} },
    };

    my $pick_color = do {
        my @colors = RT->Config->Get("ChartColors");
        sub { $colors[ $_[0] % @colors - 1 ] }
    };

    my $function_count = 0;
    foreach my $column ( @{ $columns{'Functions'} } ) {
        $i = 0;

        my $info = $self->ColumnInfo( $column );

        my @subs = ('');
        if ( $info->{'META'}{'SubValues'} ) {
            @subs = $self->FindImplementationCode( $info->{'META'}{'SubValues'} )->(
                $self
            );
        }

        my %total;
        unless ( $info->{'META'}{'NoTotals'} ) {
            while ( my $entry = $self->Next ) {
                my $raw = $entry->RawValue( $column ) || {};
                $raw = { '' => $raw } unless ref $raw;
                $total{ $_ } += $raw->{ $_ } foreach grep $raw->{$_}, @subs;
            }
            @subs = grep $total{$_}, @subs
                unless $info->{'META'}{'NoHideEmpty'};
        }

        my $label = $self->Label( $column );

        unless (@subs) {
            while ( my $entry = $self->Next ) {
                push @{ $body[ $i++ ]{'cells'} }, {
                    type => 'value',
                    value => undef,
                    query => $entry->Query,
                };
            }
            push @{ $head[0]{'cells'} }, {
                type => 'head',
                value => $label,
                rowspan => scalar @head,
                color => $pick_color->(++$function_count),
            };
            push @{ $footer[0]{'cells'} }, { type => 'value', value => undef };
            next;
        }

        if ( @subs > 1 && @head == 1 ) {
            $_->{rowspan} = 2 foreach @{ $head[0]{'cells'} };
        }

        if ( @subs == 1 ) {
            push @{ $head[0]{'cells'} }, {
                type => 'head',
                value => $label,
                rowspan => scalar @head,
                color => $pick_color->(++$function_count),
            };
        } else {
            push @{ $head[0]{'cells'} }, { type => 'head', value => $label, colspan => scalar @subs };
            push @{ $head[1]{'cells'} }, { type => 'head', value => $_, color => $pick_color->(++$function_count) }
                foreach @subs;
        }

        while ( my $entry = $self->Next ) {
            my $query = $entry->Query;
            my $value = $entry->LabelValue( $column ) || {};
            $value = { '' => $value } unless ref $value;
            foreach my $e ( @subs ) {
                push @{ $body[ $i ]{'cells'} }, {
                    type => 'value',
                    value => $value->{ $e },
                    query => $query,
                };
            }
            $i++;
        }

        unless ( $info->{'META'}{'NoTotals'} ) {
            my $total_code = $self->LabelValueCode( $column );
            foreach my $e ( @subs ) {
                my $total = $total{ $e };
                $total = $total_code->( $self, %$info, VALUE => $total )
                    if $total_code;
                push @{ $footer[0]{'cells'} }, { type => 'value', value => $total };
            }
        }
        else {
            foreach my $e ( @subs ) {
                push @{ $footer[0]{'cells'} }, { type => 'value', value => undef };
            }
        }
    }

    return thead => \@head, tbody => \@body, tfoot => \@footer;
}

sub _CalculateTime {
    my $self = shift;
    my ( $type, $value, $current ) = @_;

    return $current unless defined $value;

    if ( $type eq 'SUM' ) {
        $current += $value;
    }
    elsif ( $type eq 'AVG' ) {
        $current ||= {};
        $current->{total} += $value;
        $current->{count}++;
        $current->{calculate} ||= sub {
            my $item = shift;
            return sprintf '%.0f', $item->{total} / $item->{count};
        };
    }
    elsif ( $type eq 'MAX' ) {
        $current = $value unless $current && $current > $value;
    }
    elsif ( $type eq 'MIN' ) {
        $current = $value unless $current && $current < $value;
    }
    else {
        RT->Logger->error("Unsupported type $type");
    }
    return $current;
}

sub new {
    my $self = shift;
    $self->_SetupCustomDateRanges;
    return $self->SUPER::new(@_);
}


sub _SetupCustomDateRanges {
    my $self = shift;
    my %names;

    # Remove old custom date range groupings
    for my $field ( grep {ref} @STATISTICS ) {
        if ( $field->[1] && $field->[1] eq 'CustomDateRangeAll' ) {
            $names{ $field->[2] } = 1;
        }
    }

    my ( @new_groupings, @new_statistics );
    while (@GROUPINGS) {
        my $name = shift @GROUPINGS;
        my $type = shift @GROUPINGS;
        if ( !$names{$name} ) {
            push @new_groupings, $name, $type;
        }
    }

    while (@STATISTICS) {
        my $key    = shift @STATISTICS;
        my $info   = shift @STATISTICS;
        my ($name) = $key =~ /^(?:ALL|SUM|AVG|MIN|MAX)\((.+)\)$/;
        unless ( $name && $names{$name} ) {
            push @new_statistics, $key, $info;
        }
    }

    # Add new ones
    my %ranges = RT::Ticket->CustomDateRanges;
    for my $name ( sort keys %ranges ) {
        my %extra_info;
        my $spec = $ranges{$name};
        if ( ref $spec && $spec->{business_time} ) {
            $extra_info{business_time} = 1;
        }

        push @new_groupings, $name => $extra_info{business_time} ? 'DurationInBusinessHours' : 'Duration';
        push @new_statistics,
            (
            "ALL($name)" => [ "Summary of $name", 'CustomDateRangeAll', $name, \%extra_info ],
            "SUM($name)" => [ "Total $name",   'CustomDateRange', 'SUM', $name, \%extra_info ],
            "AVG($name)" => [ "Average $name", 'CustomDateRange', 'AVG', $name, \%extra_info ],
            "MIN($name)" => [ "Minimum $name", 'CustomDateRange', 'MIN', $name, \%extra_info ],
            "MAX($name)" => [ "Maximum $name", 'CustomDateRange', 'MAX', $name, \%extra_info ],
            );
    }

    @GROUPINGS  = @new_groupings;
    @STATISTICS = @new_statistics;
    %GROUPINGS  = %STATISTICS = ();

    return 1;
}

RT::Base->_ImportOverlays();

1;
