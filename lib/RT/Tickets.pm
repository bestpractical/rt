# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

  RT::Tickets - A collection of Ticket objects


=head1 SYNOPSIS

  use RT::Tickets;
  my $tickets = RT::Tickets->new($CurrentUser);

=head1 DESCRIPTION

   A collection of RT::Tickets.

=head1 METHODS


=cut

package RT::Tickets;

use strict;
use warnings;

use base 'RT::SearchBuilder';

use Role::Basic 'with';
with 'RT::SearchBuilder::Role::Roles';

use Scalar::Util qw/blessed/;
use 5.010;
use RT::Ticket;
use RT::SQL;

sub Table { 'Tickets'}

use RT::CustomFields;
use RT::CustomRoles;

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

# Configuration Tables:

# FIELD_METADATA is a mapping of searchable Field name, to Type, and other
# metadata.

our %FIELD_METADATA = (
    Status          => [ 'STRING', ], #loc_left_pair
    SLA             => [ 'STRING', ], #loc_left_pair
    Queue           => [ 'QUEUE' ], #loc_left_pair
    Type            => [ 'ENUM', ], #loc_left_pair
    Creator         => [ 'ENUM' => 'User', ], #loc_left_pair
    LastUpdatedBy   => [ 'ENUM' => 'User', ], #loc_left_pair
    Owner           => [ 'WATCHERFIELD' => 'Owner', ], #loc_left_pair
    EffectiveId     => [ 'INT', ], #loc_left_pair
    id              => [ 'ID', ], #loc_left_pair
    InitialPriority => [ 'INT', ], #loc_left_pair
    FinalPriority   => [ 'INT', ], #loc_left_pair
    Priority        => [ 'INT', ], #loc_left_pair
    TimeLeft        => [ 'INT', ], #loc_left_pair
    TimeWorked      => [ 'INT', ], #loc_left_pair
    TimeEstimated   => [ 'INT', ], #loc_left_pair

    Linked          => [ 'LINK' ], #loc_left_pair
    LinkedTo        => [ 'LINK' => 'To' ], #loc_left_pair
    LinkedFrom      => [ 'LINK' => 'From' ], #loc_left_pair
    MemberOf        => [ 'LINK' => To => 'MemberOf', ], #loc_left_pair
    DependsOn       => [ 'LINK' => To => 'DependsOn', ], #loc_left_pair
    RefersTo        => [ 'LINK' => To => 'RefersTo', ], #loc_left_pair
    HasMember       => [ 'LINK' => From => 'MemberOf', ], #loc_left_pair
    DependentOn     => [ 'LINK' => From => 'DependsOn', ], #loc_left_pair
    DependedOnBy    => [ 'LINK' => From => 'DependsOn', ], #loc_left_pair
    ReferredToBy    => [ 'LINK' => From => 'RefersTo', ], #loc_left_pair
    Told             => [ 'DATE'            => 'Told', ], #loc_left_pair
    Starts           => [ 'DATE'            => 'Starts', ], #loc_left_pair
    Started          => [ 'DATE'            => 'Started', ], #loc_left_pair
    Due              => [ 'DATE'            => 'Due', ], #loc_left_pair
    Resolved         => [ 'DATE'            => 'Resolved', ], #loc_left_pair
    LastUpdated      => [ 'DATE'            => 'LastUpdated', ], #loc_left_pair
    Created          => [ 'DATE'            => 'Created', ], #loc_left_pair
    Subject          => [ 'STRING', ], #loc_left_pair
    Content          => [ 'TRANSCONTENT', ], #loc_left_pair
    ContentType      => [ 'TRANSFIELD', ], #loc_left_pair
    Filename         => [ 'TRANSFIELD', ], #loc_left_pair
    TransactionDate  => [ 'TRANSDATE', ], #loc_left_pair
    Requestor        => [ 'WATCHERFIELD'    => 'Requestor', ], #loc_left_pair
    Requestors       => [ 'WATCHERFIELD'    => 'Requestor', ], #loc_left_pair
    Cc               => [ 'WATCHERFIELD'    => 'Cc', ], #loc_left_pair
    AdminCc          => [ 'WATCHERFIELD'    => 'AdminCc', ], #loc_left_pair
    Watcher          => [ 'WATCHERFIELD', ], #loc_left_pair
    QueueCc          => [ 'WATCHERFIELD'    => 'Cc'      => 'Queue', ], #loc_left_pair
    QueueAdminCc     => [ 'WATCHERFIELD'    => 'AdminCc' => 'Queue', ], #loc_left_pair
    QueueWatcher     => [ 'WATCHERFIELD'    => undef     => 'Queue', ], #loc_left_pair
    CustomRole       => [ 'WATCHERFIELD' ], # loc_left_pair
    CustomFieldValue => [ 'CUSTOMFIELD' => 'Ticket' ], #loc_left_pair
    CustomField      => [ 'CUSTOMFIELD' => 'Ticket' ], #loc_left_pair
    CF               => [ 'CUSTOMFIELD' => 'Ticket' ], #loc_left_pair
    TxnCF            => [ 'CUSTOMFIELD' => 'Transaction' ], #loc_left_pair
    TransactionCF    => [ 'CUSTOMFIELD' => 'Transaction' ], #loc_left_pair
    QueueCF          => [ 'CUSTOMFIELD' => 'Queue' ], #loc_left_pair
    Lifecycle        => [ 'LIFECYCLE' ], #loc_left_pair
    Updated          => [ 'TRANSDATE', ], #loc_left_pair
    UpdatedBy        => [ 'TRANSCREATOR', ], #loc_left_pair
    OwnerGroup       => [ 'MEMBERSHIPFIELD' => 'Owner', ], #loc_left_pair
    RequestorGroup   => [ 'MEMBERSHIPFIELD' => 'Requestor', ], #loc_left_pair
    CCGroup          => [ 'MEMBERSHIPFIELD' => 'Cc', ], #loc_left_pair
    AdminCCGroup     => [ 'MEMBERSHIPFIELD' => 'AdminCc', ], #loc_left_pair
    WatcherGroup     => [ 'MEMBERSHIPFIELD', ], #loc_left_pair
    HasAttribute     => [ 'HASATTRIBUTE', 1 ],
    HasNoAttribute     => [ 'HASATTRIBUTE', 0 ],
);

# Lower Case version of FIELDS, for case insensitivity
our %LOWER_CASE_FIELDS = map { ( lc($_) => $_ ) } (keys %FIELD_METADATA);

our %SEARCHABLE_SUBFIELDS = (
    User => [qw(
        EmailAddress Name RealName Nickname Organization Address1 Address2
        City State Zip Country WorkPhone HomePhone MobilePhone PagerPhone id
    )],
);

# Mapping of Field Type to Function
our %dispatch = (
    ENUM            => \&_EnumLimit,
    INT             => \&_IntLimit,
    ID              => \&_IdLimit,
    LINK            => \&_LinkLimit,
    DATE            => \&_DateLimit,
    STRING          => \&_StringLimit,
    QUEUE           => \&_QueueLimit,
    TRANSFIELD      => \&_TransLimit,
    TRANSCONTENT    => \&_TransContentLimit,
    TRANSDATE       => \&_TransDateLimit,
    TRANSCREATOR    => \&_TransCreatorLimit,
    WATCHERFIELD    => \&_WatcherLimit,
    MEMBERSHIPFIELD => \&_WatcherMembershipLimit,
    CUSTOMFIELD     => \&_CustomFieldLimit,
    HASATTRIBUTE    => \&_HasAttributeLimit,
    LIFECYCLE       => \&_LifecycleLimit,
);

# Default EntryAggregator per type
# if you specify OP, you must specify all valid OPs
my %DefaultEA = (
    INT  => 'AND',
    ENUM => {
        '='  => 'OR',
        '!=' => 'AND'
    },
    DATE => {
        'IS' => 'OR',
        'IS NOT' => 'OR',
        '='  => 'OR',
        '>=' => 'AND',
        '<=' => 'AND',
        '>'  => 'AND',
        '<'  => 'AND'
    },
    STRING => {
        '='        => 'OR',
        '!='       => 'AND',
        'LIKE'     => 'AND',
        'NOT LIKE' => 'AND'
    },
    QUEUE => {
         '='        => 'OR',
         '!='       => 'AND',
         'LIKE'     => 'OR',
         'NOT LIKE' => 'AND'
    },
    TRANSFIELD   => 'AND',
    TRANSDATE    => 'AND',
    LINK         => 'OR',
    LINKFIELD    => 'AND',
    TARGET       => 'AND',
    BASE         => 'AND',
    WATCHERFIELD => {
        '='        => 'OR',
        '!='       => 'AND',
        'LIKE'     => 'OR',
        'NOT LIKE' => 'AND'
    },

    HASATTRIBUTE => {
        '='        => 'AND',
        '!='       => 'AND',
    },

    CUSTOMFIELD => 'OR',
);

sub FIELDS     { return \%FIELD_METADATA }

our @SORTFIELDS = qw(id Status
    Queue Subject
    Owner Created Due Starts Started
    Told
    Resolved LastUpdated Priority TimeWorked TimeLeft);

=head2 SortFields

Returns the list of fields that lists of tickets can easily be sorted by

=cut

sub SortFields {
    my $self = shift;
    return (@SORTFIELDS);
}


# BEGIN SQL STUFF *********************************


sub CleanSlate {
    my $self = shift;
    $self->SUPER::CleanSlate( @_ );
    delete $self->{$_} foreach qw(
        _sql_cf_alias
        _sql_group_members_aliases
        _sql_object_cfv_alias
        _sql_role_group_aliases
        _sql_trattachalias
        _sql_u_watchers_alias_for_sort
        _sql_u_watchers_aliases
        _sql_current_user_can_see_applied
    );
}

=head1 Limit Helper Routines

These routines are the targets of a dispatch table depending on the
type of field.  They all share the same signature:

  my ($self,$field,$op,$value,@rest) = @_;

The values in @rest should be suitable for passing directly to
DBIx::SearchBuilder::Limit.

Essentially they are an expanded/broken out (and much simplified)
version of what ProcessRestrictions used to do.  They're also much
more clearly delineated by the TYPE of field being processed.

=head2 _IdLimit

Handle ID field.

=cut

sub _IdLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    if ( $value eq '__Bookmarked__' ) {
        return $sb->_BookmarkLimit( $field, $op, $value, @rest );
    } else {
        return $sb->_IntLimit( $field, $op, $value, @rest );
    }
}

