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

# Major Changes:

# - Decimated ProcessRestrictions and broke it into multiple
# functions joined by a LUT
# - Semi-Generic SQL stuff moved to another file

# Known Issues: FIXME!

# - ClearRestrictions and Reinitialization is messy and unclear.  The
# only good way to do it is to create a new RT::Tickets object.

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


use RT::Ticket;

use base 'RT::SearchBuilder';

sub Table { 'Tickets'}

use RT::CustomFields;
use DBIx::SearchBuilder::Unique;

# Configuration Tables:

# FIELD_METADATA is a mapping of searchable Field name, to Type, and other
# metadata.

our %FIELD_METADATA = (
    Status          => [ 'ENUM', ], #loc_left_pair
    Queue           => [ 'ENUM' => 'Queue', ], #loc_left_pair
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
    CustomFieldValue => [ 'CUSTOMFIELD', ], #loc_left_pair
    CustomField      => [ 'CUSTOMFIELD', ], #loc_left_pair
    CF               => [ 'CUSTOMFIELD', ], #loc_left_pair
    Updated          => [ 'TRANSDATE', ], #loc_left_pair
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
        WorkPhone HomePhone MobilePhone PagerPhone id
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
    TRANSFIELD      => \&_TransLimit,
    TRANSCONTENT    => \&_TransContentLimit,
    TRANSDATE       => \&_TransDateLimit,
    WATCHERFIELD    => \&_WatcherLimit,
    MEMBERSHIPFIELD => \&_WatcherMembershipLimit,
    CUSTOMFIELD     => \&_CustomFieldLimit,
    HASATTRIBUTE    => \&_HasAttributeLimit,
);
our %can_bundle = ();# WATCHERFIELD => "yes", );

