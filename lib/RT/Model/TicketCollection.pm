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
# Major Changes:

# - Decimated ProcessRestrictions and broke it into multiple
# functions joined by a LUT
# - Semi-Generic SQL stuff moved to another file

# Known Issues: FIXME!

# - ClearRestrictions and Reinitialization is messy and unclear.  The
# only good way to do it is to create a RT::Model::TicketCollection->new Object.

=head1 name

  RT::Model::TicketCollection - A collection of Ticket objects


=head1 SYNOPSIS

  use RT::Model::TicketCollection;
  my $tickets = RT::Model::TicketCollection->new($CurrentUser);

=head1 description

   A collection of RT::Model::TicketCollection.

=head1 METHODS


=cut

use strict;
use warnings;

package RT::Model::TicketCollection;
use base qw/RT::SearchBuilder/;
no warnings qw(redefine);

use RT::Model::CustomFieldCollection;
use Jifty::DBI::Collection::Unique;

# Override jifty default
sub implicit_clauses { }

# Configuration Tables:

# FIELD_METADATA is a mapping of searchable Field name, to Type, and other
# metadata.

our %FIELD_METADATA = (
    status           => [ 'ENUM', ],
    queue            => [ 'ENUM' => 'Queue', ],
    type             => [ 'ENUM', ],
    creator          => [ 'ENUM' => 'User', ],
    last_updated_by    => [ 'ENUM' => 'User', ],
    owner            => [ 'WATCHERFIELD' => 'owner', ],
    effective_id      => [ 'INT', ],
    id               => [ 'INT', ],
    initial_priority => [ 'INT', ],
    final_priority   => [ 'INT', ],
    priority         => [ 'INT', ],
    time_left        => [ 'INT', ],
    time_worked      => [ 'INT', ],
    time_estimated   => [ 'INT', ],

    Linked       => ['LINK'],
    linked_to     => [ 'LINK' => 'To' ],
    LinkedFrom   => [ 'LINK' => 'From' ],
    MemberOf     => [ 'LINK' => To => 'MemberOf', ],
    DependsOn    => [ 'LINK' => To => 'DependsOn', ],
    RefersTo     => [ 'LINK' => To => 'RefersTo', ],
    has_member   => [ 'LINK' => From => 'MemberOf', ],
    DependentOn  => [ 'LINK' => From => 'DependsOn', ],
    DependedOnBy => [ 'LINK' => From => 'DependsOn', ],
    ReferredToBy => [ 'LINK' => From => 'RefersTo', ],
    Told            => [ 'DATE'         => 'Told', ],
    starts          => [ 'DATE'         => 'starts', ],
    Started         => [ 'DATE'         => 'Started', ],
    Due             => [ 'DATE'         => 'Due', ],
    resolved        => [ 'DATE'         => 'resolved', ],
    LastUpdated     => [ 'DATE'         => 'LastUpdated', ],
    Created         => [ 'DATE'         => 'Created', ],
    subject         => [ 'STRING', ],
    content         => [ 'TRANSFIELD', ],
    content_type     => [ 'TRANSFIELD', ],
    Filename        => [ 'TRANSFIELD', ],
    TransactionDate => [ 'TRANSDATE', ],
    requestor       => [ 'WATCHERFIELD' => 'requestor', ],
    requestors      => [ 'WATCHERFIELD' => 'requestor', ],
    cc              => [ 'WATCHERFIELD' => 'cc', ],
    AdminCc         => [ 'WATCHERFIELD' => 'admin_cc', ],
    admin_cc         => [ 'WATCHERFIELD' => 'admin_cc', ],
    Watcher         => [ 'WATCHERFIELD', ],

    CustomFieldvalue => [ 'CUSTOMFIELD', ],
    CustomField      => [ 'CUSTOMFIELD', ],
    CF               => [ 'CUSTOMFIELD', ],
    Updated          => [ 'TRANSDATE', ],
    requestor_group   => [ 'MEMBERSHIPFIELD' => 'requestor', ],
    cc_group          => [ 'MEMBERSHIPFIELD' => 'cc', ],
    admin_cc_group     => [ 'MEMBERSHIPFIELD' => 'admin_cc', ],
    WatcherGroup     => [ 'MEMBERSHIPFIELD', ],
);

# Mapping of Field type to Function
our %dispatch = (
    ENUM            => \&_enum_limit,
    INT             => \&_int_limit,
    LINK            => \&_link_limit,
    DATE            => \&_date_limit,
    STRING          => \&_string_limit,
    TRANSFIELD      => \&_trans_limit,
    TRANSDATE       => \&_trans_date_limit,
    WATCHERFIELD    => \&_watcher_limit,
    MEMBERSHIPFIELD => \&_watcher_membership_limit,
    CUSTOMFIELD     => \&_custom_field_limit,
);
our %can_bundle = ();    # WATCHERFIELD => "yes", );

# Default entry_aggregator per type
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
    target       => 'AND',
    base         => 'AND',
    WATCHERFIELD => {
        '='        => 'OR',
        '!='       => 'AND',
        'LIKE'     => 'OR',
        'NOT LIKE' => 'AND'
    },

    CUSTOMFIELD => 'OR',
);

# Helper functions for passing the above lexically scoped tables above
# into Tickets_Overlay_SQL.
sub columns    { return \%FIELD_METADATA }
sub dispatch   { return \%dispatch }
sub can_bundle { return \%can_bundle }

# Bring in the clowns.

# {{{ sub SortFields

our @SORTcolumns = qw(id Status
    queue subject
    owner Created Due starts Started
    Told
    resolved LastUpdated priority time_worked time_left);

=head2 SortFields

Returns the list of fields that lists of tickets can easily be sorted by

=cut

sub sort_fields {
    my $self = shift;
    return (@SORTcolumns);
}

# }}}

# BEGIN SQL STUFF *********************************

sub clean_slate {
    my $self = shift;
    $self->SUPER::clean_slate(@_);
    delete $self->{$_} foreach qw(
        _sql_cf_alias
        _sql_group_members_aliases
        _sql_object_cfv_alias
        _sql_role_group_aliases
        _sql_transalias
        _sql_trattachalias
        _sql_u_watchers_alias_for_sort
        _sql_u_watchers_aliases
    );
}

=head1 Limit Helper Routines

These routines are the targets of a dispatch table depending on the
type of field.  They all share the same signature:

  my ($self,$field,$op,$value,@rest) = @_;

The values in @rest should be suitable for passing directly to
Jifty::DBI::limit.

Essentially they are an expanded/broken out (and much simplified)
version of what ProcessRestrictions used to do.  They're also much
more clearly delineated by the type of field being processed.

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

sub _enum_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # SQL::Statement changes != to <>.  (Can we remove this now?)
    $op = "!=" if $op eq "<>";

    die "Invalid Operation: $op for $field"
        unless $op eq "="
            or $op eq "!=";

    my $meta = $FIELD_METADATA{$field};
    if ( defined $meta->[1] && defined $value && $value !~ /^\d+$/ ) {
        my $class = "RT::Model::" . $meta->[1];
        my $o     = $class->new();
        $o->load($value);
        $value = $o->id;
    }
    $sb->_sql_limit(
        column   => $field,
        value    => $value,
        operator => $op,
        @rest,
    );
}

=head2 _IntLimit

Handle fields where the values are limited to integers.  (For example,
priority, time_worked.)

Meta Data:
  None

=cut

sub _int_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid Operator $op for $field"
        unless $op =~ /^(=|!=|>|<|>=|<=)$/;

    $sb->_sql_limit(
        column   => $field,
        value    => $value,
        operator => $op,
        @rest,
    );
}

=head2 _LinkLimit

Handle fields which deal with links between tickets.  (MemberOf, DependsOn)

Meta Data:
  1: Direction (From, To)
  2: Link type (MemberOf, DependsOn, RefersTo)

=cut