sub _BookmarkLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid operator $op for __Bookmarked__ search on $field"
        unless $op =~ /^(=|!=)$/;

    my @bookmarks = $sb->CurrentUser->UserObj->Bookmarks;

    return $sb->Limit(
        FIELD    => $field,
        OPERATOR => $op,
        VALUE    => 0,
        @rest,
    ) unless @bookmarks;

    # as bookmarked tickets can be merged we have to use a join
    # but it should be pretty lightweight
    my $tickets_alias = $sb->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Tickets',
        FIELD2 => 'EffectiveId',
    );

    $op = $op eq '='? 'IN': 'NOT IN';
    $sb->Limit(
        ALIAS    => $tickets_alias,
        FIELD    => 'id',
        OPERATOR => $op,
        VALUE    => [ @bookmarks ],
        @rest,
    );
}

=head2 _EnumLimit

Handle Fields which are limited to certain values, and potentially
need to be looked up from another class.

This subroutine actually handles two different kinds of fields.  For
some the user is responsible for limiting the values.  (i.e. Status,
Type).

For others, the value specified by the user will be looked by via
specified class.

Meta Data:
  name of class to lookup in (Optional)

=cut

sub _EnumLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # SQL::Statement changes != to <>.  (Can we remove this now?)
    $op = "!=" if $op eq "<>";

    die "Invalid Operation: $op for $field"
        unless $op eq "="
        or $op     eq "!=";

    my $meta = $FIELD_METADATA{$field};
    if ( defined $meta->[1] && defined $value && $value !~ /^\d+$/ ) {
        my $class = "RT::" . $meta->[1];
        my $o     = $class->new( $sb->CurrentUser );
        $o->Load($value);
        $value = $o->Id || 0;
    } elsif ( $field eq "Type" ) {
        $value = lc $value if $value =~ /^(ticket|approval|reminder)$/i;
    }
    $sb->Limit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _IntLimit

Handle fields where the values are limited to integers.  (For example,
Priority, TimeWorked.)

Meta Data:
  None

=cut

sub _IntLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    my $is_a_like = $op =~ /MATCHES|ENDSWITH|STARTSWITH|LIKE/i;

    # We want to support <id LIKE '1%'> for ticket autocomplete,
    # but we need to explicitly typecast on Postgres
    if ( $is_a_like && RT->Config->Get('DatabaseType') eq 'Pg' ) {
        return $sb->Limit(
            FUNCTION => "CAST(main.$field AS TEXT)",
            OPERATOR => $op,
            VALUE    => $value,
            @rest,
        );
    }

    $sb->Limit(
        FIELD    => $field,
        VALUE    => $value,
        OPERATOR => $op,
        @rest,
    );
}

=head2 _LinkLimit

Handle fields which deal with links between tickets.  (MemberOf, DependsOn)

Meta Data:
  1: Direction (From, To)
  2: Link Type (MemberOf, DependsOn, RefersTo)

=cut

sub _LinkLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    my $meta = $FIELD_METADATA{$field};
    die "Invalid Operator $op for $field" unless $op =~ /^(=|!=|IS|IS NOT)$/io;

    my $is_negative = 0;
    if ( $op eq '!=' || $op =~ /\bNOT\b/i ) {
        $is_negative = 1;
    }
    my $is_null = 0;
    $is_null = 1 if !$value || $value =~ /^null$/io;

    my $direction = $meta->[1] || '';
    my ($matchfield, $linkfield) = ('', '');
    if ( $direction eq 'To' ) {
        ($matchfield, $linkfield) = ("Target", "Base");
    }
    elsif ( $direction eq 'From' ) {
        ($matchfield, $linkfield) = ("Base", "Target");
    }
    elsif ( $direction ) {
        die "Invalid link direction '$direction' for $field\n";
    } else {
        $sb->_OpenParen;
        $sb->_LinkLimit( 'LinkedTo', $op, $value, @rest );
        $sb->_LinkLimit(
            'LinkedFrom', $op, $value, @rest,
            ENTRYAGGREGATOR => (($is_negative && $is_null) || (!$is_null && !$is_negative))? 'OR': 'AND',
        );
        $sb->_CloseParen;
        return;
    }

    my $is_local = 1;
    if ( $is_null ) {
        $op = ($op =~ /^(=|IS)$/i)? 'IS': 'IS NOT';
    }
    elsif ( $value =~ /\D/ ) {
        $value = RT::URI->new( $sb->CurrentUser )->CanonicalizeURI( $value );
        $is_local = 0;
    }
    $matchfield = "Local$matchfield" if $is_local;

#For doing a left join to find "unlinked tickets" we want to generate a query that looks like this
#    SELECT main.* FROM Tickets main
#        LEFT JOIN Links Links_1 ON (     (Links_1.Type = 'MemberOf')
#                                      AND(main.id = Links_1.LocalTarget))
#        WHERE Links_1.LocalBase IS NULL;

    if ( $is_null ) {
        my $linkalias = $sb->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Links',
            FIELD2 => 'Local' . $linkfield
        );
        $sb->Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        ) if $meta->[2];
        $sb->Limit(
            @rest,
            ALIAS      => $linkalias,
            FIELD      => $matchfield,
            OPERATOR   => $op,
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
        );
    }
    else {
        my $linkalias = $sb->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Links',
            FIELD2 => 'Local' . $linkfield
        );
        $sb->Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        ) if $meta->[2];
        $sb->Limit(
            LEFTJOIN => $linkalias,
            FIELD    => $matchfield,
            OPERATOR => '=',
            VALUE    => $value,
        );
        $sb->Limit(
            @rest,
            ALIAS      => $linkalias,
            FIELD      => $matchfield,
            OPERATOR   => $is_negative? 'IS': 'IS NOT',
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
        );
    }
}

=head2 _DateLimit

Handle date fields.  (Created, LastTold..)

Meta Data:
  1: type of link.  (Probably not necessary.)

=cut

sub _DateLimit {
    my ( $sb, $field, $op, $value, %rest ) = @_;

    die "Invalid Date Op: $op"
        unless $op =~ /^(=|>|<|>=|<=|IS(\s+NOT)?)$/i;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Meta Data for $field"
        unless ( defined $meta->[1] );

    if ( $op =~ /^(IS(\s+NOT)?)$/i) {
        return $sb->Limit(
            FUNCTION => $sb->NotSetDateToNullFunction,
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => "NULL",
            %rest,
        );
    }

    if ( my $subkey = $rest{SUBKEY} ) {
        if ( $subkey eq 'DayOfWeek' && $op !~ /IS/i && $value =~ /[^0-9]/ ) {
            for ( my $i = 0; $i < @RT::Date::DAYS_OF_WEEK; $i++ ) {
                # Use a case-insensitive regex for better matching across
                # locales since we don't have fc() and lc() is worse.  Really
                # we should be doing Unicode normalization too, but we don't do
                # that elsewhere in RT.
                # 
                # XXX I18N: Replace the regex with fc() once we're guaranteed 5.16.
                next unless lc $RT::Date::DAYS_OF_WEEK[ $i ] eq lc $value
                         or $sb->CurrentUser->loc($RT::Date::DAYS_OF_WEEK[ $i ]) =~ /^\Q$value\E$/i;

                $value = $i; last;
            }
            return $sb->Limit( FIELD => 'id', VALUE => 0, %rest )
                if $value =~ /[^0-9]/;
        }
        elsif ( $subkey eq 'Month' && $op !~ /IS/i && $value =~ /[^0-9]/ ) {
            for ( my $i = 0; $i < @RT::Date::MONTHS; $i++ ) {
                # Use a case-insensitive regex for better matching across
                # locales since we don't have fc() and lc() is worse.  Really
                # we should be doing Unicode normalization too, but we don't do
                # that elsewhere in RT.
                # 
                # XXX I18N: Replace the regex with fc() once we're guaranteed 5.16.
                next unless lc $RT::Date::MONTHS[ $i ] eq lc $value
                         or $sb->CurrentUser->loc($RT::Date::MONTHS[ $i ]) =~ /^\Q$value\E$/i;

                $value = $i + 1; last;
            }
            return $sb->Limit( FIELD => 'id', VALUE => 0, %rest )
                if $value =~ /[^0-9]/;
        }

        my $tz;
        if ( RT->Config->Get('ChartsTimezonesInDB') ) {
            my $to = $sb->CurrentUser->UserObj->Timezone
                || RT->Config->Get('Timezone');
            $tz = { From => 'UTC', To => $to }
                if $to && lc $to ne 'utc';
        }

        # $subkey is validated by DateTimeFunction
        my $function = $RT::Handle->DateTimeFunction(
            Type     => $subkey,
            Field    => $sb->NotSetDateToNullFunction,
            Timezone => $tz,
        );

        return $sb->Limit(
            FUNCTION => $function,
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => $value,
            %rest,
        );
    }

    my $date = RT::Date->new( $sb->CurrentUser );
    $date->Set( Format => 'unknown', Value => $value );

    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $sb->_OpenParen;

        $sb->Limit(
            FIELD    => $meta->[1],
            OPERATOR => ">=",
            VALUE    => $daystart,
            %rest,
        );

        $sb->Limit(
            FIELD    => $meta->[1],
            OPERATOR => "<",
            VALUE    => $dayend,
            %rest,
            ENTRYAGGREGATOR => 'AND',
        );

        $sb->_CloseParen;

    }
    else {
        $sb->Limit(
            FUNCTION => $sb->NotSetDateToNullFunction,
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => $date->ISO,
            %rest,
        );
    }
}

=head2 _StringLimit

Handle simple fields which are just strings.  (Subject,Type)

Meta Data:
  None

=cut

sub _StringLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # FIXME:
    # Valid Operators:
    #  =, !=, LIKE, NOT LIKE
    if ( RT->Config->Get('DatabaseType') eq 'Oracle'
        && (!defined $value || !length $value)
        && lc($op) ne 'is' && lc($op) ne 'is not'
    ) {
        if ($op eq '!=' || $op =~ /^NOT\s/i) {
            $op = 'IS NOT';
        } else {
            $op = 'IS';
        }
        $value = 'NULL';
    }

    if ($field eq "Status") {
        $value = lc $value;
    }

    $sb->Limit(
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
        @rest,
    );
}

=head2 _QueueLimit

Handle Queue field supporting both "is" and "match".

Input should be a queue name or a partial string.

=cut

sub _QueueLimit {
    my ($sb, $field, $op, $value, @rest ) = @_;

    if ($op eq 'LIKE' || $op eq 'NOT LIKE') {
        my $alias = $sb->{_sql_aliases}{queues} ||= $sb->Join(
            ALIAS1 => 'main',
            FIELD1 => 'Queue',
            TABLE2 => 'Queues',
            FIELD2 => 'id',
        );

        return $sb->Limit(
           ALIAS         => $alias,
           FIELD         => 'Name',
           OPERATOR      => $op,
           VALUE         => $value,
           CASESENSITIVE => 0,
           @rest,
       );

    }

    my $o = RT::Queue->new( $sb->CurrentUser );
    $o->Load($value);
    $value = $o->Id || 0;
    $sb->Limit(
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
        @rest,
    );
}