# Default EntryAggregator per type
# if you specify OP, you must specify all valid OPs
my %DefaultEA = (
    INT  => 'AND',
    ENUM => {
        '='  => 'OR',
        '!=' => 'AND'
    },
    DATE => {
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

# Helper functions for passing the above lexically scoped tables above
# into Tickets_SQL.
sub FIELDS     { return \%FIELD_METADATA }
sub dispatch   { return \%dispatch }
sub can_bundle { return \%can_bundle }

# Bring in the clowns.
require RT::Tickets_SQL;


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

    my @bookmarks = do {
        my $tmp = $sb->CurrentUser->UserObj->FirstAttribute('Bookmarks');
        $tmp = $tmp->Content if $tmp;
        $tmp ||= {};
        grep $_, keys %$tmp;
    };

    return $sb->_SQLLimit(
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
    $sb->_OpenParen;
    my $first = 1;
    my $ea = $op eq '='? 'OR': 'AND';
    foreach my $id ( sort @bookmarks ) {
        $sb->_SQLLimit(
            ALIAS    => $tickets_alias,
            FIELD    => 'id',
            OPERATOR => $op,
            VALUE    => $id,
            $first? (@rest): ( ENTRYAGGREGATOR => $ea )
        );
        $first = 0 if $first;
    }
    $sb->_CloseParen;
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
    }
    $sb->_SQLLimit(
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

    die "Invalid Operator $op for $field"
        unless $op =~ /^(=|!=|>|<|>=|<=)$/;

    $sb->_SQLLimit(
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

    unless ($is_null) {
        $value = RT::URI->new( $sb->CurrentUser )->CanonicalizeURI( $value );
    }

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
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        ) if $meta->[2];
        $sb->_SQLLimit(
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
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => 'Type',
            OPERATOR => '=',
            VALUE    => $meta->[2],
        ) if $meta->[2];
        $sb->SUPER::Limit(
            LEFTJOIN => $linkalias,
            FIELD    => $matchfield,
            OPERATOR => '=',
            VALUE    => $value,
        );
        $sb->_SQLLimit(
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
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid Date Op: $op"
        unless $op =~ /^(=|>|<|>=|<=)$/;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Meta Data for $field"
        unless ( defined $meta->[1] );

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

        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => ">=",
            VALUE    => $daystart,
            @rest,
        );

        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => "<",
            VALUE    => $dayend,
            @rest,
            ENTRYAGGREGATOR => 'AND',
        );

        $sb->_CloseParen;

    }
    else {
        $sb->_SQLLimit(
            FIELD    => $meta->[1],
            OPERATOR => $op,
            VALUE    => $date->ISO,
            @rest,
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

    $sb->_SQLLimit(
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

        $sb->_SQLLimit(
            ALIAS         => $txn_alias,
            FIELD         => 'Created',
            OPERATOR      => ">=",
            VALUE         => $daystart,
            @rest
        );
        $sb->_SQLLimit(
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
        $sb->_SQLLimit(
            ALIAS         => $txn_alias,
            FIELD         => 'Created',
            OPERATOR      => $op,
            VALUE         => $date->ISO,
            @rest
        );
    }

    $sb->_CloseParen;
}

=head2 _TransLimit

Limit based on the ContentType or the Filename of a transaction.

=cut

sub _TransLimit {
    my ( $self, $field, $op, $value, %rest ) = @_;

    my $txn_alias = $self->JoinTransactions;
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->_SQLJoin(
            TYPE   => 'LEFT', # not all txns have an attachment
            ALIAS1 => $txn_alias,
            FIELD1 => 'id',
            TABLE2 => 'Attachments',
            FIELD2 => 'TransactionId',
        );
    }

    $self->_SQLLimit(
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
    #on. We put them in TicketAliases so that they get nuked
    #when we redo the join.

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
        $self->_SQLLimit( %rest, FIELD => 'id', VALUE => 0 );
        return;
    }

    my $txn_alias = $self->JoinTransactions;
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->_SQLJoin(
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
            $alias = $self->{'_sql_aliases'}{'full_text'} ||= $self->_SQLJoin(
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
            $self->_SQLLimit(
                %rest,
                FUNCTION      => "CONTAINS( $alias.$field, ".$dbh->quote($value) .")",
                OPERATOR      => '>',
                VALUE         => 0,
                QUOTEVALUE    => 0,
                CASESENSITIVE => 1,
            );
            # this is required to trick DBIx::SB's LEFT JOINS optimizer
            # into deciding that join is redundant as it is
            $self->_SQLLimit(
                ENTRYAGGREGATOR => 'AND',
                ALIAS           => $self->{_sql_trattachalias},
                FIELD           => 'Content',
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
            );
        }
        elsif ( $db_type eq 'Pg' ) {
            my $dbh = $RT::Handle->dbh;
            $self->_SQLLimit(
                %rest,
                ALIAS       => $alias,
                FIELD       => $index,
                OPERATOR    => '@@',
                VALUE       => 'plainto_tsquery('. $dbh->quote($value) .')',
                QUOTEVALUE  => 0,
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
            $self->_SQLLimit(
                %rest,
                ALIAS       => $alias,
                FIELD       => 'query',
                OPERATOR    => '=',
                VALUE       => "$value;limit=$max;maxmatches=$max",
            );
        }
    } else {
        $self->_SQLLimit(
            %rest,
            ALIAS         => $self->{_sql_trattachalias},
            FIELD         => $field,
            OPERATOR      => $op,
            VALUE         => $value,
            CASESENSITIVE => 0,
        );
    }
    if ( RT->Config->Get('DontSearchFileAttachments') ) {
        $self->_SQLLimit(
            ENTRYAGGREGATOR => 'AND',
            ALIAS           => $self->{_sql_trattachalias},
            FIELD           => 'Filename',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
        );
    }
    $self->_CloseParen;
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

    # Bail if the subfield is not allowed
    if (    $rest{SUBKEY}
        and not grep { $_ eq $rest{SUBKEY} } @{$SEARCHABLE_SUBFIELDS{'User'}})
    {
        die "Invalid watcher subfield: '$rest{SUBKEY}'";
    }

    # if it's equality op and search by Email or Name then we can preload user
    # we do it to help some DBs better estimate number of rows and get better plans
    if ( $op =~ /^!?=$/ && (!$rest{'SUBKEY'} || $rest{'SUBKEY'} eq 'Name' || $rest{'SUBKEY'} eq 'EmailAddress') ) {
        my $o = RT::User->new( $self->CurrentUser );
        my $method =
            !$rest{'SUBKEY'}
            ? $field eq 'Owner'? 'Load' : 'LoadByEmail'
            : $rest{'SUBKEY'} eq 'EmailAddress' ? 'LoadByEmail': 'Load';
        $o->$method( $value );
        $rest{'SUBKEY'} = 'id';
        $value = $o->id || 0;
    }

    # Owner was ENUM field, so "Owner = 'xxx'" allowed user to
    # search by id and Name at the same time, this is workaround
    # to preserve backward compatibility
    if ( $field eq 'Owner' ) {
        if ( ($rest{'SUBKEY'}||'') eq 'id' ) {
            $self->_SQLLimit(
                FIELD    => 'Owner',
                OPERATOR => $op,
                VALUE    => $value,
                %rest,
            );
            return;
        }
    }
    $rest{SUBKEY} ||= 'EmailAddress';

    my $groups = $self->_RoleGroupsJoin( Type => $type, Class => $class, New => !$type );

    $self->_OpenParen;
    if ( $op =~ /^IS(?: NOT)?$/i ) {
        # is [not] empty case

        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        # to avoid joining the table Users into the query, we just join GM
        # and make sure we don't match records where group is member of itself
        $self->SUPER::Limit(
            LEFTJOIN   => $group_members,
            FIELD      => 'GroupId',
            OPERATOR   => '!=',
            VALUE      => "$group_members.MemberId",
            QUOTEVALUE => 0,
        );
        $self->_SQLLimit(
            ALIAS         => $group_members,
            FIELD         => 'GroupId',
            OPERATOR      => $op,
            VALUE         => $value,
            %rest,
        );
    }
    elsif ( $op =~ /^!=$|^NOT\s+/i ) {
        # negative condition case

        # reverse op
        $op =~ s/!|NOT\s+//i;

        # XXX: we have no way to build correct "Watcher.X != 'Y'" when condition
        # "X = 'Y'" matches more then one user so we try to fetch two records and
        # do the right thing when there is only one exist and semi-working solution
        # otherwise.
        my $users_obj = RT::Users->new( $self->CurrentUser );
        $users_obj->Limit(
            FIELD         => $rest{SUBKEY},
            OPERATOR      => $op,
            VALUE         => $value,
        );
        $users_obj->OrderBy;
        $users_obj->RowsPerPage(2);
        my @users = @{ $users_obj->ItemsArrayRef };

        my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
        if ( @users <= 1 ) {
            my $uid = 0;
            $uid = $users[0]->id if @users;
            $self->SUPER::Limit(
                LEFTJOIN      => $group_members,
                ALIAS         => $group_members,
                FIELD         => 'MemberId',
                VALUE         => $uid,
            );
            $self->_SQLLimit(
                %rest,
                ALIAS           => $group_members,
                FIELD           => 'id',
                OPERATOR        => 'IS',
                VALUE           => 'NULL',
            );
        } else {
            $self->SUPER::Limit(
                LEFTJOIN   => $group_members,
                FIELD      => 'GroupId',
                OPERATOR   => '!=',
                VALUE      => "$group_members.MemberId",
                QUOTEVALUE => 0,
            );
            my $users = $self->Join(
                TYPE            => 'LEFT',
                ALIAS1          => $group_members,
                FIELD1          => 'MemberId',
                TABLE2          => 'Users',
                FIELD2          => 'id',
            );
            $self->SUPER::Limit(
                LEFTJOIN      => $users,
                ALIAS         => $users,
                FIELD         => $rest{SUBKEY},
                OPERATOR      => $op,
                VALUE         => $value,
                CASESENSITIVE => 0,
            );
            $self->_SQLLimit(
                %rest,
                ALIAS         => $users,
                FIELD         => 'id',
                OPERATOR      => 'IS',
                VALUE         => 'NULL',
            );
        }
    } else {
        # positive condition case

        my $group_members = $self->_GroupMembersJoin(
            GroupsAlias => $groups, New => 1, Left => 0
        );
        my $users = $self->Join(
            TYPE            => 'LEFT',
            ALIAS1          => $group_members,
            FIELD1          => 'MemberId',
            TABLE2          => 'Users',
            FIELD2          => 'id',
        );
        $self->_SQLLimit(
            %rest,
            ALIAS           => $users,
            FIELD           => $rest{'SUBKEY'},
            VALUE           => $value,
            OPERATOR        => $op,
            CASESENSITIVE   => 0,
        );
    }
    $self->_CloseParen;
}

sub _RoleGroupsJoin {
    my $self = shift;
    my %args = (New => 0, Class => 'Ticket', Type => '', @_);
    return $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
        if $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} }
           && !$args{'New'};

    # we always have watcher groups for ticket, so we use INNER join
    my $groups = $self->Join(
        ALIAS1          => 'main',
        FIELD1          => $args{'Class'} eq 'Queue'? 'Queue': 'id',
        TABLE2          => 'Groups',
        FIELD2          => 'Instance',
        ENTRYAGGREGATOR => 'AND',
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => 'RT::'. $args{'Class'} .'-Role',
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $groups,
        ALIAS           => $groups,
        FIELD           => 'Type',
        VALUE           => $args{'Type'},
    ) if $args{'Type'};

    $self->{'_sql_role_group_aliases'}{ $args{'Class'} .'-'. $args{'Type'} } = $groups
        unless $args{'New'};

    return $groups;
}

sub _GroupMembersJoin {
    my $self = shift;
    my %args = (New => 1, GroupsAlias => undef, Left => 1, @_);

    return $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
        if $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} }
            && !$args{'New'};

    my $alias = $self->Join(
        $args{'Left'} ? (TYPE            => 'LEFT') : (),
        ALIAS1          => $args{'GroupsAlias'},
        FIELD1          => 'id',
        TABLE2          => 'CachedGroupMembers',
        FIELD2          => 'GroupId',
        ENTRYAGGREGATOR => 'AND',
    );
    $self->SUPER::Limit(
        $args{'Left'} ? (LEFTJOIN => $alias) : (),
        ALIAS => $alias,
        FIELD => 'Disabled',
        VALUE => 0,
    );

    $self->{'_sql_group_members_aliases'}{ $args{'GroupsAlias'} } = $alias
        unless $args{'New'};

    return $alias;
}