sub _link_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    my $meta = $FIELD_METADATA{$field};
    die "Invalid Operator $op for $field"
        unless $op =~ /^(=|!=|IS|IS NOT)$/io;

    my $direction = $meta->[1] || '';
    my ( $matchfield, $linkfield ) = ( '', '' );
    if ( $direction eq 'To' ) {
        ( $matchfield, $linkfield ) = ( "target", "base" );
    } elsif ( $direction eq 'From' ) {
        ( $matchfield, $linkfield ) = ( "base", "target" );
    } elsif ($direction) {
        die "Invalid link direction '$direction' for $field\n";
    }

    my ( $is_local, $is_null ) = ( 1, 0 );
    if ( !$value || $value =~ /^null$/io ) {
        $is_null = 1;
        $op = ( $op =~ /^(=|IS)$/ ) ? 'IS' : 'IS NOT';
    } elsif ( $value =~ /\D/ ) {
        $is_local = 0;
    }
    $matchfield = "local_$matchfield" if $is_local;

    my $is_negative = 0;
    if ( $op eq '!=' ) {
        $is_negative = 1;
        $op          = '=';
    }

#For doing a left join to find "unlinked tickets" we want to generate a query that looks like this
#    SELECT main.* FROM Tickets main
#        left join Links Links_1 ON (     (Links_1.Type = 'MemberOf')
#                                      AND(main.id = Links_1.local_target))
#        WHERE Links_1.local_base IS NULL;

    if ($is_null) {
        my $linkalias = $sb->join(
            type    => 'left',
            alias1  => 'main',
            column1 => 'id',
            table2  => 'Links',
            column2 => 'local_' . $linkfield
        );
        $sb->SUPER::limit(
            leftjoin => $linkalias,
            column   => 'type',
            operator => '=',
            value    => $meta->[2],
        ) if $meta->[2];
        $sb->_sql_limit(
            @rest,
            alias       => $linkalias,
            column      => $matchfield,
            operator    => $op,
            value       => 'NULL',
            quote_value => 0,
        );
    } elsif ($is_negative) {
        my $linkalias = $sb->join(
            type    => 'left',
            alias1  => 'main',
            column1 => 'id',
            table2  => 'Links',
            column2 => 'local_' . $linkfield
        );
        $sb->SUPER::limit(
            leftjoin => $linkalias,
            column   => 'type',
            operator => '=',
            value    => $meta->[2],
        ) if $meta->[2];
        $sb->SUPER::limit(
            leftjoin => $linkalias,
            column   => $matchfield,
            operator => $op,
            value    => $value,
        );
        $sb->_sql_limit(
            @rest,
            alias       => $linkalias,
            column      => $matchfield,
            operator    => 'IS',
            value       => 'NULL',
            quote_value => 0,
        );
    } else {
        my $linkalias = $sb->new_alias('Links');
        $sb->open_paren;

        $sb->_sql_limit(
            @rest,
            alias    => $linkalias,
            column   => 'type',
            operator => '=',
            value    => $meta->[2],
        ) if $meta->[2];

        $sb->open_paren;
        if ($direction) {
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => 'local_' . $linkfield,
                operator         => '=',
                value            => 'main.id',
                quote_value      => 0,
                entry_aggregator => 'AND',
            );
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => $matchfield,
                operator         => '=',
                value            => $value,
                entry_aggregator => 'AND',
            );
        } else {
            $sb->open_paren;
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => 'local_base',
                value            => 'main.id',
                quote_value      => 0,
                entry_aggregator => 'AND',
            );
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => $matchfield . 'target',
                value            => $value,
                entry_aggregator => 'AND',
            );
            $sb->close_paren;

            $sb->open_paren;
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => 'local_target',
                value            => 'main.id',
                quote_value      => 0,
                entry_aggregator => 'OR',
            );
            $sb->_sql_limit(
                alias            => $linkalias,
                column           => $matchfield . 'base',
                value            => $value,
                entry_aggregator => 'AND',
            );
            $sb->close_paren;
        }
        $sb->close_paren;
        $sb->close_paren;
    }
}

=head2 _DateLimit

Handle date fields.  (Created, LastTold..)

Meta Data:
  1: type of link.  (Probably not necessary.)

=cut

sub _date_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    die "Invalid date Op: $op"
        unless $op =~ /^(=|>|<|>=|<=)$/;

    my $meta = $FIELD_METADATA{$field};
    die "Incorrect Meta Data for $field"
        unless ( defined $meta->[1] );

    my $date = RT::Date->new();
    $date->set( format => 'unknown', value => $value );

    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->set_to_midnight( timezone => 'server' );
        my $daystart = $date->iso;
        $date->add_day;
        my $dayend = $date->iso;

        $sb->open_paren;

        $sb->_sql_limit(
            column   => $meta->[1],
            operator => ">=",
            value    => $daystart,
            @rest,
        );

        $sb->_sql_limit(
            column   => $meta->[1],
            operator => "<=",
            value    => $dayend,
            @rest,
            entry_aggregator => 'AND',
        );

        $sb->close_paren;

    } else {
        $sb->_sql_limit(
            column   => $meta->[1],
            operator => $op,
            value    => $date->iso,
            @rest,
        );
    }
}

=head2 _StringLimit

Handle simple fields which are just strings.  (subject,Type)

Meta Data:
  None

=cut

sub _string_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # FIXME:
    # Valid Operators:
    #  =, !=, LIKE, NOT LIKE

    $sb->_sql_limit(
        column         => $field,
        operator       => $op,
        value          => $value,
        case_sensitive => 0,
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
sub _trans_date_limit {
    my ( $sb, $field, $op, $value, @rest ) = @_;

    # See the comments for TransLimit, they apply here too

    unless ( $sb->{_sql_transalias} ) {
        $sb->{_sql_transalias} = $sb->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'Transactions',
            column2 => 'object_id',
        );
        $sb->SUPER::limit(
            alias            => $sb->{_sql_transalias},
            column           => 'object_type',
            value            => 'RT::Model::Ticket',
            entry_aggregator => 'AND',
        );
    }

    my $date = RT::Date->new();
    $date->set( format => 'unknown', value => $value );

    $sb->open_paren;
    if ( $op eq "=" ) {

        # if we're specifying =, that means we want everything on a
        # particular single day.  in the database, we need to check for >
        # and < the edges of that day.

        $date->set_to_midnight( timezone => 'server' );
        my $daystart = $date->iso;
        $date->add_day;
        my $dayend = $date->iso;

        $sb->_sql_limit(
            alias          => $sb->{_sql_transalias},
            column         => 'created',
            operator       => ">=",
            value          => $daystart,
            case_sensitive => 0,
            @rest
        );
        $sb->_sql_limit(
            alias          => $sb->{_sql_transalias},
            column         => 'created',
            operator       => "<=",
            value          => $dayend,
            case_sensitive => 0,
            @rest,
            entry_aggregator => 'AND',
        );

    }

    # not searching for a single day
    else {

        #Search for the right field
        $sb->_sql_limit(
            alias          => $sb->{_sql_transalias},
            column         => 'created',
            operator       => $op,
            value          => $date->iso,
            case_sensitive => 0,
            @rest
        );
    }

    $sb->close_paren;
}

=head2 _TransLimit

Limit based on the content of a transaction or the content_type.

Meta Data:
  none

=cut