=head2 _TransDateLimit

Handle fields limiting based on Transaction Date.

The inpupt value must be in a format parseable by Time::ParseDate

Meta Data:
  None

=cut

# This routine should really be factored into translimit.
sub _TransDateLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # See the comments for TransLimit, they apply here too

    my $txn_alias = $sb->JoinTransactions;

    my $date = RT::Date->new( $sb->CurrentUser );
    $date->Set( Format => 'unknown', Value => $value );

    $sb->_OpenParen;
    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->SetToMidnight( Timezone => 'server' );
        my $daystart = $date->ISO;
        $date->AddDay;
        my $dayend = $date->ISO;

        $sb->Limit(
            ALIAS         => $txn_alias,
            FIELD         => 'Created',
            OPERATOR      => ">=",
            VALUE         => $daystart,
            @rest
        );
        $sb->Limit(
            ALIAS         => $txn_alias,
            FIELD         => 'Created',
            OPERATOR      => "<=",
            VALUE         => $dayend,
            @rest,
            ENTRYAGGREGATOR => 'AND',
        );

    }

    # not searching for a single day
    else {

        #Search for the right field
        $sb->Limit(
            ALIAS         => $txn_alias,
            FIELD         => 'Created',
            OPERATOR      => $op,
            VALUE         => $date->ISO,
            @rest
        );
    }

    $sb->_CloseParen;
}

sub _TransCreatorLimit {
    my ( $sb, $field, $op, $value, @rest ) = @_;
    $op = "!=" if $op eq "<>";
    die "Invalid Operation: $op for $field" unless $op eq "=" or $op eq "!=";

    # See the comments for TransLimit, they apply here too
    my $txn_alias = $sb->JoinTransactions;
    if ( defined $value && $value !~ /^\d+$/ ) {
        my $u = RT::User->new( $sb->CurrentUser );
        $u->Load($value);
        $value = $u->id || 0;
    }
    $sb->Limit( ALIAS => $txn_alias, FIELD => 'Creator', OPERATOR => $op, VALUE => $value, @rest );
}

=head2 _TransLimit

Limit based on the ContentType or the Filename of a transaction.

=cut

sub _TransLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    my $txn_alias = $self->JoinTransactions;
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->Join(
            TYPE   => 'LEFT', # not all txns have an attachment
            ALIAS1 => $txn_alias,
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->Limit(
        %rest,
        ALIAS         => $self->{_sql_trattachalias},
        FIELD         => $field,
        OPERATOR      => $op,
        VALUE         => $value,
        CASESENSITIVE => 0,
    );
}

=head2 _TransContentLimit

Limit based on the Content of a transaction.

=cut

sub _TransContentLimit {

    # Content search

    # If only this was this simple.  We've got to do something
    # complicated here:

    #Basically, we want to make sure that the limits apply to
    #the same attachment, rather than just another attachment
    #for the same ticket, no matter how many clauses we lump
    #on.

    # In the SQL, we might have
    #       (( Content = foo ) or ( Content = bar AND Content = baz ))
    # The AND group should share the same Alias.

    # Actually, maybe it doesn't matter.  We use the same alias and it
    # works itself out? (er.. different.)

    # Steal more from _ProcessRestrictions

    # FIXME: Maybe look at the previous FooLimit call, and if it was a
    # TransLimit and EntryAggregator == AND, reuse the Aliases?

    # Or better - store the aliases on a per subclause basis - since
    # those are going to be the things we want to relate to each other,
    # anyway.

    # maybe we should not allow certain kinds of aggregation of these
    # clauses and do a psuedo regex instead? - the problem is getting
    # them all into the same subclause when you have (A op B op C) - the
    # way they get parsed in the tree they're in different subclauses.

    my ( $self, $field, $op, $value, %rest ) = @_;
    $field = 'Content' if $field =~ /\W/;

    my $config = RT->Config->Get('FullTextSearch') || {};
    unless ( $config->{'Enable'} ) {
        $self->Limit( %rest, FIELD => 'id', VALUE => 0 );
        return;
    }

    my $txn_alias = $self->JoinTransactions;
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->Join(
            TYPE   => 'LEFT', # not all txns have an attachment
            ALIAS1 => $txn_alias,
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->_OpenParen;
    if ( $config->{'Indexed'} ) {
        my $db_type = RT->Config->Get('DatabaseType');

        my $alias;
        if ( $config->{'Table'} and $config->{'Table'} ne "Attachments") {
            $alias = $self->{'_sql_aliases'}{'full_text'} ||= $self->Join(
                TYPE   => 'LEFT',
                ALIAS1 => $self->{'_sql_trattachalias'},
                FIELD1 => 'id',
                TABLE2 => $config->{'Table'},
                FIELD2 => 'id',
            );
        } else {
            $alias = $self->{'_sql_trattachalias'};
        }

        #XXX: handle negative searches
        my $index = $config->{'Column'};
        if ( $db_type eq 'Oracle' ) {
            my $dbh = $RT::Handle->dbh;
            my $alias = $self->{_sql_trattachalias};
            $self->Limit(
                %rest,
                FUNCTION      => "CONTAINS( $alias.$field, ".$dbh->quote($value) .")",
                OPERATOR      => '>',
                VALUE         => 0,
                QUOTEVALUE    => 0,
                CASESENSITIVE => 1,
            );
            # this is required to trick DBIx::SB's LEFT JOINS optimizer
            # into deciding that join is redundant as it is
            $self->Limit(
                ENTRYAGGREGATOR => 'AND',
                ALIAS           => $self->{_sql_trattachalias},
                FIELD           => 'Content',
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
            );
        }
        elsif ( $db_type eq 'Pg' ) {
            my $dbh = $RT::Handle->dbh;
            $self->Limit(
                %rest,
                ALIAS       => $alias,
                FIELD       => $index,
                OPERATOR    => '@@',
                VALUE       => 'plainto_tsquery('. $dbh->quote($value) .')',
                QUOTEVALUE  => 0,
            );
        }
        elsif ( $db_type eq 'mysql' and not $config->{Sphinx}) {
            my $dbh = $RT::Handle->dbh;
            $self->Limit(
                %rest,
                FUNCTION    => "MATCH($alias.Content)",
                OPERATOR    => 'AGAINST',
                VALUE       => "(". $dbh->quote($value) ." IN BOOLEAN MODE)",
                QUOTEVALUE  => 0,
            );
            # As with Oracle, above, this forces the LEFT JOINs into
            # JOINS, which allows the FULLTEXT index to be used.
            # Orthogonally, the IS NOT NULL clause also helps the
            # optimizer decide to use the index.
            $self->Limit(
                ENTRYAGGREGATOR => 'AND',
                ALIAS           => $alias,
                FIELD           => "Content",
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
            );
        }
        elsif ( $db_type eq 'mysql' ) {
            # XXX: We could theoretically skip the join to Attachments,
            # and have Sphinx simply index and group by the TicketId,
            # and join Ticket.id to that attribute, which would be much
            # more efficient -- however, this is only a possibility if
            # there are no other transaction limits.

            # This is a special character.  Note that \ does not escape
            # itself (in Sphinx 2.1.0, at least), so 'foo\;bar' becoming
            # 'foo\\;bar' is not a vulnerability, and is still parsed as
            # "foo, \, ;, then bar".  Happily, the default mode is
            # "all", meaning that boolean operators are not special.
            $value =~ s/;/\\;/g;

            my $max = $config->{'MaxMatches'};
            $self->Limit(
                %rest,
                ALIAS       => $alias,
                FIELD       => 'query',
                OPERATOR    => '=',
                VALUE       => "$value;limit=$max;maxmatches=$max",
            );
        }
    } else {
        $self->Limit(
            %rest,
            ALIAS    => $txn_alias,
            FIELD    => 'Type',
            OPERATOR => 'NOT IN',
            VALUE    => ['EmailRecord', 'CommentEmailRecord'],
        );
        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            ALIAS           => $self->{_sql_trattachalias},
            FIELD           => $field,
            OPERATOR        => $op,
            VALUE           => $value,
            CASESENSITIVE   => 0,
        );
    }
    if ( RT->Config->Get('DontSearchFileAttachments') ) {
        $self->Limit(
            ENTRYAGGREGATOR => 'AND',
            ALIAS           => $self->{_sql_trattachalias},
            FIELD           => 'Filename',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
        );
    }
    $self->_CloseParen;
}

=head2 _CustomRoleDecipher

Try and turn a custom role descriptor (e.g. C<CustomRole.{Engineer}>) into
(role, column, original name).

=cut

sub _CustomRoleDecipher {
    my ($self, $string) = @_;

    my ($field, $column) = ($string =~ /^\{(.+)\}(?:\.(\w+))?$/);

    my $role;

    if ( $field =~ /\D/ ) {
        my $roles = RT::CustomRoles->new( $self->CurrentUser );
        $roles->Limit( FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0 );

        # custom roles are named uniquely, but just in case there are
        # multiple matches, bail out as we don't know which one to use
        $role = $roles->First;
        if ( $role ) {
            $role = undef if $roles->Next;
        }
    }
    else {
        $role = RT::CustomRole->new( $self->CurrentUser );
        $role->Load( $field );
    }

    return ($role, $column, $field);
}

=head2 _WatcherLimit

Handle watcher limits.  (Requestor, CC, etc..)

Meta Data:
  1: Field to query on



=cut

sub _WatcherLimit {
    my $self  = shift;
    my $field = shift;
    my $op    = shift;
    my $value = shift;
    my %rest  = (@_);

    my $meta = $FIELD_METADATA{ $field };
    my $type = $meta->[1] || '';
    my $class = $meta->[2] || 'Ticket';
    my $column = $rest{SUBKEY};

    if ($field eq 'CustomRole') {
        my ($role, $col, $original_name) = $self->_CustomRoleDecipher( $column );
        $column = $col || 'id';
        $type = $role ? $role->GroupType : $original_name;
    }

    # Bail if the subfield is not allowed
    if (    $column
        and not grep { $_ eq $column } @{$SEARCHABLE_SUBFIELDS{'User'}})
    {
        die "Invalid watcher subfield: '$column'";
    }

    $self->RoleLimit(
        TYPE      => $type,
        CLASS     => "RT::$class",
        FIELD     => $column,
        OPERATOR  => $op,
        VALUE     => $value,
        SUBCLAUSE => "ticketsql",
        %rest,
    );
}

=head2 _WatcherMembershipLimit

Handle watcher membership limits, i.e. whether the watcher belongs to a
specific group or not.