=head2 _WatcherJoin

Helper function which provides joins to a watchers table both for limits
and for ordering.

=cut

sub _WatcherJoin {
    my $self = shift;
    my $type = shift || '';


    my $groups = $self->_RoleGroupsJoin( Type => $type );
    my $group_members = $self->_GroupMembersJoin( GroupsAlias => $groups );
    # XXX: work around, we must hide groups that
    # are members of the role group we search in,
    # otherwise them result in wrong NULLs in Users
    # table and break ordering. Now, we know that
    # RT doesn't allow to add groups as members of the
    # ticket roles, so we just hide entries in CGM table
    # with MemberId == GroupId from results
    $self->SUPER::Limit(
        LEFTJOIN   => $group_members,
        FIELD      => 'GroupId',
        OPERATOR   => '!=',
        VALUE      => "$group_members.MemberId",
        QUOTEVALUE => 0,
    );
    my $users = $self->Join(
        TYPE            => 'LEFT',
        ALIAS1          => $group_members,
        FIELD1          => 'MemberId',
        TABLE2          => 'Users',
        FIELD2          => 'id',
    );
    return ($groups, $group_members, $users);
}

=head2 _WatcherMembershipLimit

Handle watcher membership limits, i.e. whether the watcher belongs to a
specific group or not.

Meta Data:
  1: Field to query on

SELECT DISTINCT main.*
FROM
    Tickets main,
    Groups Groups_1,
    CachedGroupMembers CachedGroupMembers_2,
    Users Users_3
WHERE (
    (main.EffectiveId = main.id)
) AND (
    (main.Status != 'deleted')
) AND (
    (main.Type = 'ticket')
) AND (
    (
	(Users_3.EmailAddress = '22')
	    AND
	(Groups_1.Domain = 'RT::Ticket-Role')
	    AND
	(Groups_1.Type = 'RequestorGroup')
    )
) AND
    Groups_1.Instance = main.id
AND
    Groups_1.id = CachedGroupMembers_2.GroupId
AND
    CachedGroupMembers_2.MemberId = Users_3.id
ORDER BY main.id ASC
LIMIT 25

=cut