sub _trans_limit {

    # Content, content_type, Filename

    # If only this was this simple.  We've got to do something
    # complicated here:

    #Basically, we want to make sure that the limits apply to
    #the same attachment, rather than just another attachment
    #for the same ticket, no matter how many clauses we lump
    #on. We put them in TicketAliases so that they get nuked
    #when we redo the join.

    # In the SQL, we might have
    #       (( content = foo ) or ( content = bar AND content = baz ))
    # The AND group should share the same Alias.

    # Actually, maybe it doesn't matter.  We use the same alias and it
    # works itself out? (er.. different.)

    # Steal more from _ProcessRestrictions

    # FIXME: Maybe look at the previous FooLimit call, and if it was a
    # TransLimit and entry_aggregator == AND, reuse the Aliases?

    # Or better - store the aliases on a per subclause basis - since
    # those are going to be the things we want to relate to each other,
    # anyway.

    # maybe we should not allow certain kinds of aggregation of these
    # clauses and do a psuedo regex instead? - the problem is getting
    # them all into the same subclause when you have (A op B op C) - the
    # way they get parsed in the tree they're in different subclauses.

    my ( $self, $field, $op, $value, @rest ) = @_;

    unless ( $self->{_sql_transalias} ) {
        $self->{_sql_transalias} = $self->join(
            alias1  => 'main',
            column1 => 'id',
            table2  => 'Transactions',
            column2 => 'object_id',
        );
        $self->SUPER::limit(
            alias            => $self->{_sql_transalias},
            column           => 'object_type',
            value            => 'RT::Model::Ticket',
            entry_aggregator => 'AND',
        );
    }
    unless ( defined $self->{_sql_trattachalias} ) {
        $self->{_sql_trattachalias} = $self->_sql_join(
            type => 'left',    # not all txns have an attachment
            alias1  => $self->{_sql_transalias},
            column1 => 'id',
            table2  => 'Attachments',
            column2 => 'transaction_id',
        );
    }

    $self->open_paren;

    #Search for the right field
    if ( $field eq 'content'
        and RT->config->get('DontSearchFileAttachments') )
    {
        $self->_sql_limit(
            alias            => $self->{_sql_trattachalias},
            column           => 'filename',
            operator         => 'IS',
            value            => 'NULL',
            subclause        => 'contentquery',
            entry_aggregator => 'AND',
        );
        $self->_sql_limit(
            alias          => $self->{_sql_trattachalias},
            column         => $field,
            operator       => $op,
            value          => $value,
            case_sensitive => 0,
            @rest,
            entry_aggregator => 'AND',
            subclause        => 'contentquery',
        );
    } else {
        $self->_sql_limit(
            alias            => $self->{_sql_trattachalias},
            column           => $field,
            operator         => $op,
            value            => $value,
            case_sensitive   => 0,
            entry_aggregator => 'AND',
            @rest
        );
    }

    $self->close_paren;

}

=head2 _WatcherLimit

Handle watcher limits.  (requestor, CC, etc..)

Meta Data:
  1: Field to query on



=cut

sub _watcher_limit {
    my $self  = shift;
    my $field = shift;
    my $op    = shift;
    my $value = shift;
    my %rest  = (@_);

    my $meta = $FIELD_METADATA{$field};
    my $type = $meta->[1] || '';

    # owner was ENUM field, so "owner = 'xxx'" allowed user to
    # search by id and name at the same time, this is workaround
    # to preserve backward compatibility
    if ( lc $field eq 'owner' && !$rest{subkey} && $op =~ /^!?=$/ ) {
        my $o = RT::Model::User->new;
        $o->load($value);
        $self->_sql_limit(
            column   => 'owner',
            operator => $op,
            value    => $o->id,
            %rest,
        );
        return;
    }
    $rest{subkey} ||= 'email';

    my $groups = $self->_role_groupsjoin( type => $type );

    $self->open_paren;
    if ( $op =~ /^IS(?: NOT)?$/ ) {
        my $group_members
            = $self->_group_membersjoin( groups_alias => $groups );

        # to avoid joining the table Users into the query, we just join GM
        # and make sure we don't match records where group is member of itself
        $self->SUPER::limit(
            leftjoin    => $group_members,
            column      => 'group_id',
            operator    => '!=',
            value       => "$group_members.member_id",
            quote_value => 0,
        );
        $self->_sql_limit(
            alias    => $group_members,
            column   => 'group_id',
            operator => $op,
            value    => $value,
            %rest,
        );
    } elsif ( $op =~ /^!=$|^NOT\s+/i ) {

        # reverse op
        $op =~ s/!|NOT\s+//i;

   # XXX: we have no way to build correct "Watcher.X != 'Y'" when condition
   # "X = 'Y'" matches more then one user so we try to fetch two records and
   # do the right thing when there is only one exist and semi-working solution
   # otherwise.
        my $users_obj = RT::Model::UserCollection->new;
        $users_obj->limit(
            column   => $rest{subkey},
            operator => $op,
            value    => $value,
        );
        $users_obj->order_by;
        $users_obj->rows_per_page(2);
        my @users = @{ $users_obj->items_array_ref };

        my $group_members
            = $self->_group_membersjoin( groups_alias => $groups );
        if ( @users <= 1 ) {
            my $uid = 0;
            $uid = $users[0]->id if @users;
            $self->SUPER::limit(
                leftjoin => $group_members,
                alias    => $group_members,
                column   => 'member_id',
                value    => $uid,
            );
            $self->_sql_limit(
                %rest,
                alias    => $group_members,
                column   => 'id',
                operator => 'IS',
                value    => 'NULL',
            );
        } else {
            $self->SUPER::limit(
                leftjoin    => $group_members,
                column      => 'group_id',
                operator    => '!=',
                value       => "$group_members.member_id",
                quote_value => 0,
            );
            my $users = $self->join(
                type    => 'left',
                alias1  => $group_members,
                column1 => 'member_id',
                table2  => 'Users',
                column2 => 'id',
            );
            $self->SUPER::limit(
                leftjoin       => $users,
                alias          => $users,
                column         => $rest{subkey},
                operator       => $op,
                value          => $value,
                case_sensitive => 0,
            );
            $self->_sql_limit(
                %rest,
                alias    => $users,
                column   => 'id',
                operator => 'IS',
                value    => 'NULL',
            );
        }
    } else {
        my $group_members = $self->_group_membersjoin(
            groups_alias => $groups,
            new         => 0,
        );

        my $users = $self->{'_sql_u_watchers_aliases'}{$group_members};
        unless ($users) {
            $users = $self->{'_sql_u_watchers_aliases'}{$group_members}
                = $self->new_alias('Users');
            $self->SUPER::limit(
                leftjoin    => $group_members,
                alias       => $group_members,
                column      => 'member_id',
                value       => "$users.id",
                quote_value => 0,
            );
        }

 # we join users table without adding some join condition between tables,
 # the only conditions we have are conditions on the table iteslf,
 # for example Users.email = 'x'. We should add this condition to
 # the top level of the query and bundle it with another similar conditions,
 # for example "Users.email = 'x' OR Users.email = 'Y'".
 # To achive this goal we use own subclause for conditions on the users table.
        $self->SUPER::limit(
            %rest,
            subclause      => '_sql_u_watchers_' . $users,
            alias          => $users,
            column         => $rest{'subkey'},
            value          => $value,
            operator       => $op,
            case_sensitive => 0,
        );

# A condition which ties Users and Groups (role groups) is a left join condition
# of CachedGroupMembers table. To get correct results of the query we check
# if there are matches in CGM table or not using 'cgm.id IS NOT NULL'.
        $self->_sql_limit(
            %rest,
            alias    => $group_members,
            column   => 'id',
            operator => 'IS NOT',
            value    => 'NULL',
        );
    }
    $self->close_paren;
}

sub _role_groupsjoin {
    my $self = shift;
    my %args = ( new => 0, type => '', @_ );
    return $self->{'_sql_role_group_aliases'}{ $args{'type'} }
        if $self->{'_sql_role_group_aliases'}{ $args{'type'} }
            && !$args{'new'};

    # we always have watcher groups for ticket, so we use INNER join
    my $groups = $self->join(
        alias1           => 'main',
        column1          => 'id',
        table2           => 'Groups',
        column2          => 'instance',
        entry_aggregator => 'AND',
    );
    $self->SUPER::limit(
        leftjoin => $groups,
        alias    => $groups,
        column   => 'domain',
        value    => 'RT::Model::Ticket-Role',
    );
    $self->SUPER::limit(
        leftjoin => $groups,
        alias    => $groups,
        column   => 'type',
        value    => $args{'type'},
    ) if $args{'type'};

    $self->{'_sql_role_group_aliases'}{ $args{'type'} } = $groups
        unless $args{'new'};

    return $groups;
}