Meta Data:
  1: Role to query on

=cut

sub _WatcherMembershipLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    # we don't support anything but '='
    die "Invalid $field Op: $op"
        unless $op =~ /^=$/;

    unless ( $value =~ /^\d+$/ ) {
        my $group = RT::Group->new( $self->CurrentUser );
        $group->LoadUserDefinedGroup( $value );
        $value = $group->id || 0;
    }

    my $meta = $FIELD_METADATA{$field};
    my $type = $meta->[1] || '';

    my ($members_alias, $members_column);
    if ( $type eq 'Owner' ) {
        ($members_alias, $members_column) = ('main', 'Owner');
    } else {
        (undef, undef, $members_alias) = $self->_WatcherJoin( New => 1, Name => $type );
        $members_column = 'id';
    }

    my $cgm_alias = $self->Join(
        ALIAS1          => $members_alias,
        FIELD1          => $members_column,
        TABLE2          => 'CachedGroupMembers',
        FIELD2          => 'MemberId',
    );
    $self->Limit(
        LEFTJOIN => $cgm_alias,
        ALIAS => $cgm_alias,
        FIELD => 'Disabled',
        VALUE => 0,
    );

    $self->Limit(
        ALIAS    => $cgm_alias,
        FIELD    => 'GroupId',
        VALUE    => $value,
        OPERATOR => $op,
        %rest,
    );
}

=head2 _CustomFieldDecipher

Try and turn a CF descriptor into (cfid, cfname) object pair.

Takes an optional second parameter of the CF LookupType, defaults to Ticket CFs.

=cut

sub _CustomFieldDecipher {
    my ($self, $string, $lookuptype) = @_;
    $lookuptype ||= $self->_SingularClass->CustomFieldLookupType;

    my ($object, $field, $column) = ($string =~ /^(?:(.+?)\.)?\{(.+)\}(?:\.(Content|LargeContent))?$/);
    $field ||= ($string =~ /^\{(.*?)\}$/)[0] || $string;

    my ($cf, $applied_to);

    if ( $object ) {
        my $record_class = RT::CustomField->RecordClassFromLookupType($lookuptype);
        $applied_to = $record_class->new( $self->CurrentUser );
        $applied_to->Load( $object );

        if ( $applied_to->id ) {
            RT->Logger->debug("Limiting to CFs identified by '$field' applied to $record_class #@{[$applied_to->id]} (loaded via '$object')");
        }
        else {
            RT->Logger->warning("$record_class '$object' doesn't exist, parsed from '$string'");
            $object = 0;
            undef $applied_to;
        }
    }

    if ( $field =~ /\D/ ) {
        $object ||= '';
        my $cfs = RT::CustomFields->new( $self->CurrentUser );
        $cfs->Limit( FIELD => 'Name', VALUE => $field, CASESENSITIVE => 0 );
        $cfs->LimitToLookupType($lookuptype);

        if ($applied_to) {
            $cfs->SetContextObject($applied_to);
            $cfs->LimitToObjectId($applied_to->id);
        }

        # if there is more then one field the current user can
        # see with the same name then we shouldn't return cf object
        # as we don't know which one to use
        $cf = $cfs->First;
        if ( $cf ) {
            $cf = undef if $cfs->Next;
        }
    }
    else {
        $cf = RT::CustomField->new( $self->CurrentUser );
        $cf->Load( $field );
        $cf->SetContextObject($applied_to)
            if $cf->id and $applied_to;
    }

    return ($object, $field, $cf, $column);
}

=head2 _CustomFieldLimit

Limit based on CustomFields

Meta Data:
  none

=cut

sub _CustomFieldLimit {
    my ( $self, $_field, $op, $value, %rest ) = @_;

    my $meta  = $FIELD_METADATA{ $_field };
    my $class = $meta->[1] || 'Ticket';
    my $type  = "RT::$class"->CustomFieldLookupType;

    my $field = $rest{'SUBKEY'} || die "No field specified";

    # For our sanity, we can only limit on one object at a time

    my ($object, $cfid, $cf, $column);
    ($object, $field, $cf, $column) = $self->_CustomFieldDecipher( $field, $type );


    $self->_LimitCustomField(
        %rest,
        LOOKUPTYPE  => $type,
        CUSTOMFIELD => $cf || $field,
        KEY      => $cf ? $cf->id : "$type-$object.$field",
        OPERATOR => $op,
        VALUE    => $value,
        COLUMN   => $column,
        SUBCLAUSE => "ticketsql",
    );
}

sub _CustomFieldJoinByName {
    my $self = shift;
    my ($ObjectAlias, $cf, $type) = @_;

    my ($ocfvalias, $CFs, $ocfalias) = $self->SUPER::_CustomFieldJoinByName(@_);
    $self->Limit(
        LEFTJOIN        => $ocfalias,
        ENTRYAGGREGATOR => 'OR',
        FIELD           => 'ObjectId',
        VALUE           => 'main.Queue',
        QUOTEVALUE      => 0,
    );
    return ($ocfvalias, $CFs, $ocfalias);
}

sub _HasAttributeLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    my $alias = $self->Join(
        TYPE   => 'LEFT',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Attributes',
        FIELD2 => 'ObjectId',
    );
    $self->Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
        ENTRYAGGREGATOR => 'AND'
    );
    $self->Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'Name',
        OPERATOR        => $op,
        VALUE           => $value,
        ENTRYAGGREGATOR => 'AND'
    );
    $self->Limit(
        %rest,
        ALIAS      => $alias,
        FIELD      => 'id',
        OPERATOR   => $FIELD_METADATA{$field}->[1]? 'IS NOT': 'IS',
        VALUE      => 'NULL',
        QUOTEVALUE => 0,
    );
}


sub _LifecycleLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    die "Invalid Operator $op for $field" if $op =~ /^(IS|IS NOT)$/io;
    my $queue = $self->{_sql_aliases}{queues} ||= $_[0]->Join(
        ALIAS1 => 'main',
        FIELD1 => 'Queue',
        TABLE2 => 'Queues',
        FIELD2 => 'id',
    );

    $self->Limit(
        ALIAS    => $queue,
        FIELD    => 'Lifecycle',
        OPERATOR => $op,
        VALUE    => $value,
        %rest,
    );
}

# End Helper Functions

# End of SQL Stuff -------------------------------------------------


=head2 OrderByCols ARRAY

A modified version of the OrderBy method which automatically joins where
C<ALIAS> is set to the name of a watcher type.

=cut

sub OrderByCols {
    my $self = shift;
    my @args = @_;
    my $clause;
    my @res   = ();
    my $order = 0;

    foreach my $row (@args) {
        if ( $row->{ALIAS} ) {
            push @res, $row;
            next;
        }
        if ( $row->{FIELD} !~ /\./ ) {
            my $meta = $FIELD_METADATA{ $row->{FIELD} };
            unless ( $meta ) {
                push @res, $row;
                next;
            }

            if ( $meta->[0] eq 'QUEUE' ) {
                my $alias = $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => 'main',
                    FIELD1 => $row->{'FIELD'},
                    TABLE2 => 'Queues',
                    FIELD2 => 'id',
                );
                push @res, { %$row, ALIAS => $alias, FIELD => "Name", CASESENSITIVE => 0 };
            } elsif ( ( $meta->[0] eq 'ENUM' && ($meta->[1]||'') eq 'User' )
                || ( $meta->[0] eq 'WATCHERFIELD' && ($meta->[1]||'') eq 'Owner' )
            ) {
                my $alias = $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => 'main',
                    FIELD1 => $row->{'FIELD'},
                    TABLE2 => 'Users',
                    FIELD2 => 'id',
                );
                push @res, { %$row, ALIAS => $alias, FIELD => "Name", CASESENSITIVE => 0 };
            } else {
                push @res, $row;
            }
            next;
        }

        my ( $field, $subkey ) = split /\./, $row->{FIELD}, 2;
        my $meta = $FIELD_METADATA{$field};
        if ( defined $meta->[0] && $meta->[0] eq 'WATCHERFIELD' ) {
            my $type = $meta->[1] || '';
            my $class = $meta->[2] || 'Ticket';
            my $column = $subkey;

            if ($field eq 'CustomRole') {
                my ($role, $col, $original_name) = $self->_CustomRoleDecipher( $column );
                $column = $col || 'id';
                $type = $role ? $role->GroupType : $original_name;
            }

            # cache alias as we want to use one alias per watcher type for sorting
            my $cache_key = join "-", $type, $class;
            my $users = $self->{_sql_u_watchers_alias_for_sort}{ $cache_key };
            unless ( $users ) {
                $self->{_sql_u_watchers_alias_for_sort}{ $cache_key }
                    = $users = ( $self->_WatcherJoin( Name => $type, Class => "RT::" . $class ) )[2];
            }
            push @res, { %$row, ALIAS => $users, FIELD => $column };
       } elsif ( defined $meta->[0] && $meta->[0] eq 'CUSTOMFIELD' ) {
           my ($object, $field, $cf, $column) = $self->_CustomFieldDecipher( $subkey );
           my $cfkey = $cf ? $cf->id : "$object.$field";
           push @res, $self->_OrderByCF( $row, $cfkey, ($cf || $field) );
       } elsif ( $field eq "Custom" && $subkey eq "Ownership") {
           # PAW logic is "reversed"
           my $order = "ASC";
           if (exists $row->{ORDER} ) {
               my $o = $row->{ORDER};
               delete $row->{ORDER};
               $order = "DESC" if $o =~ /asc/i;
           }

           # Ticket.Owner    1 0 X
           # Unowned Tickets 0 1 X
           # Else            0 0 X

           foreach my $uid ( $self->CurrentUser->Id, RT->Nobody->Id ) {
               if ( RT->Config->Get('DatabaseType') eq 'Oracle' ) {
                   my $f = ($row->{'ALIAS'} || 'main') .'.Owner';
                   push @res, {
                       %$row,
                       FIELD => undef,
                       ALIAS => '',
                       FUNCTION => "CASE WHEN $f=$uid THEN 1 ELSE 0 END",
                       ORDER => $order
                   };
               } else {
                   push @res, {
                       %$row,
                       FIELD => undef,
                       FUNCTION => "Owner=$uid",
                       ORDER => $order
                   };
               }
           }

           push @res, { %$row, FIELD => "Priority", ORDER => $order } ;
       }
       else {
           push @res, $row;
       }
    }
    return $self->SUPER::OrderByCols(@res);
}

sub _OpenParen {
    $_[0]->SUPER::_OpenParen( $_[1] || 'ticketsql' );
}
sub _CloseParen {
    $_[0]->SUPER::_CloseParen( $_[1] || 'ticketsql' );
}