sub _WatcherMembershipLimit {
    my ( $self, $field, $op, $value, @rest ) = @_;
    my %rest = @rest;

    $self->_OpenParen;

    my $groups       = $self->NewAlias('Groups');
    my $groupmembers = $self->NewAlias('CachedGroupMembers');
    my $users        = $self->NewAlias('Users');
    my $memberships  = $self->NewAlias('CachedGroupMembers');

    if ( ref $field ) {    # gross hack
        my @bundle = @$field;
        $self->_OpenParen;
        for my $chunk (@bundle) {
            ( $field, $op, $value, @rest ) = @$chunk;
            $self->_SQLLimit(
                ALIAS    => $memberships,
                FIELD    => 'GroupId',
                VALUE    => $value,
                OPERATOR => $op,
                @rest,
            );
        }
        $self->_CloseParen;
    }
    else {
        $self->_SQLLimit(
            ALIAS    => $memberships,
            FIELD    => 'GroupId',
            VALUE    => $value,
            OPERATOR => $op,
            @rest,
        );
    }

    # Tie to groups for tickets we care about
    $self->_SQLLimit(
        ALIAS           => $groups,
        FIELD           => 'Domain',
        VALUE           => 'RT::Ticket-Role',
        ENTRYAGGREGATOR => 'AND'
    );

    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'Instance',
        ALIAS2 => 'main',
        FIELD2 => 'id'
    );

    # }}}

    # If we care about which sort of watcher
    my $meta = $FIELD_METADATA{$field};
    my $type = ( defined $meta->[1] ? $meta->[1] : undef );

    if ($type) {
        $self->_SQLLimit(
            ALIAS           => $groups,
            FIELD           => 'Type',
            VALUE           => $type,
            ENTRYAGGREGATOR => 'AND'
        );
    }

    $self->Join(
        ALIAS1 => $groups,
        FIELD1 => 'id',
        ALIAS2 => $groupmembers,
        FIELD2 => 'GroupId'
    );

    $self->Join(
        ALIAS1 => $groupmembers,
        FIELD1 => 'MemberId',
        ALIAS2 => $users,
        FIELD2 => 'id'
    );

    $self->Limit(
        ALIAS => $groupmembers,
        FIELD => 'Disabled',
        VALUE => 0,
    );

    $self->Join(
        ALIAS1 => $memberships,
        FIELD1 => 'MemberId',
        ALIAS2 => $users,
        FIELD2 => 'id'
    );

    $self->Limit(
        ALIAS => $memberships,
        FIELD => 'Disabled',
        VALUE => 0,
    );


    $self->_CloseParen;

}

=head2 _CustomFieldDecipher

Try and turn a CF descriptor into (cfid, cfname) object pair.

=cut

sub _CustomFieldDecipher {
    my ($self, $string) = @_;

    my ($queue, $field, $column) = ($string =~ /^(?:(.+?)\.)?{(.+)}(?:\.(Content|LargeContent))?$/);
    $field ||= ($string =~ /^{(.*?)}$/)[0] || $string;

    my $cf;
    if ( $queue ) {
        my $q = RT::Queue->new( $self->CurrentUser );
        $q->Load( $queue );

        if ( $q->id ) {
            # $queue = $q->Name; # should we normalize the queue?
            $cf = $q->CustomField( $field );
        }
        else {
            $RT::Logger->warning("Queue '$queue' doesn't exist, parsed from '$string'");
            $queue = 0;
        }
    }
    elsif ( $field =~ /\D/ ) {
        $queue = '';
        my $cfs = RT::CustomFields->new( $self->CurrentUser );
        $cfs->Limit( FIELD => 'Name', VALUE => $field );
        $cfs->LimitToLookupType('RT::Queue-RT::Ticket');

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
    }

    return ($queue, $field, $cf, $column);
}

=head2 _CustomFieldJoin

Factor out the Join of custom fields so we can use it for sorting too

=cut

sub _CustomFieldJoin {
    my ($self, $cfkey, $cfid, $field) = @_;
    # Perform one Join per CustomField
    if ( $self->{_sql_object_cfv_alias}{$cfkey} ||
         $self->{_sql_cf_alias}{$cfkey} )
    {
        return ( $self->{_sql_object_cfv_alias}{$cfkey},
                 $self->{_sql_cf_alias}{$cfkey} );
    }

    my ($TicketCFs, $CFs);
    if ( $cfid ) {
        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => 'main',
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'ObjectId',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $TicketCFs,
            FIELD           => 'CustomField',
            VALUE           => $cfid,
            ENTRYAGGREGATOR => 'AND'
        );
    }
    else {
        my $ocfalias = $self->Join(
            TYPE       => 'LEFT',
            FIELD1     => 'Queue',
            TABLE2     => 'ObjectCustomFields',
            FIELD2     => 'ObjectId',
        );

        $self->SUPER::Limit(
            LEFTJOIN        => $ocfalias,
            ENTRYAGGREGATOR => 'OR',
            FIELD           => 'ObjectId',
            VALUE           => '0',
        );

        $CFs = $self->{_sql_cf_alias}{$cfkey} = $self->Join(
            TYPE       => 'LEFT',
            ALIAS1     => $ocfalias,
            FIELD1     => 'CustomField',
            TABLE2     => 'CustomFields',
            FIELD2     => 'id',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $CFs,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'LookupType',
            VALUE           => 'RT::Queue-RT::Ticket',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $CFs,
            ENTRYAGGREGATOR => 'AND',
            FIELD           => 'Name',
            VALUE           => $field,
        );

        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => $CFs,
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'CustomField',
        );
        $self->SUPER::Limit(
            LEFTJOIN        => $TicketCFs,
            FIELD           => 'ObjectId',
            VALUE           => 'main.id',
            QUOTEVALUE      => 0,
            ENTRYAGGREGATOR => 'AND',
        );
    }
    $self->SUPER::Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
        ENTRYAGGREGATOR => 'AND'
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $TicketCFs,
        FIELD           => 'Disabled',
        OPERATOR        => '=',
        VALUE           => '0',
        ENTRYAGGREGATOR => 'AND'
    );

    return ($TicketCFs, $CFs);
}

=head2 _CustomFieldLimit

Limit based on CustomFields

Meta Data:
  none

=cut

use Regexp::Common qw(RE_net_IPv4);
use Regexp::Common::net::CIDR;


