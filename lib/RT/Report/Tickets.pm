# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
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

our @GROUPINGS = (
    Status => 'Enum',

    Queue  => 'Queue',

    Owner         => 'User',
    Creator       => 'User',
    LastUpdatedBy => 'User',

    Requestor     => 'Watcher',
    Cc            => 'Watcher',
    AdminCc       => 'Watcher',
    Watcher       => 'Watcher',

    Created       => 'Date',
    Starts        => 'Date',
    Started       => 'Date',
    Resolved      => 'Date',
    Due           => 'Date',
    Told          => 'Date',
    LastUpdated   => 'Date',

    CF            => 'CustomField',
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
    },
    User => {
        SubFields => [qw(
            Name RealName NickName
            EmailAddress
            Organization
            Lang City Country Timezone
        )],
        Function => 'GenerateUserFunction',
    },
    Watcher => {
        SubFields => [qw(
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
        )],
        Function => 'GenerateDateFunction',
        Display => sub {
            my $self = shift;
            my %args = (@_);

            my $raw = $args{'VALUE'};
            return $raw unless defined $raw;

            if ( $args{'SUBKEY'} eq 'DayOfWeek' ) {
                return $RT::Date::DAYS_OF_WEEK[ int $raw ];
            }
            elsif ( $args{'SUBKEY'} eq 'Month' ) {
                return $RT::Date::MONTHS[ int($raw) - 1 ];
            }
            return $raw;
        },
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
                $queues = $args->{'Queues'} = $tree->GetReferencedQueues;
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
                push @res, "Custom field '". $CustomField->Name ."'", "CF.{". $CustomField->id ."}";
            }
            return @res;
        },
        Function => 'GenerateCustomFieldFunction',
        Label => sub {
            my $self = shift;
            my %args = (@_);

            my ($cf) = ( $args{'SUBKEY'} =~ /^{(.*)}$/ );
            if ( $cf =~ /^\d+$/ ) {
                my $obj = RT::CustomField->new( $self->CurrentUser );
                $obj->Load( $cf );
                $cf = $obj->Name;
            }

            return 'Custom field [_1]', $self->CurrentUser->loc( $cf );
        },
    },
    Enum => {
    },
);

our @STATISTICS = (
    COUNT             => ['Tickets', 'Count', 'id'],

    'SUM(TimeWorked)' => ['Total time worked',   'Simple', 'SUM', 'TimeWorked' ],
    'AVG(TimeWorked)' => ['Average time worked', 'Simple', 'AVG', 'TimeWorked' ],
    'MIN(TimeWorked)' => ['Minimum time worked', 'Simple', 'MIN', 'TimeWorked' ],
    'MAX(TimeWorked)' => ['Maximum time worked', 'Simple', 'MAX', 'TimeWorked' ],

    'SUM(TimeEstimated)' => ['Total time estimated',   'Simple', 'SUM', 'TimeEstimated' ],
    'AVG(TimeEstimated)' => ['Average time estimated', 'Simple', 'AVG', 'TimeEstimated' ],
    'MIN(TimeEstimated)' => ['Minimum time estimated', 'Simple', 'MIN', 'TimeEstimated' ],
    'MAX(TimeEstimated)' => ['Maximum time estimated', 'Simple', 'MAX', 'TimeEstimated' ],

    'SUM(TimeLeft)' => ['Total time left',   'Simple', 'SUM', 'TimeLeft' ],
    'AVG(TimeLeft)' => ['Average time left', 'Simple', 'AVG', 'TimeLeft' ],
    'MIN(TimeLeft)' => ['Minimum time left', 'Simple', 'MIN', 'TimeLeft' ],
    'MAX(TimeLeft)' => ['Maximum time left', 'Simple', 'MAX', 'TimeLeft' ],

    'SUM(Created-Resolved)'
        => ['Summary of Created-Resolved', 'DateTimeInterval', 'SUM', 'Created', 'Resolved' ],
    'AVG(Created-Resolved)'
        => ['Average Created-Resolved', 'DateTimeInterval', 'AVG', 'Created', 'Resolved' ],
    'MIN(Created-Resolved)'
        => ['Minimum Created-Resolved', 'DateTimeInterval', 'MIN', 'Created', 'Resolved' ],
    'MAX(Created-Resolved)'
        => ['Maximum Created-Resolved', 'DateTimeInterval', 'MAX', 'Created', 'Resolved' ],

    'SUM(Created-LastUpdated)'
        => ['Summary of Created-LastUpdated', 'DateTimeInterval', 'SUM', 'Created', 'LastUpdated' ],
    'AVG(Created-LastUpdated)'
        => ['Average Created-LastUpdated', 'DateTimeInterval', 'AVG', 'Created', 'LastUpdated' ],
    'MIN(Created-LastUpdated)'
        => ['Minimum Created-LastUpdated', 'DateTimeInterval', 'MIN', 'Created', 'LastUpdated' ],
    'MAX(Created-LastUpdated)'
        => ['Maximum Created-LastUpdated', 'DateTimeInterval', 'MAX', 'Created', 'LastUpdated' ],
);
our %STATISTICS;