sub Limit {
    my $self = shift;
    my %args = @_;
    $self->{'must_redo_search'} = 1;
    delete $self->{'raw_rows'};
    delete $self->{'count_all'};

    if ($self->{'using_restrictions'}) {
        RT->Deprecated( Message => "Mixing old-style LimitFoo methods with Limit is deprecated" );
        $self->LimitField(@_);
    }

    $args{SUBCLAUSE} ||= "ticketsql"
        if $self->{parsing_ticketsql} and not $args{LEFTJOIN};

    $self->{_sql_looking_at}{ lc $args{FIELD} } = 1
        if $args{FIELD} and (not $args{ALIAS} or $args{ALIAS} eq "main");

    $self->SUPER::Limit(%args);
}


=head2 LimitField

Takes a paramhash with the fields FIELD, OPERATOR, VALUE and DESCRIPTION
Generally best called from LimitFoo methods

=cut

sub LimitField {
    my $self = shift;
    my %args = (
        FIELD       => undef,
        OPERATOR    => '=',
        VALUE       => undef,
        DESCRIPTION => undef,
        @_
    );
    $args{'DESCRIPTION'} = $self->loc(
        "[_1] [_2] [_3]",  $args{'FIELD'},
        $args{'OPERATOR'}, $args{'VALUE'}
        )
        if ( !defined $args{'DESCRIPTION'} );


    if ($self->_isLimited > 1) {
        RT->Deprecated( Message => "Mixing old-style LimitFoo methods with Limit is deprecated" );
    }
    $self->{using_restrictions} = 1;

    my $index = $self->_NextIndex;

# make the TicketRestrictions hash the equivalent of whatever we just passed in;

    %{ $self->{'TicketRestrictions'}{$index} } = %args;

    $self->{'RecalcTicketLimits'} = 1;

    return ($index);
}




=head2 LimitQueue

LimitQueue takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=. (It defaults to =).
VALUE is a queue id or Name.


=cut

sub LimitQueue {
    my $self = shift;
    my %args = (
        VALUE    => undef,
        OPERATOR => '=',
        @_
    );

    #TODO  VALUE should also take queue objects
    if ( defined $args{'VALUE'} && $args{'VALUE'} !~ /^\d+$/ ) {
        my $queue = RT::Queue->new( $self->CurrentUser );
        $queue->Load( $args{'VALUE'} );
        $args{'VALUE'} = $queue->Id;
    }

    # What if they pass in an Id?  Check for isNum() and convert to
    # string.

    #TODO check for a valid queue here

    $self->LimitField(
        FIELD       => 'Queue',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join(
            ' ', $self->loc('Queue'), $args{'OPERATOR'}, $args{'VALUE'},
        ),
    );

}



=head2 LimitStatus

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a status.

RT adds Status != 'deleted' until object has
allow_deleted_search internal property set.
$tickets->{'allow_deleted_search'} = 1;
$tickets->LimitStatus( VALUE => 'deleted' );

=cut

sub LimitStatus {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );
    $self->LimitField(
        FIELD       => 'Status',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Status'), $args{'OPERATOR'},
            $self->loc( $args{'VALUE'} ) ),
    );
}

=head2 LimitToActiveStatus

Limits the status to L<RT::Queue/ActiveStatusArray>

TODO: make this respect lifecycles for the queues associated with the search

=cut

sub LimitToActiveStatus {
    my $self = shift;

    my @active = RT::Queue->ActiveStatusArray();
    for my $active (@active) {
        $self->LimitStatus(
            VALUE => $active,
        );
    }
}

=head2 LimitToInactiveStatus

Limits the status to L<RT::Queue/InactiveStatusArray>

TODO: make this respect lifecycles for the queues associated with the search

=cut

sub LimitToInactiveStatus {
    my $self = shift;

    my @active = RT::Queue->InactiveStatusArray();
    for my $active (@active) {
        $self->LimitStatus(
            VALUE => $active,
        );
    }
}

=head2 IgnoreType

If called, this search will not automatically limit the set of results found
to tickets of type "Ticket". Tickets of other types, such as "project" and
"approval" will be found.

=cut

sub IgnoreType {
    my $self = shift;

    # Instead of faking a Limit that later gets ignored, fake up the
    # fact that we're already looking at type, so that the check in
    # FromSQL goes down the right branch

    #  $self->LimitType(VALUE => '__any');
    $self->{_sql_looking_at}{type} = 1;
}



=head2 LimitType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=, it defaults to "=".
VALUE is a string to search for in the type of the ticket.



=cut

sub LimitType {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );
    $self->LimitField(
        FIELD       => 'Type',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Type'), $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}





=head2 LimitSubject

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a string to search for in the subject of the ticket.

=cut

sub LimitSubject {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'Subject',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Subject'), $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}



# Things that can be > < = !=


=head2 LimitId

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a ticket Id to search for

=cut

sub LimitId {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );

    $self->LimitField(
        FIELD       => 'id',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION =>
            join( ' ', $self->loc('Id'), $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}



=head2 LimitPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's priority against

=cut

sub LimitPriority {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'Priority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Priority'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}



=head2 LimitInitialPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's initial priority against


=cut

sub LimitInitialPriority {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'InitialPriority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Initial Priority'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}



=head2 LimitFinalPriority

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's final priority against

=cut

sub LimitFinalPriority {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'FinalPriority',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Final Priority'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}



=head2 LimitTimeWorked

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeWorked attribute

=cut

sub LimitTimeWorked {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'TimeWorked',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Time Worked'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}



=head2 LimitTimeLeft

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, >, < or !=.
VALUE is a value to match the ticket's TimeLeft attribute

=cut

sub LimitTimeLeft {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'TimeLeft',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Time Left'),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}





=head2 LimitContent

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a string to search for in the body of the ticket

=cut

sub LimitContent {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'Content',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Ticket content'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}



=head2 LimitFilename

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a string to search for in the body of the ticket

=cut

sub LimitFilename {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'Filename',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Attachment filename'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}


=head2 LimitContentType

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of =, LIKE, NOT LIKE or !=.
VALUE is a content type to search ticket attachments for

=cut

sub LimitContentType {
    my $self = shift;
    my %args = (@_);
    $self->LimitField(
        FIELD       => 'ContentType',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Ticket content type'), $args{'OPERATOR'},
            $args{'VALUE'}, ),
    );
}





=head2 LimitOwner

Takes a paramhash with the fields OPERATOR and VALUE.
OPERATOR is one of = or !=.
VALUE is a user id.

=cut

sub LimitOwner {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        @_
    );

    my $owner = RT::User->new( $self->CurrentUser );
    $owner->Load( $args{'VALUE'} );

    # FIXME: check for a valid $owner
    $self->LimitField(
        FIELD       => 'Owner',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Owner'), $args{'OPERATOR'}, $owner->Name(), ),
    );

}




=head2 LimitWatcher

  Takes a paramhash with the fields OPERATOR, TYPE and VALUE.
  OPERATOR is one of =, LIKE, NOT LIKE or !=.
  VALUE is a value to match the ticket's watcher email addresses against
  TYPE is the sort of watchers you want to match against. Leave it undef if you want to search all of them


=cut

sub LimitWatcher {
    my $self = shift;
    my %args = (
        OPERATOR => '=',
        VALUE    => undef,
        TYPE     => undef,
        @_
    );

    #build us up a description
    my ( $watcher_type, $desc );
    if ( $args{'TYPE'} ) {
        $watcher_type = $args{'TYPE'};
    }
    else {
        $watcher_type = "Watcher";
    }

    $self->LimitField(
        FIELD       => $watcher_type,
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        TYPE        => $args{'TYPE'},
        DESCRIPTION => join( ' ',
            $self->loc($watcher_type),
            $args{'OPERATOR'}, $args{'VALUE'}, ),
    );
}






=head2 LimitLinkedTo

LimitLinkedTo takes a paramhash with two fields: TYPE and TARGET
TYPE limits the sort of link we want to search on

TYPE = { RefersTo, MemberOf, DependsOn }

TARGET is the id or URI of the TARGET of the link

=cut

sub LimitLinkedTo {
    my $self = shift;
    my %args = (
        TARGET   => undef,
        TYPE     => undef,
        OPERATOR => '=',
        @_
    );

    $self->LimitField(
        FIELD       => 'LinkedTo',
        BASE        => undef,
        TARGET      => $args{'TARGET'},
        TYPE        => $args{'TYPE'},
        DESCRIPTION => $self->loc(
            "Tickets [_1] by [_2]",
            $self->loc( $args{'TYPE'} ),
            $args{'TARGET'}
        ),
        OPERATOR    => $args{'OPERATOR'},
    );
}



=head2 LimitLinkedFrom

LimitLinkedFrom takes a paramhash with two fields: TYPE and BASE
TYPE limits the sort of link we want to search on


BASE is the id or URI of the BASE of the link

=cut

sub LimitLinkedFrom {
    my $self = shift;
    my %args = (
        BASE     => undef,
        TYPE     => undef,
        OPERATOR => '=',
        @_
    );

    # translate RT2 From/To naming to RT3 TicketSQL naming
    my %fromToMap = qw(DependsOn DependentOn
        MemberOf  HasMember
        RefersTo  ReferredToBy);

    my $type = $args{'TYPE'};
    $type = $fromToMap{$type} if exists( $fromToMap{$type} );

    $self->LimitField(
        FIELD       => 'LinkedTo',
        TARGET      => undef,
        BASE        => $args{'BASE'},
        TYPE        => $type,
        DESCRIPTION => $self->loc(
            "Tickets [_1] [_2]",
            $self->loc( $args{'TYPE'} ),
            $args{'BASE'},
        ),
        OPERATOR    => $args{'OPERATOR'},
    );
}


sub LimitMemberOf {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'MemberOf',
    );
}


sub LimitHasMember {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => "$ticket_id",
        TYPE => 'HasMember',
    );

}



sub LimitDependsOn {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'DependsOn',
    );

}



sub LimitDependedOnBy {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => $ticket_id,
        TYPE => 'DependentOn',
    );

}



sub LimitRefersTo {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedTo(
        @_,
        TARGET => $ticket_id,
        TYPE   => 'RefersTo',
    );

}



sub LimitReferredToBy {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->LimitLinkedFrom(
        @_,
        BASE => $ticket_id,
        TYPE => 'ReferredToBy',
    );
}





=head2 LimitDate (FIELD => 'DateField', OPERATOR => $oper, VALUE => $ISODate)

Takes a paramhash with the fields FIELD OPERATOR and VALUE.

OPERATOR is one of > or <
VALUE is a date and time in ISO format in GMT
FIELD is one of Starts, Started, Told, Created, Resolved, LastUpdated

There are also helper functions of the form LimitFIELD that eliminate
the need to pass in a FIELD argument.

=cut

sub LimitDate {
    my $self = shift;
    my %args = (
        FIELD    => undef,
        VALUE    => undef,
        OPERATOR => undef,

        @_
    );

    #Set the description if we didn't get handed it above
    unless ( $args{'DESCRIPTION'} ) {
        $args{'DESCRIPTION'} = $args{'FIELD'} . " "
            . $args{'OPERATOR'} . " "
            . $args{'VALUE'} . " GMT";
    }

    $self->LimitField(%args);

}


sub LimitCreated {
    my $self = shift;
    $self->LimitDate( FIELD => 'Created', @_ );
}

sub LimitDue {
    my $self = shift;
    $self->LimitDate( FIELD => 'Due', @_ );

}

sub LimitStarts {
    my $self = shift;
    $self->LimitDate( FIELD => 'Starts', @_ );

}

sub LimitStarted {
    my $self = shift;
    $self->LimitDate( FIELD => 'Started', @_ );
}

sub LimitResolved {
    my $self = shift;
    $self->LimitDate( FIELD => 'Resolved', @_ );
}

sub LimitTold {
    my $self = shift;
    $self->LimitDate( FIELD => 'Told', @_ );
}

sub LimitLastUpdated {
    my $self = shift;
    $self->LimitDate( FIELD => 'LastUpdated', @_ );
}

#

=head2 LimitTransactionDate (OPERATOR => $oper, VALUE => $ISODate)

Takes a paramhash with the fields FIELD OPERATOR and VALUE.

OPERATOR is one of > or <
VALUE is a date and time in ISO format in GMT


=cut

sub LimitTransactionDate {
    my $self = shift;
    my %args = (
        FIELD    => 'TransactionDate',
        VALUE    => undef,
        OPERATOR => undef,

        @_
    );

    #  <20021217042756.GK28744@pallas.fsck.com>
    #    "Kill It" - Jesse.

    #Set the description if we didn't get handed it above
    unless ( $args{'DESCRIPTION'} ) {
        $args{'DESCRIPTION'} = $args{'FIELD'} . " "
            . $args{'OPERATOR'} . " "
            . $args{'VALUE'} . " GMT";
    }

    $self->LimitField(%args);

}




=head2 LimitCustomField

Takes a paramhash of key/value pairs with the following keys:

=over 4

=item CUSTOMFIELD - CustomField name or id.  If a name is passed, an additional parameter QUEUE may also be passed to distinguish the custom field.

=item OPERATOR - The usual Limit operators

=item VALUE - The value to compare against

=back

=cut

sub LimitCustomField {
    my $self = shift;
    my %args = (
        VALUE       => undef,
        CUSTOMFIELD => undef,
        OPERATOR    => '=',
        DESCRIPTION => undef,
        FIELD       => 'CustomFieldValue',
        QUOTEVALUE  => 1,
        @_
    );

    my $CF = RT::CustomField->new( $self->CurrentUser );
    if ( $args{CUSTOMFIELD} =~ /^\d+$/ ) {
        $CF->Load( $args{CUSTOMFIELD} );
    }
    else {
        $CF->LoadByName(
            Name       => $args{CUSTOMFIELD},
            LookupType => RT::Ticket->CustomFieldLookupType,
            ObjectId   => $args{QUEUE},
        );
        $args{CUSTOMFIELD} = $CF->Id;
    }

    #If we are looking to compare with a null value.
    if ( $args{'OPERATOR'} =~ /^is$/i ) {
        $args{'DESCRIPTION'}
            ||= $self->loc( "Custom field [_1] has no value.", $CF->Name );
    }
    elsif ( $args{'OPERATOR'} =~ /^is not$/i ) {
        $args{'DESCRIPTION'}
            ||= $self->loc( "Custom field [_1] has a value.", $CF->Name );
    }

    # if we're not looking to compare with a null value
    else {
        $args{'DESCRIPTION'} ||= $self->loc( "Custom field [_1] [_2] [_3]",
            $CF->Name, $args{OPERATOR}, $args{VALUE} );
    }

    if ( defined $args{'QUEUE'} && $args{'QUEUE'} =~ /\D/ ) {
        my $QueueObj = RT::Queue->new( $self->CurrentUser );
        $QueueObj->Load( $args{'QUEUE'} );
        $args{'QUEUE'} = $QueueObj->Id;
    }
    delete $args{'QUEUE'} unless defined $args{'QUEUE'} && length $args{'QUEUE'};

    my @rest;
    @rest = ( ENTRYAGGREGATOR => 'AND' )
        if ( $CF->Type eq 'SelectMultiple' );

    $self->LimitField(
        VALUE => $args{VALUE},
        FIELD => "CF"
            .(defined $args{'QUEUE'}? ".$args{'QUEUE'}" : '' )
            .".{" . $CF->Name . "}",
        OPERATOR    => $args{OPERATOR},
        CUSTOMFIELD => 1,
        @rest,
    );

    $self->{'RecalcTicketLimits'} = 1;
}



=head2 _NextIndex

Keep track of the counter for the array of restrictions

=cut

sub _NextIndex {
    my $self = shift;
    return ( $self->{'restriction_index'}++ );
}




sub _Init {
    my $self = shift;
    $self->{'table'}                   = "Tickets";
    $self->{'RecalcTicketLimits'}      = 1;
    $self->{'restriction_index'}       = 1;
    $self->{'primary_key'}             = "id";
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'columns_to_display'};
    $self->SUPER::_Init(@_);

    $self->_InitSQL();
}

sub _InitSQL {
    my $self = shift;
    # Private Member Variables (which should get cleaned)
    $self->{'_sql_transalias'}    = undef;
    $self->{'_sql_trattachalias'} = undef;
    $self->{'_sql_cf_alias'}  = undef;
    $self->{'_sql_object_cfv_alias'}  = undef;
    $self->{'_sql_watcher_join_users_alias'} = undef;
    $self->{'_sql_query'}         = '';
    $self->{'_sql_looking_at'}    = {};
}


sub Count {
    my $self = shift;
    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::Count() );
}


