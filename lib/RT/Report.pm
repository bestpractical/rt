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

package RT::Report;

use strict;
use warnings;
use 5.010;
use Scalar::Util qw(weaken);
use RT::User;


=head1 NAME

RT::Report - Base class of RT search charts

=head1 DESCRIPTION

This class defines fundamental bits of code that all report classes like
L<RT::Report::Tickets> can make use of.

Subclasses are supposed to have the following things defined:

=over

=item @GROUPINGS

Group By options are defined here.

=item @STATISTICS

Calculation options are defined here.

=back

Check L<RT::Report::Tickets> for real examples.

=head1 METHODS

=cut

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
        Distinct => 1,
    },
    Catalog => {
        Display => sub {
            my $self = shift;
            my %args = (@_);

            my $catalog = RT::Catalog->new( $self->CurrentUser );
            $catalog->Load( $args{'VALUE'} );
            return $catalog->Name;
        },
        Localize => 1,
        Distinct => 1,
    },
    Priority => {
        Sort => 'numeric raw',
        Distinct => 1,
    },
    User => {
        SubFields => [grep RT::User->_Accessible($_, "public"), qw(
            Name RealName NickName
            EmailAddress
            Organization
            Lang City Country Timezone
        )],
        Function => 'GenerateUserFunction',
        Distinct => 1,
    },
    Watcher => {
        SubFields => sub {
            my $self = shift;
            my $args = shift;

            my %fields = (
                user => [ grep RT::User->_Accessible( $_, "public" ),
                    qw( Name RealName NickName EmailAddress Organization Lang City Country Timezone) ],
                principal => [ grep RT::User->_Accessible( $_, "public" ), qw( Name ) ],
            );

            my @res;
            if ( $args->{key} =~ /^CustomRole/ ) {
                my $crs = $self->GetCustomRoles(%$args);
                while ( my $cr = $crs->Next ) {
                    for my $field ( @{ $fields{ $cr->MaxValues ? 'user' : 'principal' } } ) {
                        push @res, [ $cr->Name, $field ], "CustomRole.{" . $cr->id . "}.$field";
                    }
                }
            }
            else {
                for my $field ( @{ $fields{principal} } ) {
                    push @res, [ $args->{key}, $field ], "$args->{key}.$field";
                }
            }
            return @res;
        },
        Function => 'GenerateWatcherFunction',
        Label    => sub {
            my $self = shift;
            my %args = (@_);

            my $key;
            if ( $args{KEY} =~ /^CustomRole\.\{(\d+)\}/ ) {
                my $id = $1;
                my $cr = RT::CustomRole->new( $self->CurrentUser );
                $cr->Load($id);
                $key = $cr->Name;
            }
            else {
                $key = $args{KEY};
            }
            return join ' ', $key, $args{SUBKEY};
        },
        Display => sub {
            my $self = shift;
            my %args = (@_);
            # VALUE could be "(no value)" from perl level calculation
            if ( $args{FIELD} eq 'id' && ($args{'VALUE'} // '') !~ /\D/ ) {
                my $princ = RT::Principal->new( $self->CurrentUser );
                $princ->Load( $args{'VALUE'} ) if $args{'VALUE'};
                return $self->loc('(no value)') unless $princ->Id;
                return $princ->IsGroup ? $self->loc( 'Group: [_1]', $princ->Object->Name ) : $princ->Object->Name;
            }
            else {
                return $args{VALUE};
            }
        },
        Distinct => sub {
            my $self = shift;
            my %args = @_;
            if ( $args{KEY} =~ /^CustomRole\.\{(\d+)\}/ ) {
                my $id = $1;
                my $obj = RT::CustomRole->new( RT->SystemUser );
                $obj->Load( $id );
                if ( $obj->MaxValues == 1 ) {
                    return 1;
                }
                else {
                    return 0;
                }
            }
            return 0;
        },
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
        Distinct => 1,
    },
    CustomField => {
        SubFields => sub {
            my $self = shift;
            my $args = shift;

            my @res;
            my $CustomFields = $self->GetCustomFields(%$args);
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

                # When we render label in charts, the cf could surely be
                # seen by current user(SubFields above checks rights), but
                # we can't use current user to load cf here because the
                # right might be granted at queue level and it's not
                # straightforward to add a related queue as context object
                # here. That's why we use RT->SystemUser here instead.

                my $obj = RT::CustomField->new( RT->SystemUser );
                $obj->Load( $cf );
                $cf = $obj->Name;
            }

            return 'Custom field [_1]', $cf;
        },
        Distinct => sub {
            my $self = shift;
            my %args = @_;
            if ( $args{SUBKEY} =~ /\{(\d+)\}/ ) {
                my $id = $1;
                my $obj = RT::CustomField->new( RT->SystemUser );
                $obj->Load( $id );
                if ( $obj->MaxValues == 1 ) {
                    return 1;
                }
                else {
                    return 0;
                }
            }
            return 0;
        },
    },
    Enum => {
        Localize => 1,
        Distinct => 1,
    },
    Duration => {
        SubFields => [ qw/Default Hour Day Week Month Year/ ],
        Localize => 1,
        Short    => 0,
        Show     => 1,
        Sort     => 'duration',
        Distinct => 1,
    },
    DurationInBusinessHours => {
        SubFields => [ qw/Default Hour/ ],
        Localize => 1,
        Short    => 0,
        Show     => 1,
        Sort     => 'duration',
        Distinct => 1,
        Display => sub {
            my $self = shift;
            my %args = (@_);
            my $value = $args{VALUE};
            my $format = $args{FORMAT} || 'text';
            if ( $format eq 'html' ) {
                RT::Interface::Web::EscapeHTML(\$value);
                my $css_class;
                if ( my $style = $self->__Value('_css_class') ) {
                    $css_class = $style->{$args{NAME}};
                };
                return $value unless $css_class;
                return qq{<span class="$css_class">$value</span>};
            }
            else {
                return $value;
            }
        },
    },
);

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
    CustomFieldNumericRange => {
        Function => sub {
            my $self     = shift;
            my $function = shift;
            my $id       = shift;
            my $cf       = RT::CustomField->new( RT->SystemUser );
            $cf->Load($id);
            my ($ocfv_alias) = $self->_CustomFieldJoin( $id, $cf );
            my $cast         = RT->DatabaseHandle->CastAsDecimal('Content');
            my $precision    = $cf->NumericPrecision() // 3;
            return (
                FUNCTION => $function eq 'AVG' ? "ROUND($function($cast), $precision)" : "$function($cast)",
                ALIAS    => $ocfv_alias,
            );
        },
    },
    CustomFieldNumericRangeAll => {
        SubValues    => sub { return ( 'Minimum', 'Average', 'Maximum', 'Total' ) },
        Function => sub {
            my $self = shift;
            my $id   = shift;
            my $cf   = RT::CustomField->new( RT->SystemUser );
            $cf->Load($id);
            my ($ocfv_alias) = $self->_CustomFieldJoin( $id, $cf );
            my $cast         = RT->DatabaseHandle->CastAsDecimal('Content');
            my $precision    = $cf->NumericPrecision() // 3;

            return (
                Minimum => { FUNCTION => "MIN($cast)",                    ALIAS => $ocfv_alias },
                Average => { FUNCTION => "ROUND(AVG($cast), $precision)", ALIAS => $ocfv_alias },
                Maximum => { FUNCTION => "MAX($cast)",                    ALIAS => $ocfv_alias },
                Total   => { FUNCTION => "SUM($cast)",                    ALIAS => $ocfv_alias },
            );
        },
    },
);