sub _group_membersjoin {
    my $self = shift;
    my %args = ( new => 1, groups_alias => undef, @_ );

    return $self->{'_sql_group_members_aliases'}{ $args{'groups_alias'} }
        if $self->{'_sql_group_members_aliases'}{ $args{'groups_alias'} }
            && !$args{'new'};

    my $alias = $self->join(
        type             => 'left',
        alias1           => $args{'groups_alias'},
        column1          => 'id',
        table2           => 'CachedGroupMembers',
        column2          => 'group_id',
        entry_aggregator => 'AND',
    );

    $self->{'_sql_group_members_aliases'}{ $args{'groups_alias'} } = $alias
        unless $args{'new'};

    return $alias;
}

=head2 _Watcherjoin

Helper function which provides joins to a watchers table both for limits
and for ordering.

=cut

sub _watcherjoin {
    my $self = shift;
    my $type = shift || '';

    my $groups        = $self->_role_groupsjoin( type          => $type );
    my $group_members = $self->_group_membersjoin( groups_alias => $groups );

    # XXX: work around, we must hide groups that
    # are members of the role group we search in,
    # otherwise them result in wrong NULLs in Users
    # table and break ordering. Now, we know that
    # RT doesn't allow to add groups as members of the
    # ticket roles, so we just hide entries in CGM table
    # with member_id == group_id from results
    $self->SUPER::limit(
        leftjoin    => $group_members,
        column      => 'group_id',
        operator    => '!=',
        value       => "$group_members.member_id",
        quote_value => 0,
    );
    my $users = $self->join(
        type    => 'left',
        alias1  => $group_members,
        column1 => 'member_id',
        table2  => 'Users',
        column2 => 'id',
    );
    return ( $groups, $group_members, $users );
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
    (main.effective_id = main.id)
) AND (
    (main.Status != 'deleted')
) AND (
    (main.Type = 'ticket')
) AND (
    (
	(Users_3.email = '22')
	    AND
	(Groups_1.domain = 'RT::Model::Ticket-Role')
	    AND
	(Groups_1.Type = 'requestor_group')
    )
) AND
    Groups_1.instance = main.id
AND
    Groups_1.id = CachedGroupMembers_2.group_id
AND
    CachedGroupMembers_2.member_id = Users_3.id
order BY main.id ASC
LIMIT 25

=cut

sub _watcher_membership_limit {
    my ( $self, $field, $op, $value, @rest ) = @_;
    my %rest = @rest;

    $self->open_paren;

    my $groups       = $self->new_alias('Groups');
    my $groupmembers = $self->new_alias('CachedGroupMembers');
    my $users        = $self->new_alias('Users');
    my $memberships  = $self->new_alias('CachedGroupMembers');

    if ( ref $field ) {    # gross hack
        my @bundle = @$field;
        $self->open_paren;
        for my $chunk (@bundle) {
            ( $field, $op, $value, @rest ) = @$chunk;
            $self->_sql_limit(
                alias    => $memberships,
                column   => 'group_id',
                value    => $value,
                operator => $op,
                @rest,
            );
        }
        $self->close_paren;
    } else {
        $self->_sql_limit(
            alias    => $memberships,
            column   => 'group_id',
            value    => $value,
            operator => $op,
            @rest,
        );
    }

    # {{{ Tie to groups for tickets we care about
    $self->_sql_limit(
        alias            => $groups,
        column           => 'domain',
        value            => 'RT::Model::Ticket-Role',
        entry_aggregator => 'AND'
    );

    $self->join(
        alias1  => $groups,
        column1 => 'instance',
        alias2  => 'main',
        column2 => 'id'
    );

    # }}}

    # If we care about which sort of watcher
    my $meta = $FIELD_METADATA{$field};
    my $type = ( defined $meta->[1] ? $meta->[1] : undef );

    if ($type) {
        $self->_sql_limit(
            alias            => $groups,
            column           => 'type',
            value            => $type,
            entry_aggregator => 'AND'
        );
    }

    $self->join(
        alias1  => $groups,
        column1 => 'id',
        alias2  => $groupmembers,
        column2 => 'group_id'
    );

    $self->join(
        alias1  => $groupmembers,
        column1 => 'member_id',
        alias2  => $users,
        column2 => 'id'
    );

    $self->join(
        alias1  => $memberships,
        column1 => 'member_id',
        alias2  => $users,
        column2 => 'id'
    );

    $self->close_paren;

}

=head2 _CustomFieldDecipher

Try and turn a CF descriptor into (cfid, cfname) object pair.

=cut

sub _custom_field_decipher {
    my ( $self, $string ) = @_;

    my ( $queue, $field, $column )
        = ( $string =~ /^(?:(.+?)\.)?{(.+)}(?:\.(.+))?$/ );
    $field ||= ( $string =~ /^{(.*?)}$/ )[0] || $string;

    my $cfid;
    if ($queue) {
        my $q = RT::Model::Queue->new;
        $q->load($queue);

        my $cf;
        if ( $q->id ) {

            # $queue = $q->name; # should we normalize the queue?
            $cf = $q->custom_field($field);
        } else {
            Jifty->log->warn(
                "Queue '$queue' doesn't exists, parsed from '$string'");
            $queue = 0;
        }

        if ( $cf and my $id = $cf->id ) {
            $cfid  = $cf->id;
            $field = $cf->name;
        }
    } else {
        $queue = 0;
    }

    return ( $queue, $field, $cfid, $column );
}

=head2 _CustomFieldjoin

Factor out the join of custom fields so we can use it for sorting too

=cut

sub _custom_field_join {
    my ( $self, $cfkey, $cfid, $field ) = @_;

    # Perform one join per CustomField
    if (   $self->{_sql_object_cfv_alias}{$cfkey}
        || $self->{_sql_cf_alias}{$cfkey} )
    {
        return (
            $self->{_sql_object_cfv_alias}{$cfkey},
            $self->{_sql_cf_alias}{$cfkey}
        );
    }

    my ( $TicketCFs, $CFs );
    if ($cfid) {
        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->join(
            type    => 'left',
            alias1  => 'main',
            column1 => 'id',
            table2  => 'ObjectCustomFieldValues',
            column2 => 'object_id',
        );
        $self->SUPER::limit(
            leftjoin         => $TicketCFs,
            column           => 'custom_field',
            value            => $cfid,
            entry_aggregator => 'AND'
        );
    } else {
        my $ocfalias = $self->join(
            type             => 'left',
            column1          => 'queue',
            table2           => 'ObjectCustomFields',
            column2          => 'object_id',
            entry_aggregator => 'OR',
        );

        $self->SUPER::limit(
            leftjoin => $ocfalias,
            column   => 'object_id',
            value    => '0',
        );

        $CFs = $self->{_sql_cf_alias}{$cfkey} = $self->join(
            type    => 'left',
            alias1  => $ocfalias,
            column1 => 'custom_field',
            table2  => 'CustomFields',
            column2 => 'id',
        );

        $TicketCFs = $self->{_sql_object_cfv_alias}{$cfkey} = $self->join(
            type    => 'left',
            alias1  => $CFs,
            column1 => 'id',
            table2  => 'ObjectCustomFieldValues',
            column2 => 'custom_field',
        );
        $self->SUPER::limit(
            leftjoin         => $TicketCFs,
            column           => 'object_id',
            value            => 'main.id',
            quote_value      => 0,
            entry_aggregator => 'AND',
        );
    }
    $self->SUPER::limit(
        leftjoin         => $TicketCFs,
        column           => 'object_type',
        value            => 'RT::Model::Ticket',
        entry_aggregator => 'AND'
    );
    $self->SUPER::limit(
        leftjoin         => $TicketCFs,
        column           => 'disabled',
        operator         => '=',
        value            => '0',
        entry_aggregator => 'AND'
    );

    return ( $TicketCFs, $CFs );
}