sub _CustomFieldLimit {
    my ( $self, $_field, $op, $value, %rest ) = @_;

    my $field = $rest{'SUBKEY'} || die "No field specified";

    # For our sanity, we can only limit on one queue at a time

    my ($queue, $cfid, $cf, $column);
    ($queue, $field, $cf, $column) = $self->_CustomFieldDecipher( $field );
    $cfid = $cf ? $cf->id  : 0 ;

# If we're trying to find custom fields that don't match something, we
# want tickets where the custom field has no value at all.  Note that
# we explicitly don't include the "IS NULL" case, since we would
# otherwise end up with a redundant clause.

    my ($negative_op, $null_op, $inv_op, $range_op)
        = $self->ClassifySQLOperation( $op );

    my $fix_op = sub {
        return @_ unless RT->Config->Get('DatabaseType') eq 'Oracle';

        my %args = @_;
        return %args unless $args{'FIELD'} eq 'LargeContent';
        
        my $op = $args{'OPERATOR'};
        if ( $op eq '=' ) {
            $args{'OPERATOR'} = 'MATCHES';
        }
        elsif ( $op eq '!=' ) {
            $args{'OPERATOR'} = 'NOT MATCHES';
        }
        elsif ( $op =~ /^[<>]=?$/ ) {
            $args{'FUNCTION'} = "TO_CHAR( $args{'ALIAS'}.LargeContent )";
        }
        return %args;
    };

    if ( $cf && $cf->Type eq 'IPAddress' ) {
        my $parsed = RT::ObjectCustomFieldValue->ParseIP($value);
        if ($parsed) {
            $value = $parsed;
        }
        else {
            $RT::Logger->warn("$value is not a valid IPAddress");
        }
    }

    if ( $cf && $cf->Type eq 'IPAddressRange' ) {

        if ( $value =~ /^\s*$RE{net}{CIDR}{IPv4}{-keep}\s*$/o ) {

            # convert incomplete 192.168/24 to 192.168.0.0/24 format
            $value =
              join( '.', map $_ || 0, ( split /\./, $1 )[ 0 .. 3 ] ) . "/$2"
              || $value;
        }

        my ( $start_ip, $end_ip ) =
          RT::ObjectCustomFieldValue->ParseIPRange($value);
        if ( $start_ip && $end_ip ) {
            if ( $op =~ /^([<>])=?$/ ) {
                my $is_less = $1 eq '<' ? 1 : 0;
                if ( $is_less ) {
                    $value = $start_ip;
                }
                else {
                    $value = $end_ip;
                }
            }
            else {
                $value = join '-', $start_ip, $end_ip;
            }
        }
        else {
            $RT::Logger->warn("$value is not a valid IPAddressRange");
        }
    }

    my $single_value = !$cf || !$cfid || $cf->SingleValue;

    my $cfkey = $cfid ? $cfid : "$queue.$field";

    if ( $null_op && !$column ) {
        # IS[ NOT] NULL without column is the same as has[ no] any CF value,
        # we can reuse our default joins for this operation
        # with column specified we have different situation
        my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cfid, $field );
        $self->_OpenParen;
        $self->_SQLLimit(
            ALIAS    => $TicketCFs,
            FIELD    => 'id',
            OPERATOR => $op,
            VALUE    => $value,
            %rest
        );
        $self->_SQLLimit(
            ALIAS      => $CFs,
            FIELD      => 'Name',
            OPERATOR   => 'IS NOT',
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
            ENTRYAGGREGATOR => 'AND',
        ) if $CFs;
        $self->_CloseParen;
    }
    elsif ( $op !~ /^[<>]=?$/ && (  $cf && $cf->Type eq 'IPAddressRange')) {
    
        my ($start_ip, $end_ip) = split /-/, $value;
        
        $self->_OpenParen;
        if ( $op !~ /NOT|!=|<>/i ) { # positive equation
            $self->_CustomFieldLimit(
                'CF', '<=', $end_ip, %rest,
                SUBKEY => $rest{'SUBKEY'}. '.Content',
            );
            $self->_CustomFieldLimit(
                'CF', '>=', $start_ip, %rest,
                SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
                ENTRYAGGREGATOR => 'AND',
            ); 
            # as well limit borders so DB optimizers can use better
            # estimations and scan less rows
# have to disable this tweak because of ipv6
#            $self->_CustomFieldLimit(
#                $field, '>=', '000.000.000.000', %rest,
#                SUBKEY          => $rest{'SUBKEY'}. '.Content',
#                ENTRYAGGREGATOR => 'AND',
#            );
#            $self->_CustomFieldLimit(
#                $field, '<=', '255.255.255.255', %rest,
#                SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
#                ENTRYAGGREGATOR => 'AND',
#            );  
        }       
        else { # negative equation
            $self->_CustomFieldLimit($field, '>', $end_ip, %rest);
            $self->_CustomFieldLimit(
                $field, '<', $start_ip, %rest,
                SUBKEY          => $rest{'SUBKEY'}. '.LargeContent',
                ENTRYAGGREGATOR => 'OR',
            );  
            # TODO: as well limit borders so DB optimizers can use better
            # estimations and scan less rows, but it's harder to do
            # as we have OR aggregator
        }
        $self->_CloseParen;
    } 
    elsif ( !$negative_op || $single_value ) {
        $cfkey .= '.'. $self->{'_sql_multiple_cfs_index'}++ if !$single_value && !$range_op;
        my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cfid, $field );

        $self->_OpenParen;

        $self->_OpenParen;

        $self->_OpenParen;
        # if column is defined then deal only with it
        # otherwise search in Content and in LargeContent
        if ( $column ) {
            $self->_SQLLimit( $fix_op->(
                ALIAS      => $TicketCFs,
                FIELD      => $column,
                OPERATOR   => $op,
                VALUE      => $value,
                CASESENSITIVE => 0,
                %rest
            ) );
            $self->_CloseParen;
            $self->_CloseParen;
            $self->_CloseParen;
        }
        else {
            # need special treatment for Date
            if ( $cf and $cf->Type eq 'DateTime' and $op eq '=' ) {

                if ( $value =~ /:/ ) {
                    # there is time speccified.
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set( Format => 'unknown', Value => $value );
                    $self->_SQLLimit(
                        ALIAS    => $TicketCFs,
                        FIELD    => 'Content',
                        OPERATOR => "=",
                        VALUE    => $date->ISO,
                        %rest,
                    );
                }
                else {
                # no time specified, that means we want everything on a
                # particular day.  in the database, we need to check for >
                # and < the edges of that day.
                    my $date = RT::Date->new( $self->CurrentUser );
                    $date->Set( Format => 'unknown', Value => $value );
                    $date->SetToMidnight( Timezone => 'server' );
                    my $daystart = $date->ISO;
                    $date->AddDay;
                    my $dayend = $date->ISO;

                    $self->_OpenParen;

                    $self->_SQLLimit(
                        ALIAS    => $TicketCFs,
                        FIELD    => 'Content',
                        OPERATOR => ">=",
                        VALUE    => $daystart,
                        %rest,
                    );

                    $self->_SQLLimit(
                        ALIAS    => $TicketCFs,
                        FIELD    => 'Content',
                        OPERATOR => "<=",
                        VALUE    => $dayend,
                        %rest,
                        ENTRYAGGREGATOR => 'AND',
                    );

                    $self->_CloseParen;
                }
            }
            elsif ( $op eq '=' || $op eq '!=' || $op eq '<>' ) {
                if ( length( Encode::encode_utf8($value) ) < 256 ) {
                    $self->_SQLLimit(
                        ALIAS    => $TicketCFs,
                        FIELD    => 'Content',
                        OPERATOR => $op,
                        VALUE    => $value,
                        CASESENSITIVE => 0,
                        %rest
                    );
                }
                else {
                    $self->_OpenParen;
                    $self->_SQLLimit(
                        ALIAS           => $TicketCFs,
                        FIELD           => 'Content',
                        OPERATOR        => '=',
                        VALUE           => '',
                        ENTRYAGGREGATOR => 'OR'
                    );
                    $self->_SQLLimit(
                        ALIAS           => $TicketCFs,
                        FIELD           => 'Content',
                        OPERATOR        => 'IS',
                        VALUE           => 'NULL',
                        ENTRYAGGREGATOR => 'OR'
                    );
                    $self->_CloseParen;
                    $self->_SQLLimit( $fix_op->(
                        ALIAS           => $TicketCFs,
                        FIELD           => 'LargeContent',
                        OPERATOR        => $op,
                        VALUE           => $value,
                        ENTRYAGGREGATOR => 'AND',
                        CASESENSITIVE => 0,
                    ) );
                }
            }
            else {
                $self->_SQLLimit(
                    ALIAS    => $TicketCFs,
                    FIELD    => 'Content',
                    OPERATOR => $op,
                    VALUE    => $value,
                    CASESENSITIVE => 0,
                    %rest
                );

                $self->_OpenParen;
                $self->_OpenParen;
                $self->_SQLLimit(
                    ALIAS           => $TicketCFs,
                    FIELD           => 'Content',
                    OPERATOR        => '=',
                    VALUE           => '',
                    ENTRYAGGREGATOR => 'OR'
                );
                $self->_SQLLimit(
                    ALIAS           => $TicketCFs,
                    FIELD           => 'Content',
                    OPERATOR        => 'IS',
                    VALUE           => 'NULL',
                    ENTRYAGGREGATOR => 'OR'
                );
                $self->_CloseParen;
                $self->_SQLLimit( $fix_op->(
                    ALIAS           => $TicketCFs,
                    FIELD           => 'LargeContent',
                    OPERATOR        => $op,
                    VALUE           => $value,
                    ENTRYAGGREGATOR => 'AND',
                    CASESENSITIVE => 0,
                ) );
                $self->_CloseParen;
            }
            $self->_CloseParen;

            # XXX: if we join via CustomFields table then
            # because of order of left joins we get NULLs in
            # CF table and then get nulls for those records
            # in OCFVs table what result in wrong results
            # as decifer method now tries to load a CF then
            # we fall into this situation only when there
            # are more than one CF with the name in the DB.
            # the same thing applies to order by call.
            # TODO: reorder joins T <- OCFVs <- CFs <- OCFs if
            # we want treat IS NULL as (not applies or has
            # no value)
            $self->_SQLLimit(
                ALIAS           => $CFs,
                FIELD           => 'Name',
                OPERATOR        => 'IS NOT',
                VALUE           => 'NULL',
                QUOTEVALUE      => 0,
                ENTRYAGGREGATOR => 'AND',
            ) if $CFs;
            $self->_CloseParen;

            if ($negative_op) {
                $self->_SQLLimit(
                    ALIAS           => $TicketCFs,
                    FIELD           => $column || 'Content',
                    OPERATOR        => 'IS',
                    VALUE           => 'NULL',
                    QUOTEVALUE      => 0,
                    ENTRYAGGREGATOR => 'OR',
                );
            }

            $self->_CloseParen;
        }
    }
    else {
        $cfkey .= '.'. $self->{'_sql_multiple_cfs_index'}++;
        my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cfid, $field );

        # reverse operation
        $op =~ s/!|NOT\s+//i;

        # if column is defined then deal only with it
        # otherwise search in Content and in LargeContent
        if ( $column ) {
            $self->SUPER::Limit( $fix_op->(
                LEFTJOIN   => $TicketCFs,
                ALIAS      => $TicketCFs,
                FIELD      => $column,
                OPERATOR   => $op,
                VALUE      => $value,
                CASESENSITIVE => 0,
            ) );
        }
        else {
            $self->SUPER::Limit(
                LEFTJOIN   => $TicketCFs,
                ALIAS      => $TicketCFs,
                FIELD      => 'Content',
                OPERATOR   => $op,
                VALUE      => $value,
                CASESENSITIVE => 0,
            );
        }
        $self->_SQLLimit(
            %rest,
            ALIAS      => $TicketCFs,
            FIELD      => 'id',
            OPERATOR   => 'IS',
            VALUE      => 'NULL',
            QUOTEVALUE => 0,
        );
    }
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
    $self->SUPER::Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'ObjectType',
        VALUE           => 'RT::Ticket',
        ENTRYAGGREGATOR => 'AND'
    );
    $self->SUPER::Limit(
        LEFTJOIN        => $alias,
        FIELD           => 'Name',
        OPERATOR        => $op,
        VALUE           => $value,
        ENTRYAGGREGATOR => 'AND'
    );
    $self->_SQLLimit(
        %rest,
        ALIAS      => $alias,
        FIELD      => 'id',
        OPERATOR   => $FIELD_METADATA{$field}->[1]? 'IS NOT': 'IS',
        VALUE      => 'NULL',
        QUOTEVALUE => 0,
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
            my $meta = $self->FIELDS->{ $row->{FIELD} };
            unless ( $meta ) {
                push @res, $row;
                next;
            }

            if ( $meta->[0] eq 'ENUM' && ($meta->[1]||'') eq 'Queue' ) {
                my $alias = $self->Join(
                    TYPE   => 'LEFT',
                    ALIAS1 => 'main',
                    FIELD1 => $row->{'FIELD'},
                    TABLE2 => 'Queues',
                    FIELD2 => 'id',
                );
                push @res, { %$row, ALIAS => $alias, FIELD => "Name" };
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
                push @res, { %$row, ALIAS => $alias, FIELD => "Name" };
            } else {
                push @res, $row;
            }
            next;
        }

        my ( $field, $subkey ) = split /\./, $row->{FIELD}, 2;
        my $meta = $self->FIELDS->{$field};
        if ( defined $meta->[0] && $meta->[0] eq 'WATCHERFIELD' ) {
            # cache alias as we want to use one alias per watcher type for sorting
            my $users = $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] };
            unless ( $users ) {
                $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] }
                    = $users = ( $self->_WatcherJoin( $meta->[1] ) )[2];
            }
            push @res, { %$row, ALIAS => $users, FIELD => $subkey };
       } elsif ( defined $meta->[0] && $meta->[0] eq 'CUSTOMFIELD' ) {
           my ($queue, $field, $cf_obj, $column) = $self->_CustomFieldDecipher( $subkey );
           my $cfkey = $cf_obj ? $cf_obj->id : "$queue.$field";
           $cfkey .= ".ordering" if !$cf_obj || ($cf_obj->MaxValues||0) != 1;
           my ($TicketCFs, $CFs) = $self->_CustomFieldJoin( $cfkey, ($cf_obj ?$cf_obj->id :0) , $field );
           # this is described in _CustomFieldLimit
           $self->_SQLLimit(
               ALIAS      => $CFs,
               FIELD      => 'Name',
               OPERATOR   => 'IS NOT',
               VALUE      => 'NULL',
               QUOTEVALUE => 1,
               ENTRYAGGREGATOR => 'AND',
           ) if $CFs;
           unless ($cf_obj) {
               # For those cases where we are doing a join against the
               # CF name, and don't have a CFid, use Unique to make sure
               # we don't show duplicate tickets.  NOTE: I'm pretty sure
               # this will stay mixed in for the life of the
               # class/package, and not just for the life of the object.
               # Potential performance issue.
               require DBIx::SearchBuilder::Unique;
               DBIx::SearchBuilder::Unique->import;
           }
           my $CFvs = $self->Join(
               TYPE   => 'LEFT',
               ALIAS1 => $TicketCFs,
               FIELD1 => 'CustomField',
               TABLE2 => 'CustomFieldValues',
               FIELD2 => 'CustomField',
           );
           $self->SUPER::Limit(
               LEFTJOIN        => $CFvs,
               FIELD           => 'Name',
               QUOTEVALUE      => 0,
               VALUE           => $TicketCFs . ".Content",
               ENTRYAGGREGATOR => 'AND'
           );

           push @res, { %$row, ALIAS => $CFvs, FIELD => 'SortOrder' };
           push @res, { %$row, ALIAS => $TicketCFs, FIELD => 'Content' };
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




=head2 Limit

Takes a paramhash with the fields FIELD, OPERATOR, VALUE and DESCRIPTION
Generally best called from LimitFoo methods

=cut

sub Limit {
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

    my $index = $self->_NextIndex;

# make the TicketRestrictions hash the equivalent of whatever we just passed in;

    %{ $self->{'TicketRestrictions'}{$index} } = %args;

    $self->{'RecalcTicketLimits'} = 1;

# If we're looking at the effective id, we don't want to append the other clause
# which limits us to tickets where id = effective id
    if ( $args{'FIELD'} eq 'EffectiveId'
        && ( !$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) )
    {
        $self->{'looking_at_effective_id'} = 1;
    }

    if ( $args{'FIELD'} eq 'Type'
        && ( !$args{'ALIAS'} || $args{'ALIAS'} eq 'main' ) )
    {
        $self->{'looking_at_type'} = 1;
    }

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

    $self->Limit(
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
    $self->Limit(
        FIELD       => 'Status',
        VALUE       => $args{'VALUE'},
        OPERATOR    => $args{'OPERATOR'},
        DESCRIPTION => join( ' ',
            $self->loc('Status'), $args{'OPERATOR'},
            $self->loc( $args{'VALUE'} ) ),
    );
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
    # Tickets_SQL/FromSQL goes down the right branch

    #  $self->LimitType(VALUE => '__any');
    $self->{looking_at_type} = 1;
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
    $self->Limit(
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
    $self->Limit(
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

    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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
    $self->Limit(
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

    $self->Limit(
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

    $self->Limit(
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

    $self->Limit(
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

    $self->Limit(%args);

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

    $self->Limit(%args);

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
        $CF->LoadByNameAndQueue(
            Name  => $args{CUSTOMFIELD},
            Queue => $args{QUEUE}
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

    $self->Limit(
        VALUE => $args{VALUE},
        FIELD => "CF"
            .(defined $args{'QUEUE'}? ".{$args{'QUEUE'}}" : '' )
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
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'}         = 0;
    $self->{'restriction_index'}       = 1;
    $self->{'primary_key'}             = "id";
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'columns_to_display'};
    $self->SUPER::_Init(@_);

    $self->_InitSQL;

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
        $RT::Principal::_ACL_CACHE->set( $key => 1 );
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
 
    if ( my $cached = $RT::Principal::_ACL_CACHE->fetch( $cache_key ) ) {
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
    $RT::Principal::_ACL_CACHE->set( $cache_key => \%res );
    return %res;
}

sub _DirectlyCanSeeIn {
    my $self = shift;
    my $id = $self->CurrentUser->id;

    my $cache_key = 'User-'. $id .';:;ShowTicket;:;DirectlyCanSeeIn';
    if ( my $cached = $RT::Principal::_ACL_CACHE->fetch( $cache_key ) ) {
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
            $RT::Principal::_ACL_CACHE->set( $cache_key => [-1] );
            return (-1);
        }
        elsif ( $type eq 'RT::Queue' ) {
            push @res, $ACE->__Value('ObjectId');
        }
        else {
            $RT::Logger->error('ShowTicket right is granted on unsupported object');
        }
    }
    $RT::Principal::_ACL_CACHE->set( $cache_key => \@res );
    return @res;
}

sub CurrentUserCanSee {
    my $self = shift;
    return if $self->{'_sql_current_user_can_see_applied'};

    return $self->{'_sql_current_user_can_see_applied'} = 1
        if $self->CurrentUser->UserObj->HasRight(
            Right => 'SuperUser', Object => $RT::System
        );

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
        $groups->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role' );
        foreach ( @tmp ) {
            $groups->Limit( FIELD => 'Type', VALUE => $_ );
        }
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
        $self->SUPER::Limit(
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
            $self->SUPER::Limit(
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
            if ( @queues == 1 ) {
                $self->SUPER::Limit(
                    SUBCLAUSE => 'ACL',
                    ALIAS => 'main',
                    FIELD => 'Queue',
                    VALUE => $_[0],
                    ENTRYAGGREGATOR => $ea,
                );
            } else {
                $self->SUPER::_OpenParen('ACL');
                foreach my $q ( @queues ) {
                    $self->SUPER::Limit(
                        SUBCLAUSE => 'ACL',
                        ALIAS => 'main',
                        FIELD => 'Queue',
                        VALUE => $q,
                        ENTRYAGGREGATOR => $ea,
                    );
                    $ea = 'OR';
                }
                $self->SUPER::_CloseParen('ACL');
            }
            return 1;
        };

        $self->SUPER::_OpenParen('ACL');
        my $ea = 'AND';
        $ea = 'OR' if $limit_queues->( $ea, @direct_queues );
        while ( my ($role, $queues) = each %roles ) {
            $self->SUPER::_OpenParen('ACL');
            if ( $role eq 'Owner' ) {
                $self->SUPER::Limit(
                    SUBCLAUSE => 'ACL',
                    FIELD           => 'Owner',
                    VALUE           => $id,
                    ENTRYAGGREGATOR => $ea,
                );
            }
            else {
                $self->SUPER::Limit(
                    SUBCLAUSE       => 'ACL',
                    ALIAS           => $cgm_alias,
                    FIELD           => 'MemberId',
                    OPERATOR        => 'IS NOT',
                    VALUE           => 'NULL',
                    QUOTEVALUE      => 0,
                    ENTRYAGGREGATOR => $ea,
                );
                $self->SUPER::Limit(
                    SUBCLAUSE       => 'ACL',
                    ALIAS           => $role_group_alias,
                    FIELD           => 'Type',
                    VALUE           => $role,
                    ENTRYAGGREGATOR => 'AND',
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





=head2 LoadRestrictions

LoadRestrictions takes a string which can fully populate the TicketRestrictons hash.
TODO It is not yet implemented

=cut



=head2 DescribeRestrictions

takes nothing.
Returns a hash keyed by restriction id.
Each element of the hash is currently a one element hash that contains DESCRIPTION which
is a description of the purpose of that TicketRestriction

=cut

sub DescribeRestrictions {
    my $self = shift;

    my %listing;

    foreach my $row ( keys %{ $self->{'TicketRestrictions'} } ) {
        $listing{$row} = $self->{'TicketRestrictions'}{$row}{'DESCRIPTION'};
    }
    return (%listing);
}



=head2 RestrictionValues FIELD

Takes a restriction field and returns a list of values this field is restricted
to.

=cut

sub RestrictionValues {
    my $self  = shift;
    my $field = shift;
    map $self->{'TicketRestrictions'}{$_}{'VALUE'}, grep {
               $self->{'TicketRestrictions'}{$_}{'FIELD'}    eq $field
            && $self->{'TicketRestrictions'}{$_}{'OPERATOR'} eq "="
        }
        keys %{ $self->{'TicketRestrictions'} };
}



=head2 ClearRestrictions

Removes all restrictions irretrievably

=cut

sub ClearRestrictions {
    my $self = shift;
    delete $self->{'TicketRestrictions'};
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'}         = 0;
    $self->{'RecalcTicketLimits'}      = 1;
}



=head2 DeleteRestriction

Takes the row Id of a restriction (From DescribeRestrictions' output, for example.
Removes that restriction from the session's limits.

=cut

sub DeleteRestriction {
    my $self = shift;
    my $row  = shift;
    delete $self->{'TicketRestrictions'}{$row};

    $self->{'RecalcTicketLimits'} = 1;

    #make the underlying easysearch object forget all its preconceptions
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



=head2 _ProcessRestrictions PARAMHASH

# The new _ProcessRestrictions is somewhat dependent on the SQL stuff,
# but isn't quite generic enough to move into Tickets_SQL.

=cut

sub _ProcessRestrictions {
    my $self = shift;

    #Blow away ticket aliases since we'll need to regenerate them for
    #a new search
    delete $self->{'TicketAliases'};
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'raw_rows'};
    delete $self->{'rows'};
    delete $self->{'count_all'};

    my $sql = $self->Query;    # Violating the _SQL namespace
    if ( !$sql || $self->{'RecalcTicketLimits'} ) {

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
looking_at_type (otherwise limit to type=ticket)

These flags are set by calling 

$tickets->{'flagname'} = 1;

BUG: There should be an API for this



=cut



=head2 NewItem

Returns an empty new RT::Ticket item

=cut

sub NewItem {
    my $self = shift;
    return(RT::Ticket->new($self->CurrentUser));
}
RT::Base->_ImportOverlays();

1;