our %STATISTICS_META = (
    Count => {
        Function => sub {
            my $self = shift;
            my $field = shift || 'id';

            # UseSQLForACLChecks may add late joins
            my $joined = ($self->_isJoined || RT->Config->Get('UseSQLForACLChecks')) ? 1 : 0;
            return (
                FUNCTION => ($joined ? 'DISTINCT COUNT' : 'COUNT'),
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
            push @fields, $field, $field;
        }
        elsif ( ref( $meta->{'SubFields'} ) eq 'ARRAY' ) {
            push @fields, map { ("$field $_", "$field.$_") } @{ $meta->{'SubFields'} };
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
    return keys %{ $self->{'column_info'} || {} };
}

sub SetupGroupings {
    my $self = shift;
    my %args = (
        Query => undef,
        GroupBy => undef,
        Function => undef,
        @_
    );

    $self->FromSQL( $args{'Query'} );

    %GROUPINGS = @GROUPINGS unless keys %GROUPINGS;

    my @group_by = ref( $args{'GroupBy'} )? @{ $args{'GroupBy'} } : ($args{'GroupBy'});
    foreach my $e ( @group_by ) {
        my ($key, $subkey) = split /\./, $e, 2;
        $e = { $self->_FieldToFunction( KEY => $key, SUBKEY => $subkey ) };
        $e->{'TYPE'} = 'grouping';
        $e->{'INFO'} = $GROUPINGS{ $key };
        $e->{'META'} = $GROUPINGS_META{ $e->{'INFO'} };
    }
    $self->GroupBy( @group_by );

    my (@res, %column_info);

    my @function = ref( $args{'Function'} )? @{ $args{'Function'} } : ($args{'Function'});
    foreach my $e ( @function ) {
        my %args = $self->_StatsToFunction( $e );
        $args{'TYPE'} = 'statistic';
        $args{'INFO'} = $STATISTICS{ $e };
        $args{'META'} = $STATISTICS_META{ $args{'INFO'}[1] };
        push @res, $self->Column( %args );
        $column_info{ $res[-1] } = \%args;
    }

    foreach my $group_by ( @group_by ) {
        my $alias = $self->Column( %$group_by );
        $column_info{ $alias } = $group_by;
        push @res, $alias;
    }

    $self->{'column_info'} = \%column_info;

    return @res;
}

=head2 _DoSearch

Subclass _DoSearch from our parent so we can go through and add in empty 
columns if it makes sense 

=cut

sub _DoSearch {
    my $self = shift;
    $self->SUPER::_DoSearch( @_ );
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call AddEmptyRows"
        );
    }
    else {
        $self->AddEmptyRows;
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

sub _StatsToFunction {
    my $self = shift;
    my ($stat) = (@_);

    %STATISTICS = @STATISTICS unless keys %STATISTICS;

    my ($display, $type, @args) = @{ $STATISTICS{ $stat } || [] };
    unless ( $type ) {
        $RT::Logger->error("'$stat' is not valid statistics for report");
        return ('FUNCTION' => 'NULL');
    }

    my $meta = $STATISTICS_META{ $type };
    return ('FUNCTION' => 'NULL') unless $meta;
    return ('FUNCTION' => 'NULL') unless $meta->{'Function'};
    return $meta->{'Function'}->( $self, @args );
}


# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    my $res = RT::Report::Tickets::Entry->new(RT->SystemUser); # $self->CurrentUser);
    $res->{'column_info'} = $self->{'column_info'};
    return $res;
}

# This is necessary since normally NewItem (above) is used to intuit the
# correct class.  However, since we're abusing a subclass, it's incorrect.
sub _RoleGroupClass { "RT::Ticket" }


=head2 AddEmptyRows

If we're grouping on a criterion we know how to add zero-value rows
for, do that.

=cut

sub AddEmptyRows {
    my $self = shift;
    if ( @{ $self->{'_group_by_field'} || [] } == 1 && $self->{'_group_by_field'}[0] eq 'Status' ) {
        my %has = map { $_->__Value('Status') => 1 } @{ $self->ItemsArrayRef || [] };

        foreach my $status ( grep !$has{$_}, RT::Queue->new($self->CurrentUser)->StatusArray ) {

            my $record = $self->NewItem;
            $record->LoadFromHash( {
                id     => 0,
                status => $status
            } );
            $self->AddRecord($record);
        }
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

    my ($name) = ( $args{'SUBKEY'} =~ /^\.{(.*)}$/ );
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
RT::Base->_ImportOverlays();

1;
