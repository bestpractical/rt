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
    },
    Enum => {
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
        elsif ( ref( $meta->{'SubFields'} ) eq 'CODE' ) {
            push @fields, $meta->{'SubFields'}->(
                $self,
                \%args,
            );
        }
        else {
            $RT::Logger->error("%GROUPINGS_META for $type has unsupported SubFields");
        }
    }
    return @fields;
}

sub Label {
    my $self = shift;
    my $field = shift;
    if ( $field =~ /^(?:CF|CustomField)\.{(.*)}$/ ) {
        my $cf = $1;
        return $self->CurrentUser->loc( "Custom field '[_1]'", $cf ) if $cf =~ /\D/;
        my $obj = RT::CustomField->new( $self->CurrentUser );
        $obj->Load( $cf );
        return $self->CurrentUser->loc( "Custom field '[_1]'", $obj->Name );
    }
    return $self->CurrentUser->loc($field);
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
        $e->{'TYPE'} = $GROUPINGS{ $key };
        $e->{'META'} = $GROUPINGS_META{ $e->{'TYPE'} };
    }
    $self->GroupBy( @group_by );

    # UseSQLForACLChecks may add late joins
    my $joined = ($self->_isJoined || RT->Config->Get('UseSQLForACLChecks')) ? 1 : 0;

    my (@res, %column_type);

    my @function = ref( $args{'Function'} )? @{ $args{'Function'} } : ($args{'Function'});
    foreach my $e ( @function ) {
        my ($function, $field) = split /\s+/, $e, 2;
        $function = 'DISTINCT COUNT' if $joined && lc($function) eq 'count';
        push @res, $self->Column( FUNCTION => $function, FIELD => $field );
        $column_type{ $res[-1] } = { FUNCTION => $function, FIELD => $field };
    }

    foreach my $group_by ( @group_by ) {
        my $alias = $self->Column( %$group_by );
        $column_type{ $alias } = $group_by;
        push @res, $alias;
    }

    $self->{'column_types'} = \%column_type;

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

    my $code;
    unless ( ref $meta->{'Function'} ) {
        $code = $self->can( $meta->{'Function'} );
        unless ( $code ) {
            $RT::Logger->error("No method ". $meta->{'Function'} );
            return ('FUNCTION' => 'NULL');
        }
    }
    elsif ( ref( $meta->{'Function'} ) eq 'CODE' ) {
        $code = $meta->{'Function'};
    }
    else {
        $RT::Logger->error("%GROUPINGS_META for $args{FIELD} has unsupported Function");
        return ('FUNCTION' => 'NULL');
    }

    return $code->( $self, %args );
}

1;



# Gotta skip over RT::Tickets->Next, since it does all sorts of crazy magic we 
# don't want.
sub Next {
    my $self = shift;
    $self->RT::SearchBuilder::Next(@_);

}

sub NewItem {
    my $self = shift;
    my $res = RT::Report::Tickets::Entry->new(RT->SystemUser); # $self->CurrentUser);
    $res->{'column_types'} = $self->{'column_types'};
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

RT::Base->_ImportOverlays();

1;