sub CountAll {
    my $self = shift;
    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::CountAll() );
}



=head2 ItemsArrayRef

Returns a reference to the set of all items found in this search

=cut

sub ItemsArrayRef {
    my $self = shift;

    return $self->{'items_array'} if $self->{'items_array'};

    my $placeholder = $self->_ItemsCounter;
    $self->GotoFirstItem();
    while ( my $item = $self->Next ) {
        push( @{ $self->{'items_array'} }, $item );
    }
    $self->GotoItem($placeholder);
    $self->{'items_array'}
        = $self->ItemsOrderBy( $self->{'items_array'} );

    return $self->{'items_array'};
}

sub ItemsArrayRefWindow {
    my $self = shift;
    my $window = shift;

    my @old = ($self->_ItemsCounter, $self->RowsPerPage, $self->FirstRow+1);

    $self->RowsPerPage( $window );
    $self->FirstRow(1);
    $self->GotoFirstItem;

    my @res;
    while ( my $item = $self->Next ) {
        push @res, $item;
    }

    $self->RowsPerPage( $old[1] );
    $self->FirstRow( $old[2] );
    $self->GotoItem( $old[0] );

    return \@res;
}


sub Next {
    my $self = shift;

    $self->_ProcessRestrictions() if ( $self->{'RecalcTicketLimits'} == 1 );

    my $Ticket = $self->SUPER::Next;
    return $Ticket unless $Ticket;

    if ( $Ticket->__Value('Status') eq 'deleted'
        && !$self->{'allow_deleted_search'} )
    {
        return $self->Next;
    }
    elsif ( RT->Config->Get('UseSQLForACLChecks') ) {
        # if we found a ticket with this option enabled then
        # all tickets we found are ACLed, cache this fact
        my $key = join ";:;", $self->CurrentUser->id, 'ShowTicket', 'RT::Ticket-'. $Ticket->id;
        $RT::Principal::_ACL_CACHE->{ $key } = 1;
        return $Ticket;
    }
    elsif ( $Ticket->CurrentUserHasRight('ShowTicket') ) {
        # has rights
        return $Ticket;
    }
    else {
        # If the user doesn't have the right to show this ticket
        return $self->Next;
    }
}

sub _DoSearch {
    my $self = shift;
    $self->CurrentUserCanSee if RT->Config->Get('UseSQLForACLChecks');
    return $self->SUPER::_DoSearch( @_ );
}

sub _DoCount {
    my $self = shift;
    $self->CurrentUserCanSee if RT->Config->Get('UseSQLForACLChecks');
    return $self->SUPER::_DoCount( @_ );
}

sub _RolesCanSee {
    my $self = shift;

    my $cache_key = 'RolesHasRight;:;ShowTicket';
 
    if ( my $cached = $RT::Principal::_ACL_CACHE->{ $cache_key } ) {
        return %$cached;
    }

    my $ACL = RT::ACL->new( RT->SystemUser );
    $ACL->Limit( FIELD => 'RightName', VALUE => 'ShowTicket' );
    $ACL->Limit( FIELD => 'PrincipalType', OPERATOR => '!=', VALUE => 'Group' );
    my $principal_alias = $ACL->Join(
        ALIAS1 => 'main',
        FIELD1 => 'PrincipalId',
        TABLE2 => 'Principals',
        FIELD2 => 'id',
    );
    $ACL->Limit( ALIAS => $principal_alias, FIELD => 'Disabled', VALUE => 0 );

    my %res = ();
    foreach my $ACE ( @{ $ACL->ItemsArrayRef } ) {
        my $role = $ACE->__Value('PrincipalType');
        my $type = $ACE->__Value('ObjectType');
        if ( $type eq 'RT::System' ) {
            $res{ $role } = 1;
        }
        elsif ( $type eq 'RT::Queue' ) {
            next if $res{ $role } && !ref $res{ $role };
            push @{ $res{ $role } ||= [] }, $ACE->__Value('ObjectId');
        }
        else {
            $RT::Logger->error('ShowTicket right is granted on unsupported object');
        }
    }
    $RT::Principal::_ACL_CACHE->{ $cache_key } = \%res;
    return %res;
}