sub Groupings {
    my $self = shift;
    my %args = (@_);

    my @fields;

    my @tmp = $self->_Groupings();
    while ( my ($field, $type) = splice @tmp, 0, 2 ) {
        my $meta = $GROUPINGS_META{ $type } || {};
        unless ( $meta->{'SubFields'} ) {
            push @fields, [$field, $field], $field;
        }
        elsif ( ref( $meta->{'SubFields'} ) eq 'ARRAY' ) {
            push @fields, map { ([$field, $_], "$field.$_") } @{ $meta->{'SubFields'} };
        }
        elsif ( my $code = $self->FindImplementationCode( $meta->{'SubFields'} ) ) {
            push @fields, $code->( $self, { %args, key => $field } );
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

    my ($key, $subkey) = split /(?<!CustomRole)\./, $args{'GroupBy'}, 2;

    my $type = $self->_GroupingType( $key );
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
        return 1 if grep $_ eq "$key.$subkey", $code->( $self, { %args, key => $key } );
    }
    return 0;
}

sub Statistics {
    my $self  = shift;
    my @items = $self->_Statistics;
    return @items, $self->_NumericCustomFields(@_);
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
    elsif ( !RT->Config->Get('UseSQLForACLChecks') ) {
        RT->Logger->notice('UseSQLForACLChecks is disabled, results might be inaccurate');
    }

    my %res = $self->_SetupGroupings(%args);

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

sub _SetupGroupings {
    my $self = shift;
    my %args = (
        Query => undef,
        GroupBy => undef,
        Function => undef,
        @_
    );

    my $i = 0;

    my @group_by = grep defined && length,
        ref( $args{'GroupBy'} )? @{ $args{'GroupBy'} } : ($args{'GroupBy'});
    @group_by = $self->DefaultGroupBy unless @group_by;

    my $distinct_results = 1;
    foreach my $e ( splice @group_by ) {
        unless ($self->IsValidGrouping( Query => $args{Query}, GroupBy => $e )) {
            RT->Logger->error("'$e' is not a valid grouping for reports; skipping");
            next;
        }
        my ($key, $subkey) = split /(?<!CustomRole)\./, $e, 2;
        $e = { $self->_FieldToFunction( KEY => $key, SUBKEY => $subkey ) };
        $e->{'TYPE'} = 'grouping';
        $e->{'INFO'} = $self->_GroupingType($key);
        $e->{'META'} = $GROUPINGS_META{ $e->{'INFO'} };
        $e->{'POSITION'} = $i++;
        if ( my $distinct = $e->{'META'}{Distinct} ) {
            if ( ref($distinct) eq 'CODE' ) {
                $distinct_results = 0 unless $distinct->( $self, KEY => $key, SUBKEY => $subkey );
            }
        }
        else {
            $distinct_results = 0;
        }
        push @group_by, $e;
    }
    $self->{_distinct_results} = $distinct_results;

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

    my %statistics = $self->Statistics(%args);
    my @function = grep defined && length,
        ref( $args{'Function'} )? @{ $args{'Function'} } : ($args{'Function'});
    push @function, 'COUNT' unless @function;
    foreach my $e ( @function ) {
        $e = {
            TYPE => 'statistic',
            KEY  => $e,
            INFO => $statistics{ $e },
            META => $STATISTICS_META{ $statistics{ $e }[1] },
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

    return %res;
}

=head2 _FieldToFunction FIELD

Returns a tuple of the field or a database function to allow grouping on that field.

=cut

sub _FieldToFunction {
    my $self = shift;
    my %args = (@_);

    $args{'FIELD'} ||= $args{'KEY'};

    my $meta = $GROUPINGS_META{ $self->_GroupingType( $args{'KEY'} ) };
    return ('FUNCTION' => 'NULL') unless $meta;

    return %args unless $meta->{'Function'};

    my $code = $self->FindImplementationCode( $meta->{'Function'} );
    return ('FUNCTION' => 'NULL') unless $code;

    return $code->( $self, %args );
}

sub SortEntries {
    my $self = shift;
    my %args = (
        ChartOrderBy   => 'label',
        ChartOrder     => 'ASC',
        ChartLimit     => undef,
        ChartLimitType => 'Top',
        @_,
    );

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
            my $r = uc $f->($args{ChartOrder} eq 'ASC' ? ( $_[0], $_[1] ) : ( $_[1], $_[0] ) );
            return $r if $r;
        }
    };

    my @data = map [$_], @{ $self->{'items'} };

    if ( $args{ChartOrderBy} eq 'value' && grep { $_ eq 'id' } $self->ColumnsList ) {
        $_->[1] = $_->[0]->RawValue('id') for @data;
        push @SORT_OPS, sub { $_[0][1] <=> $_[1][1] };
    }

    # Even if charts are sorted by value, it's still good to sort by labels next, to sort items with the same value.
    for my $group_by ( @groups ) {
        my $idx = @SORT_OPS + 1;
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

    if ( $args{ChartLimit} && $args{ChartLimit} > 0 && @{ $self->{'items'} } > $args{ChartLimit} ) {
        if ( $args{ChartLimitType} eq 'Top' ) {
            @{ $self->{'items'} } = @{ $self->{'items'} }[ 0 .. $args{ChartLimit} - 1 ];
        }
        else {
            @{ $self->{'items'} } = @{ $self->{'items'} }[ -$args{ChartLimit} .. -1 ];
        }
    }
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

    my $single_role;

    if ( $type =~ s!^CustomRole\.\{(\d+)\}!RT::CustomRole-$1! ) {
        my $id = $1;
        my $cr = RT::CustomRole->new( $self->CurrentUser );
        $cr->Load($id);
        $single_role = 1 if $cr->MaxValues;
    }

    my $column = $single_role ? $args{'SUBKEY'} || 'Name' : 'id';

    my $alias = $self->{"_sql_report_watcher_alias_$type"};
    unless ( $alias ) {
        my $groups = $self->_RoleGroupsJoin(Name => $type);
        my $group_members = $self->Join(
            TYPE            => 'LEFT',
            ALIAS1          => $groups,
            FIELD1          => 'id',
            TABLE2          => 'GroupMembers',
            FIELD2          => 'GroupId',
            ENTRYAGGREGATOR => 'AND',
        );
        $alias = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => $group_members,
            FIELD1 => 'MemberId',
            TABLE2 => $single_role ? 'Users' : 'Principals',
            FIELD2 => 'id',
        );
        $self->{"_sql_report_watcher_alias_$type"} = $alias;
    }
    @args{qw(ALIAS FIELD)} = ($alias, $column);

    return %args;
}

sub DurationAsString {
    my $self = shift;
    my %args = @_;
    my $v = $args{'VALUE'};
    my $max_unit = $args{INFO} && ref $args{INFO}[-1] && $args{INFO}[-1]{business_time} ? 'hour' : 'year';
    my $format = $args{FORMAT} || 'text';

    my $css_class;
    if (   $format eq 'html'
        && $self->can('__Value')
        && $args{INFO}
        && ref $args{INFO}[-1]
        && $args{INFO}[-1]{business_time} )
    {

        # 1 means business hours in SLA, its css is already generated and saved in _css_class.
        if ( $args{INFO}[-1]{business_time} eq '1' ) {
            my $style = $self->__Value('_css_class');
            my $field;
            if ( $args{INFO}[1] =~ /^CustomDateRange/ ) {
                $field = $args{INFO}[-2];
            }
            elsif ( $args{INFO}[1] =~ /^DateTimeInterval/ ) {
                $field = join ' to ', $args{INFO}[-3], $args{INFO}[-2];
            }

            $css_class = $style->{$field} if $style && $field;
        }
        else {
            $css_class = 'business_hours_' . HTML::Mason::Commands::CSSClass( lc $args{INFO}[-1]{business_time} )
        }
    }

    unless ( ref $v ) {
        my $value;
        if ( defined $v && length $v ) {
            $value = RT::Date->new( $self->CurrentUser )->DurationAsString(
                $v,
                Show    => 3,
                Short   => 1,
                MaxUnit => $max_unit,
            );
        }
        else {
            $value = $self->loc("(no value)");
        }

        if ( $format eq 'html' ) {
            RT::Interface::Web::EscapeHTML(\$value);
            return $value unless $css_class;
            return qq{<span class="$css_class">$value</span>};
        }
        else {
            return $value;
        }

    }

    my $date = RT::Date->new( $self->CurrentUser );
    my %res = %$v;
    foreach my $e ( values %res ) {
        $e = $date->DurationAsString( $e, Short => 1, Show => 3, MaxUnit => $max_unit )
            if defined $e && length $e;
        $e = $self->loc("(no value)") unless defined $e && length $e;
    }

    if ( $format eq 'html' ) {
        for my $key ( keys %res ) {
            RT::Interface::Web::EscapeHTML(\$res{$key});
            next unless $css_class;
            $res{$key} = qq{<span class="$css_class">$res{$key}</span>};
        }
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
    @footer = ({ even => ++$i%2, cells => []}) if $self->{_distinct_results};

    my $g = 0;
    foreach my $column ( @{ $columns{'Groups'} } ) {
        $i = 0;
        my $last;
        while ( my $entry = $self->Next ) {
            my $value = $entry->LabelValue( $column, 'html' );
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
    } if $self->{_distinct_results};

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
            push @{ $footer[0]{'cells'} }, { type => 'value', value => undef } if $self->{_distinct_results};
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
            my $value = $entry->LabelValue( $column, 'html' ) || {};
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

        next unless $self->{_distinct_results};
        unless ( $info->{'META'}{'NoTotals'} ) {
            my $total_code = $self->LabelValueCode( $column );
            foreach my $e ( @subs ) {
                my $total = $total{ $e };
                $total = $total_code->( $self, %$info, VALUE => $total, FORMAT => 'html' )
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

sub _SetupCustomDateRanges {
    my $self = shift;
    my %names;
    my @groupings = $self->_Groupings;
    my @statistics = $self->_Statistics;

    # Remove old custom date range groupings
    for my $field ( grep {ref} @statistics) {
        if ( $field->[1] && $field->[1] eq 'CustomDateRangeAll' ) {
            $names{ $field->[2] } = 1;
        }
    }

    my ( @new_groupings, @new_statistics );
    while (@groupings) {
        my $name = shift @groupings;
        my $type = shift @groupings;
        if ( !$names{$name} ) {
            push @new_groupings, $name, $type;
        }
    }

    while (@statistics) {
        my $key    = shift @statistics;
        my $info   = shift @statistics;
        my ($name) = $key =~ /^(?:ALL|SUM|AVG|MIN|MAX)\((.+)\)$/;
        unless ( $name && $names{$name} ) {
            push @new_statistics, $key, $info;
        }
    }

    # Add new ones
    my %ranges = $self->_SingularClass->ObjectType->CustomDateRanges;
    for my $name ( sort keys %ranges ) {
        my %extra_info;
        my $spec = $ranges{$name};
        if ( ref $spec && $spec->{business_time} ) {
            $extra_info{business_time} = $spec->{business_time};
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

    $self->_Groupings( @new_groupings );
    $self->_Statistics( @new_statistics );

    return 1;
}

sub _NumericCustomFields {
    my $self         = shift;
    my %args         = @_;
    my $custom_fields = $self->GetCustomFields(%args);

    my @items;
    while ( my $custom_field = $custom_fields->Next ) {
        next unless $custom_field->IsNumeric && $custom_field->SingleValue;
        my $id   = $custom_field->Id;
        my $name = $custom_field->Name;

        push @items,
            (
                "ALL(CF.$id)" => [ "Summary of $name", 'CustomFieldNumericRangeAll', $id ],
                "SUM(CF.$id)" => [ "Total $name",      'CustomFieldNumericRange',    'SUM', $id ],
                "AVG(CF.$id)" => [ "Average $name",    'CustomFieldNumericRange',    'AVG', $id ],
                "MIN(CF.$id)" => [ "Minimum $name",    'CustomFieldNumericRange',    'MIN', $id ],
                "MAX(CF.$id)" => [ "Maximum $name",    'CustomFieldNumericRange',    'MAX', $id ],
            );
    }
    return @items;
}

sub _GroupingType {
    my $self = shift;
    my $key  = shift or return;
    # keys for custom roles are like "CustomRole.{1}"
    $key = 'CustomRole' if $key =~ /^CustomRole/;
    return { $self->_Groupings }->{$key};
}

sub _GroupingsMeta { return \%GROUPINGS_META };
sub _StatisticsMeta { return \%STATISTICS_META };

# Return the corresponding @GROUPINGS in subclass
sub _Groupings {
    my $self  = shift;
    my $class = ref($self) || $self;
    no strict 'refs';

    if (@_) {
        @{ $class . '::GROUPINGS' } = @_;
    }
    return @{ $class . '::GROUPINGS' };
}

# Return the corresponding @STATISTICS in subclass
sub _Statistics {
    my $self  = shift;
    my $class = ref($self) || $self;
    no strict 'refs';

    if (@_) {
        @{ $class . '::STATISTICS' } = @_;
    }
    return @{ $class . '::STATISTICS' };
}

=head2 DefaultGroupBy

By default, it's the first item in @GROUPINGS.

=cut

sub DefaultGroupBy {
    my $self  = shift;
    my $class = ref($self) || $self;
    no strict 'refs';
    ${ $class . '::GROUPINGS' }[0];
}

# The following methods are more collection related

=head2 _DoSearchInPerl

For complicated reports that can't be calculated in SQL, do them in Perl.

=cut

sub _DoSearchInPerl {
    my $self = shift;

    my $objects = $self->_CollectionClass->new( $self->CurrentUser );
    $objects->FromSQL( $self->{_query} );
    my @groups = grep { $_->{TYPE} eq 'grouping' } map { $self->ColumnInfo($_) } $self->ColumnsList;
    my %info;

    my %bh_class;

    # Can't use ->can('SLA') as SLA is an autoloaded method of RT::Ticket
    if ( $self->_SingularClass->ObjectType->_ClassAccessible->{SLA} ) {
        %bh_class = map { $_ => 'business_hours_' . HTML::Mason::Commands::CSSClass( lc $_ ) }
           keys %{ RT->Config->Get('ServiceBusinessHours') || {} };
    }

    while ( my $object = $objects->Next ) {
        my $bh = %bh_class
            && $object->SLA ? RT->Config->Get('ServiceAgreements')->{Levels}{ $object->SLA }{BusinessHours} : '';

        my @keys;
        my @extra_keys;
        my %css_class;
        for my $group ( @groups ) {
            my $value;

            if ( $object->_Accessible($group->{KEY}, 'read' )) {
                if ( $group->{SUBKEY} ) {
                    my $method = "$group->{KEY}Obj";
                    if ( my $obj = $object->$method ) {
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
                $value //= $object->_Value( $group->{KEY} ) // $self->loc('(no value)');
            }
            elsif ( $group->{INFO} eq 'Watcher' ) {
                my @values;
                if ( $object->can($group->{KEY}) ) {
                    my $method = $group->{KEY};
                    push @values, map { $_->MemberId } @{$object->$method->MembersObj->ItemsArrayRef};
                }
                elsif ( $group->{KEY} eq 'Watcher' ) {
                    push @values, map { $_->MemberId } @{$object->$_->MembersObj->ItemsArrayRef} for /Requestor Cc AdminCc/;
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
                my $values = $object->CustomFieldValues($id);
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
                    if ( $object->$end_method->Unix > 0 && $object->$start_method->Unix > 0 ) {
                        my $seconds;

                        if ($business_time) {
                            $seconds = $object->CustomDateRange(
                                '',
                                {   value         => "$end - $start",
                                    business_time => 1,
                                    format        => sub { $_[0] },
                                }
                            );
                        }
                        else {
                            $seconds = $object->$end_method->Unix - $object->$start_method->Unix;
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
                    my %ranges = $self->_RoleGroupClass->CustomDateRanges;
                    if ( my $spec = $ranges{$group->{FIELD}} ) {
                        if ( $group->{SUBKEY} eq 'Default' ) {
                            $value = $object->CustomDateRange( $group->{FIELD}, $spec );
                        }
                        else {
                            my $seconds = $object->CustomDateRange( $group->{FIELD},
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
                            = $self->_CalculateTime( $type, $object->$method * 60, $info{$key}{$name} ) || 0;
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
                    next unless $object->$end_method->Unix > 0 && $object->$start_method->Unix > 0;

                    my $value;
                    if ($extra_info->{business_time}) {
                        $value = $object->CustomDateRange(
                            '',
                            {   value         => "$end - $start",
                                business_time => $extra_info->{business_time},
                                format        => sub { return $_[0] },
                            }
                        );
                    }
                    else {
                        $value = $object->$end_method->Unix - $object->$start_method->Unix;
                    }

                    $info{$key}{$name} = $self->_CalculateTime( $type, $value, $info{$key}{$name} );
                }
                elsif ( $field->{INFO}[1] eq 'CustomDateRange' ) {
                    my ( undef, undef, $type, $range_name ) = @{ $field->{INFO} };
                    my $name = lc $field->{NAME};
                    $info{$key}{$name} ||= 0;

                    my $value;
                    my %ranges = $self->_RoleGroupClass->CustomDateRanges;
                    if ( my $spec = $ranges{$range_name} ) {
                        $value = $object->CustomDateRange(
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
            push @{ $info{$key}{ids} }, $object->id;
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
}

sub _PostSearch {
    my $self = shift;
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call AddEmptyRows"
        );
    }
    else {
        $self->PostProcessRecords;
    }
}


# Gotta skip over customized Next, since it does all sorts of crazy magic we don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    my $res = $self->_SingularClass->new($self->CurrentUser);
    $res->{'report'} = $self;
    weaken $res->{'report'};
    return $res;
}

sub _RoleGroupClass {
    my $self = shift;
    my $collection_class = ref $self || $self;
    $collection_class =~ s!(?<=RT::)Report::!!;
    return $collection_class->_SingularClass;
}

sub _SingularClass {
    my $self = shift;
    return (ref $self || $self) . '::Entry';
}

=head2 GetReferencedObjects Query => QUERY

This is generally an abstraction of GetReferenced... methods in
L<RT::Interface::Web::QueryBuilder::Tree>, based on what current report is for.

Returns a tuple of the class and referenced objects.

=cut

sub GetReferencedObjects {
    my $self = shift;
    my %args = @_;

    my ( $class, $method );
    if ( $self->isa('RT::Report::Assets') ) {
        $class  = 'RT::Catalog';
        $method = 'GetReferencedCatalogs';
    }
    else {
        $class  = 'RT::Queue';
        $method = 'GetReferencedQueues';
    }

    my $objects;
    if ( $args{Query} ) {
        require RT::Interface::Web::QueryBuilder::Tree;
        my $tree = RT::Interface::Web::QueryBuilder::Tree->new('AND');
        $tree->ParseSQL( Query => $args{'Query'}, CurrentUser => $self->CurrentUser, Class => ref $self );
        $objects = $tree->$method( CurrentUser => $self->CurrentUser );
    }
    return ( $class, $objects );
}

=head2 GetCustomFields Query => QUERY

Returns an L<RT::CustomFields> object that contains all possible custom
fields the given query can refer to.

=cut

sub GetCustomFields {
    my $self = shift;
    my %args = @_;

    my $custom_fields = RT::CustomFields->new( $self->CurrentUser );
    $custom_fields->LimitToLookupType( $self->RecordClass->CustomFieldLookupType );
    $custom_fields->LimitToObjectId(0);

    if ( $args{'Query'} ) {
        my ( $referenced_class, $referenced_objects ) = $self->GetReferencedObjects(%args);
        foreach my $id ( keys %{$referenced_objects} ) {
            my $object = $referenced_class->new( $self->CurrentUser );
            $object->Load($id);
            next unless $object->id;
            $custom_fields->SetContextObject($object) if keys %{$referenced_objects} == 1;
            $custom_fields->LimitToObjectId( $object->id );
        }
    }
    return $custom_fields;
}

=head2 GetCustomRoles Query => QUERY

Returns an L<RT::CustomRoles> object that contains all possible custom
roles the given query can refer to.

=cut

sub GetCustomRoles {
    my $self = shift;
    my %args = @_;

    my $custom_roles = RT::CustomRoles->new( $self->CurrentUser );
    $custom_roles->LimitToLookupType( $self->RecordClass->CustomFieldLookupType );
    # Adding this to avoid returning all records when no queues are available.
    $custom_roles->LimitToObjectId(0);

    my ( $referenced_class, $referenced_objects ) = $self->GetReferencedObjects(%args);
    foreach my $id ( keys %{$referenced_objects} ) {
        my $object = $referenced_class->new( $self->CurrentUser );
        $object->Load($id);
        next unless $object->id;
        $custom_roles->LimitToObjectId( $object->id );
    }
    return $custom_roles;
}

sub _CollectionClass {
    my $self = shift;
    my $class = ref $self || $self;
    $class =~ s!::Report!!;
    return $class;
}

RT::Base->_ImportOverlays();

1;