=head2 _CustomFieldLimit

Limit based on CustomFields

Meta Data:
  none

=cut

sub _custom_field_limit {
    my ( $self, $_field, $op, $value, %rest ) = @_;

    my $field = $rest{'subkey'} || die "No field specified";

    # For our sanity, we can only limit on one queue at a time

    my ( $queue, $cfid, $column );
    ( $queue, $field, $cfid, $column )
        = $self->_custom_field_decipher($field);

    # If we're trying to find custom fields that don't match something, we
    # want tickets where the custom field has no value at all.  Note that
    # we explicitly don't include the "IS NULL" case, since we would
    # otherwise end up with a redundant clause.

    my $null_columns_ok;
    if ( ( $op =~ /^NOT LIKE$/i ) or ( $op eq '!=' ) ) {
        $null_columns_ok = 1;
    }

    my $cfkey = $cfid ? $cfid : "$queue.$field";
    my ( $TicketCFs, $CFs )
        = $self->_custom_field_join( $cfkey, $cfid, $field );

    $self->open_paren;

    if ( $CFs && !$cfid ) {
        $self->SUPER::limit(
            alias            => $CFs,
            column           => 'name',
            value            => $field,
            entry_aggregator => 'AND',
        );
    }

    $self->open_paren if $null_columns_ok;

    $self->_sql_limit(
        alias       => $TicketCFs,
        column      => $column || 'content',
        operator    => $op,
        value       => $value,
        quote_value => 1,
        %rest
    );

    if ($null_columns_ok) {
        $self->_sql_limit(
            alias            => $TicketCFs,
            column           => $column || 'content',
            operator         => 'IS',
            value            => 'NULL',
            quote_value      => 0,
            entry_aggregator => 'OR',
        );
        $self->close_paren;
    }

    $self->close_paren;

}

# End Helper Functions

# End of SQL Stuff -------------------------------------------------

# {{{ Allow sorting on watchers

=head2 order_by ARRAY

A modified version of the order_by method which automatically joins where
C<alias> is set to the name of a watcher type.

=cut

sub order_by {
    my $self = shift;
    my @args = ref( $_[0] ) ? @_ : {@_};
    my $clause;
    my @res   = ();
    my $order = 0;
    foreach my $row (@args) {
        if ( $row->{alias} || $row->{column} !~ /\./ ) {
            push @res, $row;
            next;
        }
        my ( $field, $subkey ) = split /\./, $row->{column}, 2;
        my $meta = $self->columns->{$field};
        if ( defined $meta->[0] && $meta->[0] eq 'WATCHERFIELD' ) {

        # cache alias as we want to use one alias per watcher type for sorting
            my $users = $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] };
            unless ($users) {
                $self->{_sql_u_watchers_alias_for_sort}{ $meta->[1] } = $users
                    = ( $self->_watcherjoin( $meta->[1] ) )[2];
            }
            push @res, { %$row, alias => $users, column => $subkey };
        } elsif ( defined $meta->[0] && $meta->[0] =~ /CUSTOMFIELD/i ) {
            my ( $queue, $field, $cfid )
                = $self->_custom_field_decipher($subkey);
            my $cfkey = $cfid ? $cfid : "$queue.$field";
            my ( $TicketCFs, $CFs )
                = $self->_custom_field_join( $cfkey, $cfid, $field );
            unless ($cfid) {

                # For those cases where we are doing a join against the
                # CF name, and don't have a CFid, use Unique to make sure
                # we don't show duplicate tickets.  NOTE: I'm pretty sure
                # this will stay mixed in for the life of the
                # class/package, and not just for the life of the object.
                # Potential performance issue.
                require Jifty::DBI::Collection::Unique;
                Jifty::DBI::Collection::Unique->import;
            }
            my $CFvs = $self->join(
                type    => 'left',
                alias1  => $TicketCFs,
                column1 => 'custom_field',
                table2  => 'CustomFieldValues',
                column2 => 'custom_field',
            );
            $self->SUPER::limit(
                leftjoin         => $CFvs,
                column           => 'name',
                quote_value      => 0,
                value            => $TicketCFs . ".content",
                entry_aggregator => 'AND'
            );

            push @res, { %$row, alias => $CFvs,      column => 'sort_order' };
            push @res, { %$row, alias => $TicketCFs, column => 'content' };
        } elsif ( $field eq "Custom" && $subkey eq "ownership" ) {

            # PAW logic is "reversed"
            my $order = "ASC";
            if ( exists $row->{order} ) {
                my $o = delete $row->{order};
                $order = "DESC" if $o =~ /asc/i;
            }

            # Unowned
            # Else

            # Ticket.owner  1 0 0
            my $ownerId = $self->current_user->id;
            push @res, { %$row, column => "owner=$ownerId", order => $order };

            # Unowned Tickets 0 1 0
            my $nobodyId = RT->nobody->id;
            push @res,
                { %$row, column => "owner=$nobodyId", order => $order };

            push @res, { %$row, column => "priority", order => $order };
        } else {
            push @res, $row;
        }
    }
    return $self->SUPER::order_by(@res);
}

# }}}

=head2 limit

Takes a paramhash with the fields column, operator, value and description
Generally best called from limit_Foo methods

=cut

sub limit {
    my $self = shift;
    my %args = (
        column      => undef,
        operator    => '=',
        value       => undef,
        description => undef,
        @_
    );
    $args{'description'}
        = _( "%1 %2 %3", $args{'column'}, $args{'operator'}, $args{'value'} )
        if ( !defined $args{'description'} );

    my $index = $self->next_index;

# make the TicketRestrictions hash the equivalent of whatever we just passed in;

    %{ $self->{'TicketRestrictions'}{$index} } = %args;

    $self->{'RecalcTicketLimits'} = 1;

# If we're looking at the effective id, we don't want to append the other clause
# which limits us to tickets where id = effective id
    if ( $args{'column'} eq 'effective_id'
        && ( !$args{'alias'} || $args{'alias'} eq 'main' ) )
    {
        $self->{'looking_at_effective_id'} = 1;
    }

    if ( $args{'column'} eq 'type'
        && ( !$args{'alias'} || $args{'alias'} eq 'main' ) )
    {
        $self->{'looking_at_type'} = 1;
    }

    return ($index);
}

# }}}

# {{{ sub limit_Queue

=head2 limit_Queue

limit_Queue takes a paramhash with the fields operator and value.
operator is one of = or !=. (It defaults to =).
value is a queue id or name.


=cut

sub limit_queue {
    my $self = shift;
    my %args = (
        value    => undef,
        operator => '=',
        @_
    );

    #TODO  value should also take queue objects
    if ( defined $args{'value'} && $args{'value'} !~ /^\d+$/ ) {
        my $queue = RT::Model::Queue->new();
        $queue->load( $args{'value'} );
        $args{'value'} = $queue->id;
    }

    # What if they pass in an Id?  Check for isNum() and convert to
    # string.

    #TODO check for a valid queue here

    $self->limit(
        column   => 'queue',
        value    => $args{'value'},
        operator => $args{'operator'},
        description =>
            join( ' ', _('queue'), $args{'operator'}, $args{'value'}, ),
    );

}

# }}}

# {{{ sub limit_Status

=head2 limit_Status

Takes a paramhash with the fields operator and value.
operator is one of = or !=.
value is a status.

RT adds Status != 'deleted' until object has
allow_deleted_search internal property set.
$tickets->{'allow_deleted_search'} = 1;
$tickets->limit_status( value => 'deleted' );