sub _DirectlyCanSeeIn {
    my $self = shift;
    my $id = $self->CurrentUser->id;

    my $cache_key = 'User-'. $id .';:;ShowTicket;:;DirectlyCanSeeIn';
    if ( my $cached = $RT::Principal::_ACL_CACHE->{ $cache_key } ) {
        return @$cached;
    }

    my $ACL = RT::ACL->new( RT->SystemUser );
    $ACL->Limit( FIELD => 'RightName', VALUE => 'ShowTicket' );
    my $principal_alias = $ACL->Join(
        ALIAS1 => 'main',
        FIELD1 => 'PrincipalId',
        TABLE2 => 'Principals',
        FIELD2 => 'id',
    );
    $ACL->Limit( ALIAS => $principal_alias, FIELD => 'Disabled', VALUE => 0 );
    my $cgm_alias = $ACL->Join(
        ALIAS1 => 'main',
        FIELD1 => 'PrincipalId',
        TABLE2 => 'CachedGroupMembers',
        FIELD2 => 'GroupId',
    );
    $ACL->Limit( ALIAS => $cgm_alias, FIELD => 'MemberId', VALUE => $id );
    $ACL->Limit( ALIAS => $cgm_alias, FIELD => 'Disabled', VALUE => 0 );

    my @res = ();
    foreach my $ACE ( @{ $ACL->ItemsArrayRef } ) {
        my $type = $ACE->__Value('ObjectType');
        if ( $type eq 'RT::System' ) {
            # If user is direct member of a group that has the right
            # on the system then he can see any ticket
            $RT::Principal::_ACL_CACHE->{ $cache_key } = [-1];
            return (-1);
        }
        elsif ( $type eq 'RT::Queue' ) {
            push @res, $ACE->__Value('ObjectId');
        }
        else {
            $RT::Logger->error('ShowTicket right is granted on unsupported object');
        }
    }
    $RT::Principal::_ACL_CACHE->{ $cache_key } = \@res;
    return @res;
}

sub CurrentUserCanSee {
    my $self = shift;
    return if $self->{'_sql_current_user_can_see_applied'};

    return $self->{'_sql_current_user_can_see_applied'} = 1
        if $self->CurrentUser->UserObj->HasRight(
            Right => 'SuperUser', Object => $RT::System
        );

    local $self->{using_restrictions};

    my $id = $self->CurrentUser->id;

    # directly can see in all queues then we have nothing to do
    my @direct_queues = $self->_DirectlyCanSeeIn;
    return $self->{'_sql_current_user_can_see_applied'} = 1
        if @direct_queues && $direct_queues[0] == -1;

    my %roles = $self->_RolesCanSee;
    {
        my %skip = map { $_ => 1 } @direct_queues;
        foreach my $role ( keys %roles ) {
            next unless ref $roles{ $role };

            my @queues = grep !$skip{$_}, @{ $roles{ $role } };
            if ( @queues ) {
                $roles{ $role } = \@queues;
            } else {
                delete $roles{ $role };
            }
        }
    }

# there is no global watchers, only queues and tickes, if at
# some point we will add global roles then it's gonna blow
# the idea here is that if the right is set globaly for a role
# and user plays this role for a queue directly not a ticket
# then we have to check in advance
    if ( my @tmp = grep $_ ne 'Owner' && !ref $roles{ $_ }, keys %roles ) {

        my $groups = RT::Groups->new( RT->SystemUser );
        $groups->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role', CASESENSITIVE => 0 );
        $groups->Limit(
            FIELD         => 'Name',
            FUNCTION      => 'LOWER(?)',
            OPERATOR      => 'IN',
            VALUE         => [ map {lc $_} @tmp ],
            CASESENSITIVE => 1,
        );
        my $principal_alias = $groups->Join(
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'Principals',
            FIELD2 => 'id',
        );
        $groups->Limit( ALIAS => $principal_alias, FIELD => 'Disabled', VALUE => 0 );
        my $cgm_alias = $groups->Join(
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'CachedGroupMembers',
            FIELD2 => 'GroupId',
        );
        $groups->Limit( ALIAS => $cgm_alias, FIELD => 'MemberId', VALUE => $id );
        $groups->Limit( ALIAS => $cgm_alias, FIELD => 'Disabled', VALUE => 0 );
        while ( my $group = $groups->Next ) {
            push @direct_queues, $group->Instance;
        }
    }

    unless ( @direct_queues || keys %roles ) {
        $self->Limit(
            SUBCLAUSE => 'ACL',
            ALIAS => 'main',
            FIELD => 'id',
            VALUE => 0,
            ENTRYAGGREGATOR => 'AND',
        );
        return $self->{'_sql_current_user_can_see_applied'} = 1;
    }

    {
        my $join_roles = keys %roles;
        $join_roles = 0 if $join_roles == 1 && $roles{'Owner'};
        my ($role_group_alias, $cgm_alias);
        if ( $join_roles ) {
            $role_group_alias = $self->_RoleGroupsJoin( New => 1 );
            $cgm_alias = $self->_GroupMembersJoin( GroupsAlias => $role_group_alias );
            $self->Limit(
                LEFTJOIN   => $cgm_alias,
                FIELD      => 'MemberId',
                OPERATOR   => '=',
                VALUE      => $id,
            );
        }
        my $limit_queues = sub {
            my $ea = shift;
            my @queues = @_;

            return unless @queues;
            $self->Limit(
                SUBCLAUSE       => 'ACL',
                ALIAS           => 'main',
                FIELD           => 'Queue',
                OPERATOR        => 'IN',
                VALUE           => [ @queues ],
                ENTRYAGGREGATOR => $ea,
            );
            return 1;
        };

        $self->SUPER::_OpenParen('ACL');
        my $ea = 'AND';
        $ea = 'OR' if $limit_queues->( $ea, @direct_queues );
        while ( my ($role, $queues) = each %roles ) {
            $self->SUPER::_OpenParen('ACL');
            if ( $role eq 'Owner' ) {
                $self->Limit(
                    SUBCLAUSE => 'ACL',
                    FIELD           => 'Owner',
                    VALUE           => $id,
                    ENTRYAGGREGATOR => $ea,
                );
            }
            else {
                $self->Limit(
                    SUBCLAUSE       => 'ACL',
                    ALIAS           => $cgm_alias,
                    FIELD           => 'MemberId',
                    OPERATOR        => 'IS NOT',
                    VALUE           => 'NULL',
                    QUOTEVALUE      => 0,
                    ENTRYAGGREGATOR => $ea,
                );
                $self->Limit(
                    SUBCLAUSE       => 'ACL',
                    ALIAS           => $role_group_alias,
                    FIELD           => 'Name',
                    VALUE           => $role,
                    ENTRYAGGREGATOR => 'AND',
                    CASESENSITIVE   => 0,
                );
            }
            $limit_queues->( 'AND', @$queues ) if ref $queues;
            $ea = 'OR' if $ea eq 'AND';
            $self->SUPER::_CloseParen('ACL');
        }
        $self->SUPER::_CloseParen('ACL');
    }
    return $self->{'_sql_current_user_can_see_applied'} = 1;
}



=head2 ClearRestrictions

Removes all restrictions irretrievably

=cut

sub ClearRestrictions {
    my $self = shift;
    delete $self->{'TicketRestrictions'};
    $self->{_sql_looking_at} = {};
    $self->{'RecalcTicketLimits'}      = 1;
}

# Convert a set of oldstyle SB Restrictions to Clauses for RQL

sub _RestrictionsToClauses {
    my $self = shift;

    my %clause;
    foreach my $row ( keys %{ $self->{'TicketRestrictions'} } ) {
        my $restriction = $self->{'TicketRestrictions'}{$row};

        # We need to reimplement the subclause aggregation that SearchBuilder does.
        # Default Subclause is ALIAS.FIELD, and default ALIAS is 'main',
        # Then SB AND's the different Subclauses together.

        # So, we want to group things into Subclauses, convert them to
        # SQL, and then join them with the appropriate DefaultEA.
        # Then join each subclause group with AND.

        my $field = $restriction->{'FIELD'};
        my $realfield = $field;    # CustomFields fake up a fieldname, so
                                   # we need to figure that out

        # One special case
        # Rewrite LinkedTo meta field to the real field
        if ( $field =~ /LinkedTo/ ) {
            $realfield = $field = $restriction->{'TYPE'};
        }

        # Two special case
        # Handle subkey fields with a different real field
        if ( $field =~ /^(\w+)\./ ) {
            $realfield = $1;
        }

        die "I don't know about $field yet"
            unless ( exists $FIELD_METADATA{$realfield}
                or $restriction->{CUSTOMFIELD} );

        my $type = $FIELD_METADATA{$realfield}->[0];
        my $op   = $restriction->{'OPERATOR'};

        my $value = (
            grep    {defined}
                map { $restriction->{$_} } qw(VALUE TICKET BASE TARGET)
        )[0];

        # this performs the moral equivalent of defined or/dor/C<//>,
        # without the short circuiting.You need to use a 'defined or'
        # type thing instead of just checking for truth values, because
        # VALUE could be 0.(i.e. "false")

        # You could also use this, but I find it less aesthetic:
        # (although it does short circuit)
        #( defined $restriction->{'VALUE'}? $restriction->{VALUE} :
        # defined $restriction->{'TICKET'} ?
        # $restriction->{TICKET} :
        # defined $restriction->{'BASE'} ?
        # $restriction->{BASE} :
        # defined $restriction->{'TARGET'} ?
        # $restriction->{TARGET} )

        my $ea = $restriction->{ENTRYAGGREGATOR}
            || $DefaultEA{$type}
            || "AND";
        if ( ref $ea ) {
            die "Invalid operator $op for $field ($type)"
                unless exists $ea->{$op};
            $ea = $ea->{$op};
        }

        # Each CustomField should be put into a different Clause so they
        # are ANDed together.
        if ( $restriction->{CUSTOMFIELD} ) {
            $realfield = $field;
        }

        exists $clause{$realfield} or $clause{$realfield} = [];

        # Escape Quotes
        $field =~ s!(['\\])!\\$1!g;
        $value =~ s!(['\\])!\\$1!g;
        my $data = [ $ea, $type, $field, $op, $value ];

        # here is where we store extra data, say if it's a keyword or
        # something.  (I.e. "TYPE SPECIFIC STUFF")

        if (lc $ea eq 'none') {
            $clause{$realfield} = [ $data ];
        } else {
            push @{ $clause{$realfield} }, $data;
        }
    }
    return \%clause;
}

=head2 ClausesToSQL

=cut

sub ClausesToSQL {
  my $self = shift;
  my $clauses = shift;
  my @sql;

  for my $f (keys %{$clauses}) {
    my $sql;
    my $first = 1;

    # Build SQL from the data hash
    for my $data ( @{ $clauses->{$f} } ) {
      $sql .= $data->[0] unless $first; $first=0; # ENTRYAGGREGATOR
      $sql .= " '". $data->[2] . "' ";            # FIELD
      $sql .= $data->[3] . " ";                   # OPERATOR
      $sql .= "'". $data->[4] . "' ";             # VALUE
    }

    push @sql, " ( " . $sql . " ) ";
  }

  return join("AND",@sql);
}

sub _ProcessRestrictions {
    my $self = shift;

    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'raw_rows'};
    delete $self->{'count_all'};

    my $sql = $self->Query;
    if ( !$sql || $self->{'RecalcTicketLimits'} ) {

        local $self->{using_restrictions};
        #  "Restrictions to Clauses Branch\n";
        my $clauseRef = eval { $self->_RestrictionsToClauses; };
        if ($@) {
            $RT::Logger->error( "RestrictionsToClauses: " . $@ );
            $self->FromSQL("");
        }
        else {
            $sql = $self->ClausesToSQL($clauseRef);
            $self->FromSQL($sql) if $sql;
        }
    }

    $self->{'RecalcTicketLimits'} = 0;

}

=head2 _BuildItemMap

Build up a L</ItemMap> of first/last/next/prev items, so that we can
display search nav quickly.

=cut

sub _BuildItemMap {
    my $self = shift;

    my $window = RT->Config->Get('TicketsItemMapSize');

    $self->{'item_map'} = {};

    my $items = $self->ItemsArrayRefWindow( $window );
    return unless $items && @$items;

    my $prev = 0;
    $self->{'item_map'}{'first'} = $items->[0]->EffectiveId;
    for ( my $i = 0; $i < @$items; $i++ ) {
        my $item = $items->[$i];
        my $id = $item->EffectiveId;
        $self->{'item_map'}{$id}{'defined'} = 1;
        $self->{'item_map'}{$id}{'prev'}    = $prev;
        $self->{'item_map'}{$id}{'next'}    = $items->[$i+1]->EffectiveId
            if $items->[$i+1];
        $prev = $id;
    }
    $self->{'item_map'}{'last'} = $prev
        if !$window || @$items < $window;
}

=head2 ItemMap

Returns an a map of all items found by this search. The map is a hash
of the form:

    {
        first => <first ticket id found>,
        last => <last ticket id found or undef>,

        <ticket id> => {
            prev => <the ticket id found before>,
            next => <the ticket id found after>,
        },
        <ticket id> => {
            prev => ...,
            next => ...,
        },
    }

=cut

sub ItemMap {
    my $self = shift;
    $self->_BuildItemMap unless $self->{'item_map'};
    return $self->{'item_map'};
}




=head2 PrepForSerialization

You don't want to serialize a big tickets object, as
the {items} hash will be instantly invalid _and_ eat
lots of space

=cut

sub PrepForSerialization {
    my $self = shift;
    delete $self->{'items'};
    delete $self->{'items_array'};
    $self->RedoSearch();
}

=head1 FLAGS

RT::Tickets supports several flags which alter search behavior:


allow_deleted_search  (Otherwise never show deleted tickets in search results)

These flags are set by calling 

$tickets->{'flagname'} = 1;

BUG: There should be an API for this



=cut

=head2 FromSQL

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.

=cut

sub _parser {
    my ($self,$string) = @_;

    require RT::Interface::Web::QueryBuilder::Tree;
    my $tree = RT::Interface::Web::QueryBuilder::Tree->new;
    my @results = $tree->ParseSQL(
        Query => $string,
        CurrentUser => $self->CurrentUser,
    );
    die join "; ", map { ref $_ eq 'ARRAY' ? $_->[ 0 ] : $_ } @results if @results;

    state ( $active_status_node, $inactive_status_node );

    my $escape_quotes = sub {
        my $text = shift;
        $text =~ s{(['\\])}{\\$1}g;
        return $text;
    };

    $tree->traverse(
        sub {
            my $node = shift;
            return unless $node->isLeaf and $node->getNodeValue;
            my ($key, $subkey, $meta, $op, $value, $bundle)
                = @{$node->getNodeValue}{qw/Key Subkey Meta Op Value Bundle/};
            return unless $key eq "Status" && $value =~ /^(?:__(?:in)?active__)$/i;

            my $parent = $node->getParent;
            my $index = $node->getIndex;

            if ( ( lc $value eq '__inactive__' && $op eq '=' ) || ( lc $value eq '__active__' && $op eq '!=' ) ) {
                unless ( $inactive_status_node ) {
                    my %lifecycle =
                      map { $_ => $RT::Lifecycle::LIFECYCLES{ $_ }{ inactive } }
                      grep { @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ inactive } || [] } }
                      keys %RT::Lifecycle::LIFECYCLES;
                    return unless %lifecycle;

                    my $sql;
                    if ( keys %lifecycle == 1 ) {
                        $sql = join ' OR ', map { qq{ Status = '$_' } } map { $escape_quotes->($_) } map { @$_ } values %lifecycle;
                    }
                    else {
                        my @inactive_sql;
                        for my $name ( keys %lifecycle ) {
                            my $escaped_name = $escape_quotes->($name);
                            my $inactive_sql =
                                qq{Lifecycle = '$escaped_name'}
                              . ' AND ('
                              . join( ' OR ', map { qq{ Status = '$_' } } map { $escape_quotes->($_) } @{ $lifecycle{ $name } } ) . ')';
                            push @inactive_sql, qq{($inactive_sql)};
                        }
                        $sql = join ' OR ', @inactive_sql;
                    }
                    $inactive_status_node = RT::Interface::Web::QueryBuilder::Tree->new;
                    $inactive_status_node->ParseSQL(
                        Query       => $sql,
                        CurrentUser => $self->CurrentUser,
                    );
                }
                $parent->removeChild( $node );
                $parent->insertChild( $index, $inactive_status_node );
            }
            else {
                unless ( $active_status_node ) {
                    my %lifecycle =
                      map {
                        $_ => [
                            @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ initial } || [] },
                            @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ active }  || [] },
                          ]
                      }
                      grep {
                             @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ initial } || [] }
                          || @{ $RT::Lifecycle::LIFECYCLES{ $_ }{ active }  || [] }
                      } keys %RT::Lifecycle::LIFECYCLES;
                    return unless %lifecycle;

                    my $sql;
                    if ( keys %lifecycle == 1 ) {
                        $sql = join ' OR ', map { qq{ Status = '$_' } } map { $escape_quotes->($_) } map { @$_ } values %lifecycle;
                    }
                    else {
                        my @active_sql;
                        for my $name ( keys %lifecycle ) {
                            my $escaped_name = $escape_quotes->($name);
                            my $active_sql =
                                qq{Lifecycle = '$escaped_name'}
                              . ' AND ('
                              . join( ' OR ', map { qq{ Status = '$_' } } map { $escape_quotes->($_) } @{ $lifecycle{ $name } } ) . ')';
                            push @active_sql, qq{($active_sql)};
                        }
                        $sql = join ' OR ', @active_sql;
                    }
                    $active_status_node = RT::Interface::Web::QueryBuilder::Tree->new;
                    $active_status_node->ParseSQL(
                        Query       => $sql,
                        CurrentUser => $self->CurrentUser,
                    );
                }
                $parent->removeChild( $node );
                $parent->insertChild( $index, $active_status_node );
            }
        }
    );

    # Perform an optimization pass looking for watcher bundling
    $tree->traverse(
        sub {
            my $node = shift;
            return if $node->isLeaf;
            return unless ($node->getNodeValue||'') eq "OR";
            my %refs;
            my @kids = grep {$_->{Meta}[0] eq "WATCHERFIELD"}
                map {$_->getNodeValue}
                grep {$_->isLeaf} $node->getAllChildren;
            for (@kids) {
                my $node = $_;
                my ($key, $subkey, $op) = @{$node}{qw/Key Subkey Op/};
                next if $node->{Meta}[1] and RT::Ticket->Role($node->{Meta}[1])->{Column};
                next if $op =~ /^!=$|\bNOT\b/i;
                next if $op =~ /^IS( NOT)?$/i and not $subkey;
                $node->{Bundle} = $refs{$node->{Meta}[1] || ''} ||= [];
            }
        }
    );

    my $ea = '';
    $tree->traverse(
        sub {
            my $node = shift;
            $ea = $node->getParent->getNodeValue if $node->getIndex > 0;
            return $self->_OpenParen unless $node->isLeaf;

            my ($key, $subkey, $meta, $op, $value, $bundle)
                = @{$node->getNodeValue}{qw/Key Subkey Meta Op Value Bundle/};

            # normalize key and get class (type)
            my $class = $meta->[0];

            # replace __CurrentUser__ with id
            $value = $self->CurrentUser->id if $value eq '__CurrentUser__';

            # replace __CurrentUserName__ with the username
            $value = $self->CurrentUser->Name if $value eq '__CurrentUserName__';

            my $sub = $dispatch{ $class }
                or die "No dispatch method for class '$class'";

            # A reference to @res may be pushed onto $sub_tree{$key} from
            # above, and we fill it here.
            $sub->( $self, $key, $op, $value,
                    ENTRYAGGREGATOR => $ea,
                    SUBKEY          => $subkey,
                    BUNDLE          => $bundle,
                  );
        },
        sub {
            my $node = shift;
            return $self->_CloseParen unless $node->isLeaf;
        }
    );
}

sub FromSQL {
    my ($self,$query) = @_;

    {
        # preserve first_row and show_rows across the CleanSlate
        local ($self->{'first_row'}, $self->{'show_rows'}, $self->{_sql_looking_at});
        $self->CleanSlate;
        $self->_InitSQL();
    }

    return (1, $self->loc("No Query")) unless $query;

    $self->{_sql_query} = $query;
    eval {
        local $self->{parsing_ticketsql} = 1;
        $self->_parser( $query );
    };
    if ( $@ ) {
        my $error = "$@";
        $RT::Logger->error("Couldn't parse query: $error");
        return (0, $error);
    }

    # We only want to look at EffectiveId's (mostly) for these searches.
    unless ( $self->{_sql_looking_at}{effectiveid} ) {
        # instead of EffectiveId = id we do IsMerged IS NULL
        $self->Limit(
            FIELD           => 'IsMerged',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
            ENTRYAGGREGATOR => 'AND',
            QUOTEVALUE      => 0,
        );
    }
    unless ( $self->{_sql_looking_at}{type} ) {
        $self->Limit( FIELD => 'Type', VALUE => 'ticket' );
    }

    # We don't want deleted tickets unless 'allow_deleted_search' is set
    unless( $self->{'allow_deleted_search'} ) {
        $self->Limit(
            FIELD    => 'Status',
            OPERATOR => '!=',
            VALUE => 'deleted',
        );
    }

    # set SB's dirty flag
    $self->{'must_redo_search'} = 1;
    $self->{'RecalcTicketLimits'} = 0;

    return (1, $self->loc("Valid Query"));
}

=head2 Query

Returns the last string passed to L</FromSQL>.

=cut

sub Query {
    my $self = shift;
    return $self->{_sql_query};
}

RT::Base->_ImportOverlays();

1;