=cut

sub limit_status {
    my $self = shift;
    my %args = (
        operator => '=',
        @_
    );
    $self->limit(
        column   => 'status',
        value    => $args{'value'},
        operator => $args{'operator'},
        description =>
            join( ' ', _('Status'), $args{'operator'}, _( $args{'value'} ) ),
    );
}

# }}}

# {{{ sub IgnoreType

=head2 IgnoreType

If called, this search will not automatically limit the set of results found
to tickets of type "Ticket". Tickets of other types, such as "project" and
"approval" will be found.

=cut

sub ignore_type {
    my $self = shift;

    # Instead of faking a Limit that later gets ignored, fake up the
    # fact that we're already looking at type, so that the check in
    # Tickets_Overlay_SQL/from_sql goes down the right branch

    #  $self->limit_type(value => '__any');
    $self->{looking_at_type} = 1;
}

# }}}

# {{{ sub limit_Type

=head2 limit_Type

Takes a paramhash with the fields operator and value.
operator is one of = or !=, it defaults to "=".
value is a string to search for in the type of the ticket.



=cut

sub limit_type {
    my $self = shift;
    my %args = (
        operator => '=',
        value    => undef,
        @_
    );
    $self->limit(
        column   => 'type',
        value    => $args{'value'},
        operator => $args{'operator'},
        description =>
            join( ' ', _('type'), $args{'operator'}, $args{'Limit'}, ),
    );
}

# }}}

# }}}


# }}}


=head2 limit_Watcher

  Takes a paramhash with the fields operator, type and value.
  operator is one of =, LIKE, NOT LIKE or !=.
  value is a value to match the ticket\'s watcher email addresses against
  type is the sort of watchers you want to match against. Leave it undef if you want to search all of them


=cut

sub limit_watcher {
    my $self = shift;
    my %args = (
        operator => '=',
        value    => undef,
        type     => undef,
        @_
    );

    #build us up a description
    my ( $watcher_type, $desc );
    if ( $args{'type'} ) {
        $watcher_type = $args{'type'};
    } else {
        $watcher_type = "Watcher";
    }

    $self->limit(
        column   => $watcher_type,
        value    => $args{'value'},
        operator => $args{'operator'},
        type     => $args{'type'},
        description =>
            join( ' ', _($watcher_type), $args{'operator'}, $args{'value'}, ),
    );
}

# }}}

# }}}

# }}}

# {{{ limit_ing based on links

# {{{ limit_linked_to

=head2 limit_linked_to

limit_linked_to takes a paramhash with two fields: type and target
type limits the sort of link we want to search on

type = { RefersTo, MemberOf, DependsOn }

target is the id or URI of the target of the link

=cut

sub limit_linked_to {
    my $self = shift;
    my %args = (
        target   => undef,
        type     => undef,
        operator => '=',
        @_
    );

    $self->limit(
        column => 'linked_to',
        base   => undef,
        target => $args{'target'},
        type   => $args{'type'},
        description =>
            _( "Tickets %1 by %2", _( $args{'type'} ), $args{'target'} ),
        operator => $args{'operator'},
    );
}

# }}}

# {{{ limit_LinkedFrom

=head2 limit_LinkedFrom

limit_LinkedFrom takes a paramhash with two fields: type and base
type limits the sort of link we want to search on


base is the id or URI of the base of the link

=cut

sub limit_linked_from {
    my $self = shift;
    my %args = (
        base     => undef,
        type     => undef,
        operator => '=',
        @_
    );

    # translate RT2 From/To naming to RT3 TicketSQL naming
    my %fromToMap = qw(DependsOn DependentOn
        MemberOf  has_member
        RefersTo  ReferredToBy);

    my $type = $args{'type'};
    $type = $fromToMap{$type} if exists( $fromToMap{$type} );

    $self->limit(
        column => 'linked_to',
        target => undef,
        base   => $args{'base'},
        type   => $type,
        description =>
            _( "Tickets %1 %2", _( $args{'type'} ), $args{'base'}, ),
        operator => $args{'operator'},
    );
}

# }}}

# {{{ limit_member_of
sub limit_member_of {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_to(
        @_,
        target => $ticket_id,
        type   => 'MemberOf',
    );
}

# }}}

# {{{ limit_has_member
sub limit_has_member {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_from(
        @_,
        base => "$ticket_id",
        type => 'has_member',
    );

}

# }}}

# {{{ limit_DependsOn

sub limitdepends_on {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_to(
        @_,
        target => $ticket_id,
        type   => 'DependsOn',
    );

}

# }}}

# {{{ limit_depended_on_by

sub limit_depended_on_by {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_from(
        @_,
        base => $ticket_id,
        type => 'DependentOn',
    );

}

# }}}

# {{{ limit_RefersTo

sub limit_refers_to {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_to(
        @_,
        target => $ticket_id,
        type   => 'RefersTo',
    );

}

# }}}

# {{{ limit_ReferredToBy

sub limit_referred_to_by {
    my $self      = shift;
    my $ticket_id = shift;
    return $self->limit_linked_from(
        @_,
        base => $ticket_id,
        type => 'ReferredToBy',
    );
}

# }}}

# }}}


# {{{ sub _nextIndex

=head2 _nextIndex

Keep track of the counter for the array of restrictions

=cut

sub next_index {
    my $self = shift;
    return ( $self->{'restriction_index'}++ );
}

# }}}

# }}}

# {{{ Core bits to make this a Jifty::DBI object

# {{{ sub _init
sub _init {
    my $self = shift;
    $self->{'RecalcTicketLimits'}      = 1;
    $self->{'looking_at_effective_id'} = 0;
    $self->{'looking_at_type'}         = 0;
    $self->{'restriction_index'}       = 1;
    $self->{'primary_key'}             = "id";
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'columns_to_display'};
    $self->SUPER::_init(@_);

    $self->_init_sql;

}

# }}}

# {{{ sub count
sub count {
    my $self = shift;
    $self->_process_restrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::count() );
}

# }}}

# {{{ sub count_all
sub count_all {
    my $self = shift;
    $self->_process_restrictions() if ( $self->{'RecalcTicketLimits'} == 1 );
    return ( $self->SUPER::count_all() );
}

# }}}

# {{{ sub items_array_ref

=head2 items_array_ref

Returns a reference to the set of all items found in this search

=cut

sub items_array_ref {
    my $self = shift;
    my @items;

    unless ( $self->{'items_array'} ) {

        my $placeholder = $self->_items_counter;
        $self->goto_first_item();
        while ( my $item = $self->next ) {
            push( @{ $self->{'items_array'} }, $item );
        }
        $self->goto_item($placeholder);
        $self->{'items_array'}
            = $self->items_order_by( $self->{'items_array'} );
    }
    return ( $self->{'items_array'} );
}

# }}}

# {{{ sub next
sub next {
    my $self = shift;

    $self->_process_restrictions() if ( $self->{'RecalcTicketLimits'} == 1 );

    my $Ticket = $self->SUPER::next();
    if ( ( defined($Ticket) ) and ( ref($Ticket) ) ) {

        if ( $Ticket->__value('status') eq 'deleted'
            && !$self->{'allow_deleted_search'} )
        {
            return ( $self->next() );
        }

        # Since Ticket could be granted with more rights instead
        # of being revoked, it's ok if queue rights allow
        # ShowTicket.  It seems need another query, but we have
        # rights cache in Principal::has_right.
        elsif ($Ticket->queue_obj->current_user_has_right('ShowTicket')
            || $Ticket->current_user_has_right('ShowTicket') )
        {
            return ($Ticket);
        }

        if ( $Ticket->__value('status') eq 'deleted' ) {
            return ( $self->next() );
        }

        # Since Ticket could be granted with more rights instead
        # of being revoked, it's ok if queue rights allow
        # ShowTicket.  It seems need another query, but we have
        # rights cache in Principal::has_right.
        elsif ($Ticket->queue_obj->current_user_has_right('ShowTicket')
            || $Ticket->current_user_has_right('ShowTicket') )
        {
            return ($Ticket);
        }

        #If the user doesn't have the right to show this ticket
        else {
            return ( $self->next() );
        }
    }

    #if there never was any ticket
    else {
        return (undef);
    }

}

# }}}

# }}}


# Convert a set of oldstyle SB Restrictions to Clauses for RQL

sub _restrictions_to_clauses {
    my $self = shift;

    my $row;
    my %clause;
    foreach $row ( keys %{ $self->{'TicketRestrictions'} } ) {
        my $restriction = $self->{'TicketRestrictions'}{$row};

   # We need to reimplement the subclause aggregation that SearchBuilder does.
   # Default Subclause is alias.column, and default alias is 'main',
   # Then SB AND's the different Subclauses together.

        # So, we want to group things into Subclauses, convert them to
        # SQL, and then join them with the appropriate DefaultEA.
        # Then join each subclause group with AND.

        my $field = $restriction->{'column'};
        my $realfield = $field;    # CustomFields fake up a fieldname, so
                                   # we need to figure that out

        # One special case
        # Rewrite linked_to meta field to the real field
        if ( $field =~ /linked_to/ ) {
            $realfield = $field = $restriction->{'type'};
        }

        # Two special case
        # Handle subkey fields with a different real field
        if ( $field =~ /^(\w+)\./ ) {
            $realfield = $1;
        }

        die "I don't know about $field yet"
            unless ( exists $FIELD_METADATA{$realfield}
            or $restriction->{customfield} );

        my $type = $FIELD_METADATA{$realfield}->[0];
        my $op   = $restriction->{'operator'};

        my $value = (
            grep    {defined}
                map { $restriction->{$_} } qw(value TICKET base target)
        )[0];

        # this performs the moral equivalent of defined or/dor/C<//>,
        # without the short circuiting.You need to use a 'defined or'
        # type thing instead of just checking for truth values, because
        # value could be 0.(i.e. "false")

        # You could also use this, but I find it less aesthetic:
        # (although it does short circuit)
        #( defined $restriction->{'value'}? $restriction->{value} :
        # defined $restriction->{'TICKET'} ?
        # $restriction->{TICKET} :
        # defined $restriction->{'base'} ?
        # $restriction->{base} :
        # defined $restriction->{'target'} ?
        # $restriction->{target} )

        my $ea = $restriction->{entry_aggregator}
            || $DefaultEA{$type}
            || "AND";
        if ( ref $ea ) {
            die "Invalid operator $op for $field ($type)"
                unless exists $ea->{$op};
            $ea = $ea->{$op};
        }

        # Each CustomField should be put into a different Clause so they
        # are ANDed together.
        if ( $restriction->{customfield} ) {
            $realfield = $field;
        }

        exists $clause{$realfield} or $clause{$realfield} = [];

        # Escape Quotes
        $field =~ s!(['"])!\\$1!g;
        $value =~ s!(['"])!\\$1!g;
        my $data = [ $ea, $type, $field, $op, $value ];

        # here is where we store extra data, say if it's a keyword or
        # something.  (I.e. "type SPECIFIC STUFF")

        push @{ $clause{$realfield} }, $data;
    }
    return \%clause;
}

# }}}

# {{{ sub _ProcessRestrictions

=head2 _ProcessRestrictions PARAMHASH

# The new _ProcessRestrictions is somewhat dependent on the SQL stuff,
# but isn't quite generic enough to move into Tickets_Overlay_SQL.

=cut

sub _process_restrictions {
    my $self = shift;

    #Blow away ticket aliases since we'll need to regenerate them for
    #a new search
    delete $self->{'TicketAliases'};
    delete $self->{'items_array'};
    delete $self->{'item_map'};
    delete $self->{'raw_rows'};
    delete $self->{'rows'};
    delete $self->{'count_all'};

    my $sql = $self->query;    # Violating the _SQL namespace
    if ( !$sql || $self->{'RecalcTicketLimits'} ) {

        #  "Restrictions to Clauses Branch\n";
        my $clauseRef = eval { $self->_restrictions_to_clauses; };
        if ($@) {
            Jifty->log->error( "RestrictionsToClauses: " . $@ );
            $self->from_sql("");
        } else {
            $sql = $self->clauses_to_sql($clauseRef);
            $self->from_sql($sql) if $sql;
        }
    }

    $self->{'RecalcTicketLimits'} = 0;

}

=head2 _BuildItemMap

    # Build up a map of first/last/next/prev items, so that we can display search nav quickly

=cut

sub _build_item_map {
    my $self = shift;

    my $items = $self->items_array_ref;
    my $prev  = 0;

    delete $self->{'item_map'};
    if ( $items->[0] ) {
        $self->{'item_map'}->{'first'} = $items->[0]->effective_id;
        while ( my $item = shift @$items ) {
            my $id = $item->effective_id;
            $self->{'item_map'}->{$id}->{'defined'} = 1;
            $self->{'item_map'}->{$id}->{prev}      = $prev;
            $self->{'item_map'}->{$id}->{next}      = $items->[0]->effective_id
                if ( $items->[0] );
            $prev = $id;
        }
        $self->{'item_map'}->{'last'} = $prev;
    }
}

=head2 ItemMap

Returns an a map of all items found by this search. The map is of the form

$ItemMap->{'first'} = first ticketid found
$ItemMap->{'last'} = last ticketid found
$ItemMap->{$id}->{prev} = the ticket id found before $id
$ItemMap->{$id}->{next} = the ticket id found after $id

=cut

sub item_map {
    my $self = shift;
    $self->_build_item_map()
        unless ( $self->{'items_array'} and $self->{'item_map'} );
    return ( $self->{'item_map'} );
}

=cut



}



# }}}

# }}}

=head2 PrepForSerialization

You don't want to serialize a big tickets object, as the {items} hash will be instantly invalid _and_ eat lots of space

=cut

sub prep_for_serialization {
    my $self = shift;
    delete $self->{'items'};
    $self->redo_search();
}

use RT::SQL;

# Import configuration data from the lexcial scope of __PACKAGE__ (or
# at least where those two Subroutines are defined.)

# Lower Case version of columns, for case insensitivity
my %lcfields = map { ( lc($_) => $_ ) } ( keys %FIELD_METADATA );

sub _init_sql {
    my $self = shift;

    # Private Member Variables (which should get cleaned)
    $self->{'_sql_transalias'}               = undef;
    $self->{'_sql_trattachalias'}            = undef;
    $self->{'_sql_cf_alias'}                 = undef;
    $self->{'_sql_object_cfv_alias'}         = undef;
    $self->{'_sql_watcher_join_users_alias'} = undef;
    $self->{'_sql_query'}                    = '';
    $self->{'_sql_looking_at'}               = {};
}

sub _sql_limit {
    my $self = shift;
    my %args = (@_);
    if ( $args{'column'} eq 'effective_id'
        && ( !$args{'alias'} || $args{'alias'} eq 'main' ) )
    {
        $self->{'looking_at_effective_id'} = 1;
    }

    if ( $args{'column'} eq 'type'
        && ( !$args{'alias'} || $args{'alias'} eq 'main' ) )
    {
        $self->{'looking_at_type'} = 1;
    }

    # All SQL stuff goes into one SB subclause so we can deal with all
    # the aggregation
    $self->SUPER::limit( %args, subclause => 'ticketsql' );
}

sub _sql_join {

    # All SQL stuff goes into one SB subclause so we can deal with all
    # the aggregation
    my $this = shift;

    $this->join( @_, subclause => 'ticketsql' );
}

# Helpers
sub open_paren {
    $_[0]->SUPER::open_paren('ticketsql');
}

sub close_paren {
    $_[0]->SUPER::close_paren('ticketsql');
}

=head1 SQL Functions

=cut

=head2 Robert's Simple SQL Parser

Documentation In Progress

The Parser/Tokenizer is a relatively simple state machine that scans through a SQL WHERE clause type string extracting a token at a time (where a token is:

  value -> quoted string or number
  AGGREGator -> AND or OR
  KEYWORD -> quoted string or single word
  OPerator -> =,!=,LIKE,etc..
  PARENthesis -> open or close.

And that stream of tokens is passed through the "machine" in order to build up a structure that looks like:

       KEY OP value
  AND  KEY OP value
  OR   KEY OP value

That also deals with parenthesis for nesting.  (The parentheses are
just handed off the SearchBuilder)

=cut

sub _close_bundle {
    my ( $self, @bundle ) = @_;
    return unless @bundle;

    if ( @bundle == 1 ) {
        $bundle[0]->{'dispatch'}->(
            $self,
            $bundle[0]->{'key'},
            $bundle[0]->{'op'},
            $bundle[0]->{'val'},
            subclause        => '',
            entry_aggregator => $bundle[0]->{ea},
            subkey           => $bundle[0]->{subkey},
        );
    } else {
        my @args;
        foreach my $chunk (@bundle) {
            push @args,
                [
                $chunk->{key},
                $chunk->{op},
                $chunk->{val},
                subclause        => '',
                entry_aggregator => $chunk->{ea},
                subkey           => $chunk->{subkey},
                ];
        }
        $bundle[0]->{dispatch}->( $self, \@args );
    }
}

sub _parser {
    my ( $self, $string ) = @_;
    my @bundle;
    my $ea = '';

    my %callback;
    $callback{'open_paren'} = sub {
        $self->_close_bundle(@bundle);
        @bundle = ();
        $self->open_paren;
    };
    $callback{'close_paren'} = sub {
        $self->_close_bundle(@bundle);
        @bundle = ();
        $self->close_paren;
    };
    $callback{'entry_aggregator'} = sub { $ea = $_[0] || '' };
    $callback{'Condition'} = sub {
        my ( $key, $op, $value ) = @_;

        # key has dot then it's compound variant and we have subkey
        my $subkey = '';
        ( $key, $subkey ) = ( $1, $2 ) if $key =~ /^([^\.]+)\.(.+)$/;

        # normalize key and get class (type)
        my $class;
        if ( exists $lcfields{ lc $key } ) {
            $key   = $lcfields{ lc $key };
            $class = $FIELD_METADATA{$key}->[0];
        }
        die "Unknown field '$key' in '$string'" unless $class;

        unless ( $dispatch{$class} ) {
            die "No dispatch method for class '$class'";
        }
        my $sub = $dispatch{$class};

        if ($can_bundle{$class}
            && (!@bundle
                || (   $bundle[-1]->{dispatch} == $sub
                    && $bundle[-1]->{key}    eq $key
                    && $bundle[-1]->{subkey} eq $subkey )
            )
            )
        {
            push @bundle,
                {
                dispatch => $sub,
                key      => $key,
                op       => $op,
                val      => $value,
                ea       => $ea,
                subkey   => $subkey,
                };
        } else {
            $self->_close_bundle(@bundle);
            @bundle = ();
            $sub->(
                $self, $key, $op, $value,
                subclause        => '',        # don't need anymore
                entry_aggregator => $ea,
                subkey           => $subkey,
            );
        }
        $self->{_sql_looking_at}{ lc $key } = 1;
        $ea = '';
    };
    RT::SQL::parse( $string, \%callback );
    $self->_close_bundle(@bundle);
    @bundle = ();
}

=head2 ClausesToSQL

=cut

sub clauses_to_sql {
    my $self    = shift;
    my $clauses = shift;
    my @sql;

    for my $f ( keys %{$clauses} ) {
        my $sql;
        my $first = 1;

        # Build SQL from the data hash
        for my $data ( @{ $clauses->{$f} } ) {
            $sql .= $data->[0] unless $first;
            $first = 0;    # entry_aggregator
            $sql .= " '" . $data->[2] . "' ";    # column
            $sql .= $data->[3] . " ";            # operator
            $sql .= "'" . $data->[4] . "' ";     # value
        }

        push @sql, " ( " . $sql . " ) ";
    }

    return join( "AND", @sql );
}

=head2 from_sql

Convert a RT-SQL string into a set of SearchBuilder restrictions.

Returns (1, 'Status message') on success and (0, 'Error Message') on
failure.




=cut

sub from_sql {
    my ( $self, $query ) = @_;

    {

        # preserve first_row and show_rows across the clean_slate
        local ( $self->{'first_row'}, $self->{'show_rows'} );
        $self->clean_slate;
    }
    $self->_init_sql();

    return ( 1, _("No Query") ) unless $query;

    $self->{_sql_query} = $query;
    eval { $self->_parser($query); };
    if ($@) {
        Jifty->log->error($@);
        return ( 0, $@ );
    }

    # We only want to look at effective_id's (mostly) for these searches.
    unless ( exists $self->{_sql_looking_at}{'effectiveid'} ) {

        #TODO, we shouldn't be hard #coding the tablename to main.
        $self->SUPER::limit(
            column           => 'effective_id',
            value            => 'main.id',
            entry_aggregator => 'AND',
            quote_value      => 0,
        );
    }

    # FIXME: Need to bring this logic back in

#      if ($self->_islimit_ed && (! $self->{'looking_at_effective_id'})) {
#         $self->SUPER::limit( column => 'effective_id',
#               operator => '=',
#               quote_value => 0,
#               value => 'main.id');   #TODO, we shouldn't be hard coding the tablename to main.
#       }
# --- This is hardcoded above.  This comment block can probably go.
# Or, we need to reimplement the looking_at_effective_id toggle.

    # Unless we've explicitly asked to look at a specific Type, we need
    # to limit to it.
    unless ( $self->{looking_at_type} ) {
        $self->SUPER::limit( column => 'type', value => 'ticket' );
    }

    # We don't want deleted tickets unless 'allow_deleted_search' is set
    unless ( $self->{'allow_deleted_search'} ) {
        $self->SUPER::limit(
            column   => 'status',
            operator => '!=',
            value    => 'deleted',
        );
    }

    # set SB's dirty flag
    $self->{'must_redo_search'}   = 1;
    $self->{'RecalcTicketLimits'} = 0;

    return ( 1, _("Valid Query") );
}

=head2 Query

Returns the query that this object was initialized with

=cut

sub query {
    return ( $_[0]->{_sql_query} );
}

1;

=pod

=head2 Exceptions

Most of the RT code does not use Exceptions (die/eval) but it is used
in the TicketSQL code for simplicity and historical reasons.  Lest you
be worried that the dies will trigger user visible errors, all are
trapped via evals.

99% of the dies fall in subroutines called via from_sql and then parse.
(This includes all of the _FooLimit routines in TicketCollection_Overlay.pm.)
The other 1% or so are via _ProcessRestrictions.

All dies are trapped by eval {}s, and will be logged at the 'error'
log level.  The general failure mode is to not display any tickets.

=head2 General Flow

Legacy Layer:

   Legacy limit_Foo routines build up a RestrictionsHash

   _ProcessRestrictions converts the Restrictions to Clauses
   ([key,op,val,rest]).

   Clauses are converted to RT-SQL (TicketSQL)

New RT-SQL Layer:

   from_sql calls the parser

   The parser calls the _FooLimit routines to do Jifty::DBI
   limits.

And then the normal SearchBuilder/Ticket routines are used for
display/navigation.

=cut

=head1 FLAGS

RT::Model::TicketCollection supports several flags which alter search behavior:


allow_deleted_search  (Otherwise never show deleted tickets in search results)
looking_at_type (otherwise limit to type=ticket)

These flags are set by calling 

$tickets->{'flagname'} = 1;

BUG: There should be an API for this

=cut

=cut

1;



